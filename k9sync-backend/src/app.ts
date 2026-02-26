import Fastify from 'fastify';
import cors from '@fastify/cors';
import { loadEnv } from './config/env.js';
import { authRoutes } from './presentation/routes/auth.routes.js';
import { logger } from './shared/logger.js';
import { AppError } from './shared/errors.js';

const env = loadEnv();

export async function buildApp() {
  const app = Fastify({ logger: false });

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof AppError) {
      return reply.status(error.statusCode).send({
        error: { code: error.code, message: error.message, ...(error.context && { context: error.context }) },
      });
    }
    logger.error({ err: error }, 'Unhandled error');
    return reply.status(500).send({
      error: { code: 'INTERNAL_ERROR', message: 'Internal server error' },
    });
  });

  await app.register(cors, { origin: true });

  // Flutter baseUrl = https://api.k9sync.app/v1 → routes /v1/auth/*, /v1/dogs/*, etc.
  const rawPrefix = (env.API_PREFIX || 'v1').trim();
  const prefix = rawPrefix.startsWith('/') ? rawPrefix : `/${rawPrefix}`;
  await app.register(authRoutes, { prefix: `${prefix}/auth` });

  // Test: GET /v1/health
  app.get(`${prefix}/health`, async () => ({ ok: true, message: 'K9 Sync API' }));

  // 404 avec détail pour débogage
  app.setNotFoundHandler((request, reply) => {
    logger.warn({ method: request.method, url: request.url }, 'Route not found');
    return reply.status(404).send({
      error: {
        code: 'NOT_FOUND',
        message: 'Route not found',
        requested: { method: request.method, url: request.url },
        hint: 'Try GET /v1/health or POST /v1/auth/register (base URL must include /v1)',
      },
    });
  });

  return app;
}
