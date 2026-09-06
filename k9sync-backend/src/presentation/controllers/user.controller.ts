import { FastifyRequest, FastifyReply } from 'fastify';
import bcrypt from 'bcrypt';
import { getPrisma } from '../../config/database.js';
import { NotFoundError, UnauthorizedError, ValidationError } from '../../shared/errors.js';
import { logger } from '../../shared/logger.js';
import {
  deleteAccountBodySchema,
  postConsentsBodySchema,
  pushTokenBodySchema,
} from '../schemas/user.schema.js';

export class UserController {
  /**
   * Delete the authenticated user's account.
   *
   * Requires the current password in the body — a valid JWT alone is not
   * enough for a destructive, irreversible action (matches the confirmation
   * promised on the app's privacy screen).
   *
   * `Dog` has no direct FK to `User` — only the `DogUser` join table does —
   * so deleting a `User` row alone only cascades to `RefreshToken` and
   * `DogUser` (removes pairings), never to `Dog`/`Collar`/telemetry. To
   * actually erase "my dogs and their data" as promised to the user, we
   * explicitly delete every Dog this user owns (role 'owner'); that delete
   * is what triggers the rest of the cascade (Dog -> DogUser/Collar/Alert,
   * Collar -> GpsLocation/HealthRecord/ActivityRecord). Dogs shared with
   * this user as family/viewer are left untouched — only their DogUser
   * link is removed, via the final user delete.
   */
  async deleteMe(req: FastifyRequest<{ Body: unknown }>, reply: FastifyReply) {
    const userId = req.userId;

    const body = deleteAccountBodySchema.safeParse(req.body);
    if (!body.success) throw new ValidationError(body.error.flatten());
    const { password } = body.data;

    const user = await getPrisma().user.findUnique({ where: { id: userId } });
    if (!user) {
      logger.warn({ userId }, 'DELETE /users/me — user not found');
      throw new NotFoundError('User', userId);
    }

    const passwordMatches = await bcrypt.compare(password, user.passwordHash);
    if (!passwordMatches) {
      logger.warn({ userId }, 'DELETE /users/me — invalid password, account not deleted');
      throw new UnauthorizedError('Invalid password');
    }

    await getPrisma().$transaction(async (tx) => {
      const ownedDogs = await tx.dogUser.findMany({
        where: { userId, role: 'owner' },
        select: { dogId: true },
      });

      if (ownedDogs.length > 0) {
        await tx.dog.deleteMany({
          where: { id: { in: ownedDogs.map((d) => d.dogId) } },
        });
      }

      await tx.user.delete({ where: { id: userId } });
    });

    logger.info({ userId }, 'Account deleted');
    return reply.status(204).send();
  }

