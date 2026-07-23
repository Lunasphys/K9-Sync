import { FastifyRequest, FastifyReply } from 'fastify';
import jwt from 'jsonwebtoken';
import { UnauthorizedError } from '../errors.js';

// Extend FastifyRequest to carry the authenticated user id
declare module 'fastify' {
  interface FastifyRequest {
    userId: string;
  }
}

export async function jwtAuth(req: FastifyRequest, _reply: FastifyReply): Promise<void> {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    throw new UnauthorizedError('Missing authorization header');
  }

  const token = header.slice(7);
  const secret = process.env.JWT_ACCESS_SECRET ?? '';

  let payload: string | jwt.JwtPayload;
  try {
    payload = jwt.verify(token, secret);
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      throw new UnauthorizedError('Token expired');
    }
    throw new UnauthorizedError('Invalid token signature');
  }

  if (typeof payload === 'string' || !payload.sub) {
    throw new UnauthorizedError('Token missing subject');
  }

  req.userId = payload.sub;
}
