import { FastifyRequest, FastifyReply } from 'fastify';
import { getPrisma } from '../../config/database.js';
import { NotFoundError } from '../../shared/errors.js';
import { logger } from '../../shared/logger.js';

export class UserController {
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
