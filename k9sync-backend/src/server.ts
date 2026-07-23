import './load-env.js';
import { buildApp } from './app.js';
import { loadEnv } from './config/env.js';
import { initPrisma, getPrisma } from './config/database.js';
import { logger } from './shared/logger.js';
import { connectMqtt } from './mqtt/mqtt_client.js';
import type { MqttClient } from 'mqtt';

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

  let mqttClient: MqttClient | undefined;
  if (env.MQTT_BROKER_URL) {
    mqttClient = connectMqtt(env.MQTT_BROKER_URL, {
      username: env.MQTT_USERNAME,
      password: env.MQTT_PASSWORD,
    });
  } else {
    logger.warn('MQTT_BROKER_URL not set — MQTT ingestion disabled');
  }

  await app.listen({ port: env.PORT, host: '0.0.0.0' });
  logger.info({ port: env.PORT, prefix: env.API_PREFIX }, 'K9 Sync API listening');

  const shutdown = async () => {
    await app.close();
    mqttClient?.end();
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
