import Fastify from 'fastify';
import path from 'path';
import cors from '@fastify/cors';
import fastifyMultipart from '@fastify/multipart';
import fastifyStatic from '@fastify/static';
import { loadEnv } from './config/env.js';
import { authRoutes } from './presentation/routes/auth.routes.js';
import { userRoutes } from './presentation/routes/user.routes.js';
import { dogRoutes } from './presentation/routes/dog.routes.js';
import { uploadRoutes } from './presentation/routes/upload.routes.js';
import { gpsActivityRoutes } from './presentation/routes/gps_activity_routes.js';
import { logger } from './shared/logger.js';
import { AppError } from './shared/errors.js';

const env = loadEnv();

export async function buildApp() {
  const app = Fastify({ logger: false });

  // Fastify's default JSON parser throws on an empty body even when
  // Content-Type: application/json is set (e.g. POST /auth/logout with no
  // payload) — treat an empty body as "no body" instead of a parse error.
  app.addContentTypeParser(
    'application/json',
    { parseAs: 'string' },
    (_req, body, done) => {
      const raw = body as string;
      if (raw === '') {
        done(null, undefined);
        return;
      }
      try {
        done(null, JSON.parse(raw));
      } catch (err) {
        (err as { statusCode?: number }).statusCode = 400;
        done(err as Error, undefined);
      }
    },
  );

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof AppError) {
      return reply.status(error.statusCode).send({
        error: { code: error.code, message: error.message, ...(error.context && { context: error.context }) },
      });
    }

    // Some call sites still throw a plain Error/object with a bolted-on
    // .statusCode instead of a proper AppError subclass (e.g. requireDogAccess
    // in dog.routes.ts / dog.controller.ts: `const err: any = new Error(...);
    // err.statusCode = 403;`). Respect that status code too — otherwise a
    // legitimate 4xx gets reported to the client as a 500 "Unhandled error".
    const adHocStatus = (error as { statusCode?: unknown })?.statusCode;
    if (
      typeof adHocStatus === 'number' &&
      Number.isInteger(adHocStatus) &&
      adHocStatus >= 400 &&
      adHocStatus < 600
    ) {
      const message = error instanceof Error ? error.message : 'Request failed';
      return reply.status(adHocStatus).send({ error: { code: 'ERROR', message } });
    }

    logger.error({ err: error }, 'Unhandled error');
    return reply.status(500).send({
      error: { code: 'INTERNAL_ERROR', message: 'Internal server error' },
    });
  });

  await app.register(cors, { origin: true });

  await app.register(fastifyMultipart, {
    limits: { fileSize: 5 * 1024 * 1024 },
  });

  await app.register(fastifyStatic, {
    root: path.join(process.cwd(), 'uploads'),
    prefix: '/uploads/',
  });

  // Flutter baseUrl = https://api.k9sync.app/v1 → routes /v1/auth/*, /v1/dogs/*, etc.
  const rawPrefix = (env.API_PREFIX || 'v1').trim();
  const prefix = rawPrefix.startsWith('/') ? rawPrefix : `/${rawPrefix}`;
  await app.register(authRoutes, { prefix: `${prefix}/auth` });
  await app.register(userRoutes, { prefix: `${prefix}/users` });
  await app.register(dogRoutes, { prefix });
  await app.register(uploadRoutes, { prefix });
  await app.register(gpsActivityRoutes, { prefix });

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
