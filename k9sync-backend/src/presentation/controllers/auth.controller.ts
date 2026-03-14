import { FastifyRequest, FastifyReply } from 'fastify';
import { getPrisma } from '../../config/database.js';
import { logger } from '../../shared/logger.js';
import { ValidationError, UnauthorizedError, ConflictError } from '../../shared/errors.js';
import bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';
import {
  registerBodySchema,
  loginBodySchema,
  refreshBodySchema,
  forgotPasswordBodySchema,
} from '../schemas/auth.schema.js';
import type { RegisterBody, LoginBody, RefreshBody } from '../schemas/auth.schema.js';

// Minimal JWT signing for skeleton — replace with proper JWT (e.g. jsonwebtoken RS256)
function signAccessToken(payload: { sub: string }): string {
  const secret = process.env.JWT_ACCESS_SECRET ?? '';
  return Buffer.from(JSON.stringify({ ...payload, iat: Date.now() })).toString('base64') + '.' + secret.slice(0, 8);
}

function userToJson(user: {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  phone: string | null;
  subscriptionPlan: string;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: user.id,
    email: user.email,
    firstName: user.firstName,
    lastName: user.lastName,
    phone: user.phone,
    subscriptionPlan: user.subscriptionPlan,
    createdAt: user.createdAt.toISOString(),
    updatedAt: user.updatedAt.toISOString(),
  };
}

export class AuthController {
  async register(req: FastifyRequest<{ Body: unknown }>, reply: FastifyReply) {
    const body = registerBodySchema.safeParse(req.body);
    if (!body.success) throw new ValidationError(body.error.flatten());
    const { email, password, firstName, lastName } = body.data as RegisterBody;

    const existing = await getPrisma().user.findUnique({ where: { email } });
    if (existing) throw new ConflictError('email', 'Email already in use');

    const passwordHash = await bcrypt.hash(password, 12);
    const user = await getPrisma().user.create({
      data: { email, passwordHash, firstName, lastName, subscriptionPlan: 'free' },
    });

    const accessToken = signAccessToken({ sub: user.id });
    const refreshRaw = uuidv4();
    const refreshHash = await bcrypt.hash(refreshRaw, 12);
    const expiresAt = new Date(Date.now() + (Number(process.env.JWT_REFRESH_EXPIRES_DAYS) ?? 7) * 24 * 60 * 60 * 1000);
    await getPrisma().refreshToken.create({
      data: { userId: user.id, token: refreshHash, expiresAt },
    });

    logger.info({ userId: user.id, event: 'register' }, 'User registered');
    return reply.status(201).send({
      user: userToJson(user),
      accessToken,
      refreshToken: refreshRaw,
    });
  }

  async login(req: FastifyRequest<{ Body: unknown }>, reply: FastifyReply) {
    const body = loginBodySchema.safeParse(req.body);
    if (!body.success) throw new ValidationError(body.error.flatten());
    const { email, password } = body.data as LoginBody;

    const user = await getPrisma().user.findUnique({ where: { email } });
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new UnauthorizedError('Invalid email or password');
    }

    const accessToken = signAccessToken({ sub: user.id });
    const refreshRaw = uuidv4();
    const refreshHash = await bcrypt.hash(refreshRaw, 12);
    const expiresAt = new Date(Date.now() + (Number(process.env.JWT_REFRESH_EXPIRES_DAYS) ?? 7) * 24 * 60 * 60 * 1000);
    await getPrisma().refreshToken.create({
      data: { userId: user.id, token: refreshHash, expiresAt },
    });

    logger.info({ userId: user.id, event: 'login' }, 'User logged in');
    return reply.send({
      user: userToJson(user),
      accessToken,
      refreshToken: refreshRaw,
    });
  }

  async refresh(req: FastifyRequest<{ Body: unknown }>, reply: FastifyReply) {
    const body = refreshBodySchema.safeParse(req.body);
    if (!body.success) throw new ValidationError(body.error.flatten());
    const { refreshToken: rawToken } = body.data as RefreshBody;

    const tokens = await getPrisma().refreshToken.findMany({
      where: { expiresAt: { gt: new Date() } },
      include: { user: true },
    });
    let match: (typeof tokens)[0] | null = null;
    for (const t of tokens) {
      if (await bcrypt.compare(rawToken, t.token)) {
        match = t;
        break;
      }
    }
    if (!match) throw new UnauthorizedError('Invalid or expired refresh token');

    await getPrisma().refreshToken.delete({ where: { id: match.id } });
    const newRaw = uuidv4();
    const newHash = await bcrypt.hash(newRaw, 12);
    const expiresAt = new Date(Date.now() + (Number(process.env.JWT_REFRESH_EXPIRES_DAYS) ?? 7) * 24 * 60 * 60 * 1000);
    await getPrisma().refreshToken.create({
      data: { userId: match.userId, token: newHash, expiresAt },
    });

    const accessToken = signAccessToken({ sub: match.user.id });
    return reply.send({
      user: userToJson(match.user),
      accessToken,
      refreshToken: newRaw,
    });
  }

  async logout(
    req: FastifyRequest<{ Body: { refreshToken?: string } }>,
    reply: FastifyReply,
  ) {
    const { refreshToken } = (req.body ?? {}) as { refreshToken?: string };

    if (refreshToken) {
      const tokens = await getPrisma().refreshToken.findMany({
        where: {
          userId: req.userId,
          expiresAt: { gt: new Date() },
        },
      });

      for (const stored of tokens) {
        const match = await bcrypt.compare(refreshToken, stored.token);
        if (match) {
          await getPrisma().refreshToken.delete({ where: { id: stored.id } });
          break;
        }
      }
    }

    return reply.status(204).send();
  }

  async forgotPassword(req: FastifyRequest<{ Body: unknown }>, reply: FastifyReply) {
    const body = forgotPasswordBodySchema.safeParse(req.body);
    if (!body.success) throw new ValidationError(body.error.flatten());
    // TODO: send reset email (e.g. SendGrid, Firebase Auth, or custom token)
    logger.info({ email: (body.data as { email: string }).email }, 'Forgot password requested');
    return reply.status(202).send({ message: 'If the email exists, a reset link was sent.' });
  }
}
