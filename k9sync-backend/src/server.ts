import './load-env.js';
import { buildApp } from './app.js';
import { loadEnv } from './config/env.js';
import { initPrisma, getPrisma } from './config/database.js';
import { logger } from './shared/logger.js';

const env = loadEnv();
initPrisma(env.DATABASE_URL);

async function main() {
  const app = await buildApp();
  const prisma = getPrisma();

  try {
    await prisma.$connect();
    logger.info('Database connected');
  } catch (e) {
    logger.fatal({ err: e }, 'Database connection failed');
    process.exit(1);
  }

  await app.listen({ port: env.PORT, host: '0.0.0.0' });
  logger.info({ port: env.PORT, prefix: env.API_PREFIX }, 'K9 Sync API listening');

  const shutdown = async () => {
    await app.close();
    await prisma.$disconnect();
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  logger.fatal({ err }, 'Startup failed');
  process.exit(1);
});
