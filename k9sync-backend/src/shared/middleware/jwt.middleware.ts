import { FastifyRequest, FastifyReply } from 'fastify';
import { UnauthorizedError } from '../errors.js';

// Extend FastifyRequest to carry the authenticated user id
declare module 'fastify' {
  interface FastifyRequest {
    userId: string;
  }
}

// Mirrors the minimal signing logic in auth.controller.ts:
// token = base64(JSON payload) + '.' + secret.slice(0, 8)
export async function jwtAuth(req: FastifyRequest, _reply: FastifyReply): Promise<void> {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    throw new UnauthorizedError('Missing authorization header');
  }

  const token = header.slice(7);
  const dotIndex = token.lastIndexOf('.');
  if (dotIndex === -1) throw new UnauthorizedError('Invalid token format');

  const payloadB64 = token.slice(0, dotIndex);
  const sentSecret = token.slice(dotIndex + 1);

  // Verify the secret suffix matches
  const expectedSecret = (process.env.JWT_ACCESS_SECRET ?? '').slice(0, 8);
  if (sentSecret !== expectedSecret) {
    throw new UnauthorizedError('Invalid token signature');
  }

  let payload: { sub?: string; iat?: number };
  try {
    payload = JSON.parse(Buffer.from(payloadB64, 'base64').toString('utf8'));
  } catch {
    throw new UnauthorizedError('Malformed token payload');
  }

  if (!payload.sub) throw new UnauthorizedError('Token missing subject');

  req.userId = payload.sub;
}
