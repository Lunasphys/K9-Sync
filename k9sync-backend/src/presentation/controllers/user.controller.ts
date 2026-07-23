import { FastifyRequest, FastifyReply } from 'fastify';
import { getPrisma } from '../../config/database.js';
import { NotFoundError } from '../../shared/errors.js';
import { logger } from '../../shared/logger.js';

export class UserController {
  /**
   * Delete the authenticated user's account.
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
  async deleteMe(req: FastifyRequest, reply: FastifyReply) {
    const userId = req.userId;

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
}
