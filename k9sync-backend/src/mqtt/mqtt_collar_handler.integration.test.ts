// Integration test — requires a reachable Postgres (see .env / docker-compose.yml:
// `docker compose up -d postgres`). Not part of `npm test` / CI, which has no
// database available. Run manually: npm run test:integration
import '../load-env.js';
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { initPrisma, getPrisma } from '../config/database.js';
import { handleHealthMessage } from './mqtt_collar_handler.js';

initPrisma(process.env.DATABASE_URL ?? '');
const prisma = getPrisma();

after(async () => {
  await prisma.$disconnect();
});

test('handleHealthMessage persists steps/activeMinutes/sleepPhase into an ActivityRecord', async () => {
  const dog = await prisma.dog.create({ data: { name: 'MqttActivityDog' } });
  const serialNumber = `MQTT-ACT-${randomUUID()}`;
  const collar = await prisma.collar.create({ data: { serialNumber, dogId: dog.id } });

  await handleHealthMessage(serialNumber, {
    collarSerial: serialNumber,
    dogId: dog.id,
    heartRate: 90,
    temperature: 38.2,
    steps: 1234,
    activeMinutes: 15,
    sleepPhase: 'light',
    recordedAt: new Date().toISOString(),
  });

  const activityRecords = await prisma.activityRecord.findMany({
    where: { collarId: collar.id },
  });
  assert.equal(activityRecords.length, 1, 'an ActivityRecord must be created from the health message');
  assert.equal(activityRecords[0].steps, 1234);
  assert.equal(activityRecords[0].activeMinutes, 15);
  assert.equal(activityRecords[0].sleepPhase, 'light');

  // The HealthRecord path must still work exactly as before
  const healthRecords = await prisma.healthRecord.findMany({ where: { collarId: collar.id } });
  assert.equal(healthRecords.length, 1);
  assert.equal(healthRecords[0].heartRate, 90);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
});

test('handleHealthMessage does not create an ActivityRecord when the message carries no activity/sleep data', async () => {
  const dog = await prisma.dog.create({ data: { name: 'MqttNoActivityDog' } });
  const serialNumber = `MQTT-NOACT-${randomUUID()}`;
  const collar = await prisma.collar.create({ data: { serialNumber, dogId: dog.id } });

  await handleHealthMessage(serialNumber, {
    collarSerial: serialNumber,
    dogId: dog.id,
    heartRate: 90,
    temperature: 38.2,
    recordedAt: new Date().toISOString(),
  });

  const activityRecords = await prisma.activityRecord.findMany({
    where: { collarId: collar.id },
  });
  assert.equal(activityRecords.length, 0);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
});
