import { FastifyRequest, FastifyReply } from 'fastify';
import { getPrisma } from '../../config/database.js';
import { logger } from '../../shared/logger.js';
import { ConflictError, ForbiddenError, ValidationError } from '../../shared/errors.js';
import { requireDogAccess } from '../../shared/middleware/dog_access.middleware.js';
import { inviteBodySchema } from '../schemas/dog.schema.js';
import { pairCollarBodySchema } from '../schemas/collar.schema.js';

// ── GET /dogs ─────────────────────────────────────────────────────────────────

export async function getDogs(req: FastifyRequest, reply: FastifyReply) {
  const userDogs = await getPrisma().dogUser.findMany({
    where: {
      userId: req.userId,
    },
    include: { dog: true },
  });

  const dogs = userDogs.map((ud) => ud.dog);
  logger.info({ userId: req.userId, count: dogs.length }, 'GET /dogs');
  return reply.send(dogs);
}

// ── POST /dogs ────────────────────────────────────────────────────────────────

export async function createDog(
  req: FastifyRequest<{
    Body: {
      name: string;
      breed?: string;
      birthDate?: string;
      weight?: number;
      sex?: string;
      allergies?: string[];
      photoUrl?: string;
    };
  }>,
  reply: FastifyReply,
) {
  const { name, breed, birthDate, weight, sex, allergies, photoUrl } = req.body;

  const dog = await getPrisma().dog.create({
    data: {
      name,
      breed,
      birthDate: birthDate ? new Date(birthDate) : undefined,
      weight,
      sex,
      allergies: allergies ?? [],
      photoUrl,
    },
  });

  // Automatically make the creator the owner
  await getPrisma().dogUser.create({
    data: {
      userId: req.userId,
      dogId: dog.id,
      role: 'owner',
    },
  });

  logger.info({ userId: req.userId, dogId: dog.id }, 'Dog created');
  return reply.status(201).send(dog);
}

// ── GET /dogs/:dogId ──────────────────────────────────────────────────────────

export async function getDog(
  req: FastifyRequest<{ Params: { dogId: string } }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId);

  const dog = await getPrisma().dog.findUnique({
    where: { id: dogId },
    include: { collar: true, geofenceZone: true },
  });
  if (!dog) return reply.status(404).send({ error: 'Dog not found' });

  return reply.send(dog);
}

// ── PATCH /dogs/:dogId ────────────────────────────────────────────────────────

export async function updateDog(
  req: FastifyRequest<{
    Params: { dogId: string };
    Body: {
      name?: string;
      breed?: string;
      birthDate?: string;
      weight?: number;
      sex?: string;
      allergies?: string[];
      photoUrl?: string;
    };
  }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId, { requireOwner: true });

  const { birthDate, name, breed, weight, sex, allergies, photoUrl } = req.body;
  const data: Record<string, unknown> = {};
  if (name !== undefined) data.name = name;
  if (breed !== undefined) data.breed = breed;
  if (birthDate) data.birthDate = new Date(birthDate);
  if (weight !== undefined) data.weight = weight;
  if (sex !== undefined) data.sex = sex;
  if (allergies !== undefined) data.allergies = allergies;
  if (photoUrl !== undefined) data.photoUrl = photoUrl;

  const dog = await getPrisma().dog.update({
    where: { id: dogId },
    data,
  });

  logger.info({ userId: req.userId, dogId }, 'Dog updated');
  return reply.send(dog);
}

// ── POST /dogs/:dogId/invite ──────────────────────────────────────────────────

/**
 * Owner-only. If the invited email already has an account, access is
 * granted immediately (DogUser created). Otherwise the invitation is
 * deferred: a PendingInvite row is stored and resolved into a DogUser as
 * soon as someone registers with that exact email (see AuthController.register).
 */
export async function inviteToDog(
  req: FastifyRequest<{
    Params: { dogId: string };
    Body: unknown;
  }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId, { requireOwner: true });

  const body = inviteBodySchema.safeParse(req.body);
  if (!body.success) throw new ValidationError(body.error.flatten());
  const { email, role, expiresAt } = body.data;
  const grantExpiresAt = role === 'dog_sitter' ? new Date(expiresAt!) : null;

  const prisma = getPrisma();
  const existingUser = await prisma.user.findUnique({ where: { email } });

  if (existingUser) {
    const alreadyHasAccess = await prisma.dogUser.findFirst({
      where: { dogId, userId: existingUser.id },
    });
    if (alreadyHasAccess) {
      throw new ConflictError('userId', 'This user already has access to this dog');
    }

    const dogUser = await prisma.dogUser.create({
      data: { dogId, userId: existingUser.id, role, expiresAt: grantExpiresAt },
    });

    logger.info({ dogId, userId: existingUser.id, role }, 'Dog access granted (invite resolved immediately)');
    return reply.status(201).send({ status: 'granted', dogUser });
  }

  const pendingInvite = await prisma.pendingInvite.upsert({
    where: { dogId_email: { dogId, email } },
    create: { dogId, email, role, expiresAt: grantExpiresAt, invitedBy: req.userId },
    update: { role, expiresAt: grantExpiresAt, invitedBy: req.userId },
  });

  logger.info({ dogId, email, role }, 'Invite deferred — no account for this email yet');
  return reply.status(202).send({ status: 'pending', pendingInvite });
}

