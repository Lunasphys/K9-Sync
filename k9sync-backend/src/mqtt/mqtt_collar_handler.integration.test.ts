// Integration test — requires a reachable Postgres (see .env / docker-compose.yml:
// `docker compose up -d postgres`). Not part of `npm test` / CI, which has no
// database available. Run manually: npm run test:integration
import '../load-env.js';
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { initPrisma, getPrisma } from '../config/database.js';
import { handleHealthMessage, handleGpsMessage } from './mqtt_collar_handler.js';

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

// ── Geofencing ────────────────────────────────────────────────────────────────

const ZONE_LAT = 45.7578;
const ZONE_LNG = 4.832;
const ZONE_RADIUS_M = 50;
// ~310m east of the zone center at this latitude — well outside a 50m radius.
const OUTSIDE_LNG = 4.836;

async function setupDogWithZone() {
  const dog = await prisma.dog.create({ data: { name: `GeofenceMqttDog-${randomUUID()}` } });
  const serialNumber = `MQTT-GEO-${randomUUID()}`;
  const collar = await prisma.collar.create({ data: { serialNumber, dogId: dog.id } });
  await prisma.geofenceZone.create({
    data: {
      dogId: dog.id,
      latitude: ZONE_LAT,
      longitude: ZONE_LNG,
      radiusM: ZONE_RADIUS_M,
      isInside: true,
    },
  });
  return { dog, serialNumber, collar };
}

function gpsPayload(serialNumber: string, dogId: string, latitude: number, longitude: number) {
  return {
    collarSerial: serialNumber,
    dogId,
    latitude,
    longitude,
    recordedAt: new Date().toISOString(),
  };
}

test('handleGpsMessage detects a dedans->dehors transition: creates a geofence Alert and flips isInside', async () => {
  const { dog, serialNumber } = await setupDogWithZone();

  await handleGpsMessage(serialNumber, gpsPayload(serialNumber, dog.id, ZONE_LAT, OUTSIDE_LNG));

  const zone = await prisma.geofenceZone.findUnique({ where: { dogId: dog.id } });
  assert.equal(zone?.isInside, false);

  const alerts = await prisma.alert.findMany({ where: { dogId: dog.id, type: 'geofence' } });
  assert.equal(alerts.length, 1);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
});

test('handleGpsMessage does not re-trigger an alert on every message while the dog stays outside', async () => {
  const { dog, serialNumber } = await setupDogWithZone();

  await handleGpsMessage(serialNumber, gpsPayload(serialNumber, dog.id, ZONE_LAT, OUTSIDE_LNG));
  // Two more GPS pings, still outside — must not create additional alerts.
  await handleGpsMessage(serialNumber, gpsPayload(serialNumber, dog.id, ZONE_LAT, OUTSIDE_LNG));
  await handleGpsMessage(serialNumber, gpsPayload(serialNumber, dog.id, ZONE_LAT, OUTSIDE_LNG));

  const alerts = await prisma.alert.findMany({ where: { dogId: dog.id, type: 'geofence' } });
  assert.equal(alerts.length, 1, 'staying outside must not create a second alert');

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
});

test('handleGpsMessage: re-entering the zone then exiting again creates a second, new alert', async () => {
  const { dog, serialNumber } = await setupDogWithZone();

  await handleGpsMessage(serialNumber, gpsPayload(serialNumber, dog.id, ZONE_LAT, OUTSIDE_LNG));
  let zone = await prisma.geofenceZone.findUnique({ where: { dogId: dog.id } });
  assert.equal(zone?.isInside, false);

  // Re-entry: back at the zone center — must not create a new alert.
  await handleGpsMessage(serialNumber, gpsPayload(serialNumber, dog.id, ZONE_LAT, ZONE_LNG));
  zone = await prisma.geofenceZone.findUnique({ where: { dogId: dog.id } });
  assert.equal(zone?.isInside, true);
  let alerts = await prisma.alert.findMany({ where: { dogId: dog.id, type: 'geofence' } });
  assert.equal(alerts.length, 1, 're-entry must not create an alert of its own');

  // Exit again — this is a fresh transition, must create a second alert.
  await handleGpsMessage(serialNumber, gpsPayload(serialNumber, dog.id, ZONE_LAT, OUTSIDE_LNG));
  zone = await prisma.geofenceZone.findUnique({ where: { dogId: dog.id } });
  assert.equal(zone?.isInside, false);
  alerts = await prisma.alert.findMany({ where: { dogId: dog.id, type: 'geofence' }, orderBy: { createdAt: 'asc' } });
  assert.equal(alerts.length, 2, 'a new exit after a re-entry must create a new alert');

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