  async getMe(req: FastifyRequest, reply: FastifyReply) {
    const user = await getPrisma().user.findUnique({
      where: { id: req.userId },
    });

    if (!user) {
      logger.warn({ userId: req.userId }, 'GET /users/me — user not found');
      throw new NotFoundError('User', req.userId);
    }

    logger.info({ userId: user.id, event: 'getMe' }, 'User profile fetched');

    return reply.send({
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        subscriptionPlan: user.subscriptionPlan,
        createdAt: user.createdAt.toISOString(),
        updatedAt: user.updatedAt.toISOString(),
      },
    });
  }

  /**
   * RGPD art. 20 (portabilité) — export de toutes les données personnelles
   * de l'utilisateur authentifié : profil, chiens qu'il possède, et pour
   * chacun leur télémétrie (GPS, santé, activité), leurs alertes et les
   * accès partagés existants. Un seul JSON structuré, pas de ZIP/CSV.
   *
   * Scope volontairement limité aux chiens dont il est `owner` — un chien
   * partagé avec lui (famille/viewer) appartient aux données de son
   * propriétaire, pas aux siennes.
   */
  async exportMyData(req: FastifyRequest, reply: FastifyReply) {
    const userId = req.userId;
    const prisma = getPrisma();

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      logger.warn({ userId }, 'GET /users/me/export — user not found');
      throw new NotFoundError('User', userId);
    }

    const ownedDogUsers = await prisma.dogUser.findMany({
      where: { userId, role: 'owner' },
      select: { dogId: true },
    });
    const dogIds = ownedDogUsers.map((d) => d.dogId);

    const dogs = await prisma.dog.findMany({
      where: { id: { in: dogIds } },
      include: {
        collar: true,
        alerts: { orderBy: { createdAt: 'desc' } },
        dogUsers: {
          include: {
            user: { select: { id: true, email: true, firstName: true, lastName: true } },
          },
        },
      },
    });

    const collarIds = dogs
      .map((dog) => dog.collar?.id)
      .filter((id): id is string => id !== undefined);

    const [gpsLocations, healthRecords, activityRecords] = await Promise.all([
      prisma.gpsLocation.findMany({
        where: { collarId: { in: collarIds } },
        orderBy: { recordedAt: 'desc' },
      }),
      prisma.healthRecord.findMany({
        where: { collarId: { in: collarIds } },
        orderBy: { recordedAt: 'desc' },
      }),
      prisma.activityRecord.findMany({
        where: { collarId: { in: collarIds } },
        orderBy: { recordedAt: 'desc' },
      }),
    ]);

    const payload = {
      exportedAt: new Date().toISOString(),
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        subscriptionPlan: user.subscriptionPlan,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      dogs: dogs.map((dog) => {
        const collarId = dog.collar?.id;
        return {
          id: dog.id,
          name: dog.name,
          breed: dog.breed,
          birthDate: dog.birthDate,
          weight: dog.weight,
          sex: dog.sex,
          allergies: dog.allergies,
          photoUrl: dog.photoUrl,
          avatarUrl: dog.avatarUrl,
          createdAt: dog.createdAt,
          updatedAt: dog.updatedAt,
          collar: dog.collar,
          sharedAccess: dog.dogUsers.map((du) => ({
            userId: du.userId,
            email: du.user.email,
            firstName: du.user.firstName,
            lastName: du.user.lastName,
            role: du.role,
            sharedSince: du.createdAt,
          })),
          alerts: dog.alerts,
          gpsLocations: collarId ? gpsLocations.filter((g) => g.collarId === collarId) : [],
          healthRecords: collarId ? healthRecords.filter((h) => h.collarId === collarId) : [],
          activityRecords: collarId
            ? activityRecords.filter((a) => a.collarId === collarId)
            : [],
        };
      }),
    };

    logger.info({ userId, dogCount: dogs.length }, 'Data export generated');

    reply.header('Content-Disposition', `attachment; filename="k9sync-export-${userId}.json"`);
    return reply.send(payload);
  }

  /**
   * RGPD — enregistre un ou plusieurs consentements pour l'utilisateur
   * authentifié. Chaque appel INSÈRE de nouvelles lignes plutôt que de
   * mettre à jour les existantes : c'est un registre de preuve légale
   * append-only, l'historique complet (qui a accepté/refusé quoi et quand)
   * doit rester consultable, pas seulement le dernier état.
   */
  async postConsents(req: FastifyRequest<{ Body: unknown }>, reply: FastifyReply) {
    const userId = req.userId;

    const body = postConsentsBodySchema.safeParse(req.body);
    if (!body.success) throw new ValidationError(body.error.flatten());
    const { consents } = body.data;

    const created = await getPrisma().consentLog.createMany({
      data: consents.map((c) => ({
        userId,
        type: c.type,
        accepted: c.accepted,
        version: c.version,
      })),
    });

    logger.info({ userId, count: created.count }, 'Consents recorded');
    return reply.status(201).send({ recorded: created.count });
  }

  /**
   * RGPD — état actuel de chaque type de consentement pour l'utilisateur
   * authentifié : le dernier enregistrement par type (l'historique complet
   * reste en base, seule la vue "état courant" est renvoyée ici).
   */
  async getConsents(req: FastifyRequest, reply: FastifyReply) {
    const userId = req.userId;

    const logs = await getPrisma().consentLog.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });

    const consents: Record<string, { accepted: boolean; version: string; createdAt: Date }> = {};
    for (const log of logs) {
      if (!(log.type in consents)) {
        consents[log.type] = {
          accepted: log.accepted,
          version: log.version,
          createdAt: log.createdAt,
        };
      }
    }

    return reply.send({ consents });
  }

  /**
   * Enregistre le token FCM de l'appareil courant pour l'utilisateur
   * authentifié. Un seul token par compte — le dernier appareil connecté
   * gagne (voir commentaire sur User.pushToken).
   */
  async registerPushToken(req: FastifyRequest<{ Body: unknown }>, reply: FastifyReply) {
    const userId = req.userId;

    const body = pushTokenBodySchema.safeParse(req.body);
    if (!body.success) throw new ValidationError(body.error.flatten());
    const { token } = body.data;

    await getPrisma().user.update({
      where: { id: userId },
      data: { pushToken: token },
    });

    logger.info({ userId }, 'Push token registered');
    return reply.status(204).send();
  }
}
