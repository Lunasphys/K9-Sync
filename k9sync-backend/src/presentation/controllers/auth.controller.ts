import { FastifyRequest, FastifyReply } from 'fastify';
import { randomInt } from 'node:crypto';
import { getPrisma } from '../../config/database.js';
import { logger } from '../../shared/logger.js';
import { ValidationError, UnauthorizedError, ConflictError } from '../../shared/errors.js';
import { mailer } from '../../shared/mailer.js';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import {
  registerBodySchema,
  loginBodySchema,
  refreshBodySchema,
  forgotPasswordBodySchema,
  resetPasswordBodySchema,
} from '../schemas/auth.schema.js';
import type { RegisterBody, LoginBody, RefreshBody, ResetPasswordBody } from '../schemas/auth.schema.js';

// Shorter than a refresh token (JWT_REFRESH_EXPIRES_DAYS) on purpose: a
// reset code is used within minutes of the email arriving, never kept
// around as a standing session.
const PASSWORD_RESET_EXPIRES_MIN = 20;

function signAccessToken(payload: { sub: string }): string {
  const secret = process.env.JWT_ACCESS_SECRET ?? '';
  const expiresIn = process.env.JWT_ACCESS_EXPIRES_IN ?? '15m';
  return jwt.sign(payload, secret, { expiresIn } as jwt.SignOptions);
}

/** Cryptographically random 6-digit code (000000-999999), zero-padded. */
function generateResetCode(): string {
  return String(randomInt(0, 1_000_000)).padStart(6, '0');
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

    // Resolve any dog-share invitation sent to this email before the account existed.
    const pendingInvites = await getPrisma().pendingInvite.findMany({ where: { email } });
    if (pendingInvites.length > 0) {
      await getPrisma().$transaction([
        ...pendingInvites.map((invite) =>
          getPrisma().dogUser.create({
            data: {
              dogId: invite.dogId,
              userId: user.id,
              role: invite.role,
              expiresAt: invite.expiresAt,
            },
          }),
        ),
        getPrisma().pendingInvite.deleteMany({ where: { email } }),
      ]);
      logger.info(
        { userId: user.id, email, count: pendingInvites.length },
        'Pending dog-share invites resolved at registration',
      );
    }

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

    // Atomic, conditional delete — avoids the TOCTOU window between the
    // findMany above and this delete. Under concurrent refresh calls with
    // the same raw token (e.g. several API calls 401-ing at once and each
    // triggering a refresh), only one deleteMany can match this still-alive
    // row; the loser gets count 0 instead of crashing on a delete-by-id of
    // an already-deleted row. A refresh token is single-use by design, so
    // the loser must re-authenticate — that's correct, not a bug.
    const { count } = await getPrisma().refreshToken.deleteMany({
      where: { id: match.id, expiresAt: { gt: new Date() } },
    });
    if (count === 0) {
      throw new UnauthorizedError('Refresh token already used — please log in again');
    }
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

  /**
   * Always responds 202 with the same message whether or not the email has
   * an account — the response must never leak account existence. Sending
   * the email is best-effort: a delivery failure is logged but never
   * surfaced to the caller, for the same reason.
   */
  async forgotPassword(req: FastifyRequest<{ Body: unknown }>, reply: FastifyReply) {
    const body = forgotPasswordBodySchema.safeParse(req.body);
    if (!body.success) throw new ValidationError(body.error.flatten());
    const { email } = body.data as { email: string };

    const user = await getPrisma().user.findUnique({ where: { email } });
    if (user) {
      const code = generateResetCode();
      const codeHash = await bcrypt.hash(code, 12);
      const expiresAt = new Date(Date.now() + PASSWORD_RESET_EXPIRES_MIN * 60 * 1000);
      await getPrisma().passwordResetToken.create({
        data: { userId: user.id, token: codeHash, expiresAt },
      });

      try {
        await mailer.sendPasswordResetEmail(user.email, code, PASSWORD_RESET_EXPIRES_MIN);
      } catch (err) {
        logger.warn({ err, userId: user.id }, 'Password reset email failed to send (non-fatal)');
      }

      logger.info({ userId: user.id, event: 'forgot_password' }, 'Password reset code generated');
    } else {
      logger.info({ email }, 'Forgot password requested for unknown email');
    }

    return reply.status(202).send({ message: 'If the email exists, a reset code was sent.' });
  }

  /**
   * Verifies the 6-digit code, sets the new password, and invalidates every
   * existing session (all RefreshToken rows) — a password reset must log
   * out every device, not just prove ownership of the account.
   */
  async resetPassword(req: FastifyRequest<{ Body: unknown }>, reply: FastifyReply) {
    const body = resetPasswordBodySchema.safeParse(req.body);
    if (!body.success) throw new ValidationError(body.error.flatten());
    const { email, code, newPassword } = body.data as ResetPasswordBody;

    const user = await getPrisma().user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedError('Invalid or expired reset code');

    const tokens = await getPrisma().passwordResetToken.findMany({
      where: { userId: user.id, expiresAt: { gt: new Date() } },
    });
    let match: (typeof tokens)[0] | null = null;
    for (const t of tokens) {
      if (await bcrypt.compare(code, t.token)) {
        match = t;
        break;
      }
    }
    if (!match) throw new UnauthorizedError('Invalid or expired reset code');

    // Atomic, conditional delete — same TOCTOU-safe pattern as /auth/refresh:
    // a concurrent reset attempt with the same code can't both succeed.
    const { count } = await getPrisma().passwordResetToken.deleteMany({
      where: { id: match.id, expiresAt: { gt: new Date() } },
    });
    if (count === 0) throw new UnauthorizedError('Invalid or expired reset code');

    const newHash = await bcrypt.hash(newPassword, 12);
    await getPrisma().user.update({ where: { id: user.id }, data: { passwordHash: newHash } });

    // Any other outstanding codes for this user are now moot — the account
    // just changed password, no reason to leave them valid for their
    // remaining minutes.
    await getPrisma().passwordResetToken.deleteMany({ where: { userId: user.id } });

    // Log out every device — not just invalidate the code.
    await getPrisma().refreshToken.deleteMany({ where: { userId: user.id } });

    logger.info({ userId: user.id, event: 'reset_password' }, 'Password reset — all sessions invalidated');
    return reply.status(204).send();
  }
}