// ── GET /dogs/:dogId/users ─────────────────────────────────────────────────────

/** Active accesses on a dog — excludes any dog_sitter grant already expired. */
export async function listDogUsers(
  req: FastifyRequest<{ Params: { dogId: string } }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId);

  const dogUsers = await getPrisma().dogUser.findMany({
    where: {
      dogId,
      OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
    },
    include: {
      user: { select: { id: true, email: true, firstName: true, lastName: true } },
    },
    orderBy: { createdAt: 'asc' },
  });

  return reply.send(
    dogUsers.map((du) => ({
      userId: du.userId,
      email: du.user.email,
      firstName: du.user.firstName,
      lastName: du.user.lastName,
      role: du.role,
      expiresAt: du.expiresAt,
      since: du.createdAt,
    })),
  );
}

// ── DELETE /dogs/:dogId/users/:userId ───────────────────────────────────────────

/** Owner-only. The owner's own access can never be revoked this way. */
export async function revokeDogUser(
  req: FastifyRequest<{ Params: { dogId: string; userId: string } }>,
  reply: FastifyReply,
) {
  const { dogId, userId } = req.params;
  await requireDogAccess(req.userId, dogId, { requireOwner: true });

  const target = await getPrisma().dogUser.findFirst({ where: { dogId, userId } });
  if (!target) return reply.status(404).send({ error: 'Access not found' });

  if (target.role === 'owner') {
    throw new ForbiddenError('cannot revoke the owner\'s own access');
  }

  await getPrisma().dogUser.delete({ where: { id: target.id } });

  logger.info({ dogId, userId }, 'Dog access revoked');
  return reply.status(204).send();
}

// ── POST /dogs/:dogId/collar/pair ───────────────────────────────────────────────

/**
 * Owner-only. Jumelage par saisie manuelle du numéro de série (pas de scan
 * BLE). Trois cas :
 *  - le numéro n'existe pas encore en base -> on le crée et le jumelle
 *    (aucune autre voie de création n'existe : ni le simulateur ni le
 *    handler MQTT ne provisionnent de Collar avant un premier jumelage) ;
 *  - il existe mais n'est jumelé à aucun chien (dogId null) -> on le réclame ;
 *  - il est déjà jumelé à CE chien -> succès idempotent, aucune écriture ;
 *  - il est déjà jumelé à un AUTRE chien -> 409.
 * Un chien déjà équipé d'un collier différent ne peut pas en jumeler un
 * second sans être d'abord dé-jumelé (hors périmètre ce soir) -> 409.
 */
export async function pairCollar(
  req: FastifyRequest<{ Params: { dogId: string }; Body: unknown }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId, { requireOwner: true });

  const body = pairCollarBodySchema.safeParse(req.body);
  if (!body.success) throw new ValidationError(body.error.flatten());
  const { serialNumber } = body.data;

  const prisma = getPrisma();

  const dog = await prisma.dog.findUnique({ where: { id: dogId }, include: { collar: true } });
  if (!dog) return reply.status(404).send({ error: 'Dog not found' });

  if (dog.collar && dog.collar.serialNumber !== serialNumber) {
    throw new ConflictError('dogId', 'This dog is already paired with a different collar');
  }

  const existing = await prisma.collar.findUnique({ where: { serialNumber } });

  if (existing) {
    if (existing.dogId === dogId) {
      // Already paired to this exact dog — idempotent success, no-op.
      return reply.status(200).send(existing);
    }
    if (existing.dogId !== null) {
      throw new ConflictError('serialNumber', 'This collar is already paired with another dog');
    }

    const claimed = await prisma.collar.update({
      where: { id: existing.id },
      data: { dogId },
    });
    logger.info({ dogId, serialNumber }, 'Existing unclaimed collar paired');
    return reply.status(200).send(claimed);
  }

  const created = await prisma.collar.create({ data: { serialNumber, dogId } });
  logger.info({ dogId, serialNumber }, 'New collar provisioned and paired');
  return reply.status(201).send(created);
}

