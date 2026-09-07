// Integration test — requires a reachable Postgres (see .env / docker-compose.yml:
// `docker compose up -d postgres`). Not part of `npm test` / CI, which has no
// database available. Run manually: npm run test:integration
import '../../load-env.js';
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import bcrypt from 'bcrypt';
import type { FastifyReply, FastifyRequest } from 'fastify';
import { initPrisma, getPrisma } from '../../config/database.js';
import { upsertGeofence, deleteGeofence } from './geofence.controller.js';

initPrisma(process.env.DATABASE_URL ?? '');
const prisma = getPrisma();

function fakeRequest(userId: string, params: Record<string, string>, body?: unknown): FastifyRequest {
  return { userId, params, body } as unknown as FastifyRequest;
}

function fakeReply() {
  const reply = {
    statusCode: 200,
    payload: undefined as unknown,
    status(code: number) {
      reply.statusCode = code;
      return reply;
    },
    header(_name: string, _value: string) {
      return reply;
    },
    send(payload?: unknown) {
      reply.payload = payload;
      return reply;
    },
  };
  return reply;
}

async function createDogWithAccess(role: 'owner' | 'family' | 'dog_sitter') {
  const hash = await bcrypt.hash('irrelevant', 4);
  const user = await prisma.user.create({
    data: {
      email: `geofence-${role}-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Test',
      lastName: role,
    },
  });
  const dog = await prisma.dog.create({ data: { name: `GeofenceDog-${randomUUID()}` } });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: user.id, role } });
  return { user, dog };
}

async function cleanup(dogId: string, userId: string) {
  await prisma.geofenceZone.deleteMany({ where: { dogId } });
  await prisma.dog.delete({ where: { id: dogId } });
  await prisma.user.delete({ where: { id: userId } });
}

after(async () => {
  await prisma.$disconnect();
});

test('PUT /dogs/:dogId/geofence creates a zone for the owner', async () => {
  const { user, dog } = await createDogWithAccess('owner');
  const reply = fakeReply();

  await upsertGeofence(
    fakeRequest(user.id, { dogId: dog.id }, { latitude: 45.7578, longitude: 4.832, radiusM: 100 }),
    reply as unknown as FastifyReply,
  );

  assert.equal(reply.statusCode, 200);
  const zone = await prisma.geofenceZone.findUnique({ where: { dogId: dog.id } });
  assert.ok(zone);
  assert.equal(zone?.radiusM, 100);
  assert.equal(zone?.latitude, 45.7578);
  assert.equal(zone?.isInside, true);

  await cleanup(dog.id, user.id);
});

test('PUT /dogs/:dogId/geofence upserts — a second call replaces the single zone, not a duplicate', async () => {
  const { user, dog } = await createDogWithAccess('owner');
  const reply1 = fakeReply();
  await upsertGeofence(
    fakeRequest(user.id, { dogId: dog.id }, { latitude: 45.75, longitude: 4.83, radiusM: 50 }),
    reply1 as unknown as FastifyReply,
  );
  const reply2 = fakeReply();
  await upsertGeofence(
    fakeRequest(user.id, { dogId: dog.id }, { latitude: 45.76, longitude: 4.84, radiusM: 200 }),
    reply2 as unknown as FastifyReply,
  );

  assert.equal(reply2.statusCode, 200);
  const zones = await prisma.geofenceZone.findMany({ where: { dogId: dog.id } });
  assert.equal(zones.length, 1, 'a single circle per dog — the second call must update, not insert');
  assert.equal(zones[0].radiusM, 200);
  assert.equal(zones[0].latitude, 45.76);

  await cleanup(dog.id, user.id);
});

test('PUT /dogs/:dogId/geofence refuses a non-owner (family)', async () => {
  const { user, dog } = await createDogWithAccess('family');
  const reply = fakeReply();

  await assert.rejects(
    () =>
      upsertGeofence(
        fakeRequest(user.id, { dogId: dog.id }, { latitude: 45.7578, longitude: 4.832, radiusM: 100 }),
        reply as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );
  assert.equal(await prisma.geofenceZone.count({ where: { dogId: dog.id } }), 0);

  await cleanup(dog.id, user.id);
});

test('PUT /dogs/:dogId/geofence refuses a radius below the minimum', async () => {
  const { user, dog } = await createDogWithAccess('owner');
  const reply = fakeReply();

  await assert.rejects(
    () =>
      upsertGeofence(
        fakeRequest(user.id, { dogId: dog.id }, { latitude: 45.7578, longitude: 4.832, radiusM: 5 }),
        reply as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 400);
      assert.equal((err as { code?: string }).code, 'GEOFENCE_RADIUS_TOO_SMALL');
      return true;
    },
  );
  assert.equal(await prisma.geofenceZone.count({ where: { dogId: dog.id } }), 0);

  await cleanup(dog.id, user.id);
});

test('DELETE /dogs/:dogId/geofence removes the zone and is idempotent when called again', async () => {
  const { user, dog } = await createDogWithAccess('owner');
  await upsertGeofence(
    fakeRequest(user.id, { dogId: dog.id }, { latitude: 45.7578, longitude: 4.832, radiusM: 100 }),
    fakeReply() as unknown as FastifyReply,
  );

  const reply1 = fakeReply();
  await deleteGeofence(fakeRequest(user.id, { dogId: dog.id }), reply1 as unknown as FastifyReply);
  assert.equal(reply1.statusCode, 204);
  assert.equal(await prisma.geofenceZone.count({ where: { dogId: dog.id } }), 0);

  // Calling it again with no zone left must not throw.
  const reply2 = fakeReply();
  await deleteGeofence(fakeRequest(user.id, { dogId: dog.id }), reply2 as unknown as FastifyReply);
  assert.equal(reply2.statusCode, 204);

  await cleanup(dog.id, user.id);
});
