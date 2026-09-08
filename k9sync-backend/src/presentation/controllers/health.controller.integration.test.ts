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
import { syncHealth, getHealthLatest } from './health.controller.js';
import { pushNotifications } from '../../shared/push_notifications.js';

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

async function createOwnerWithCollar(dogName: string) {
  const hash = await bcrypt.hash('irrelevant', 4);
  const owner = await prisma.user.create({
    data: {
      email: `owner-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Owner',
      lastName: 'User',
    },
  });
  const dog = await prisma.dog.create({ data: { name: dogName } });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: owner.id, role: 'owner' } });
  const collar = await prisma.collar.create({
    data: { serialNumber: `PUSH-${randomUUID()}`, dogId: dog.id },
  });
  return { owner, dog, collar };
}

async function createDogWithAccess(role: 'family' | 'dog_sitter', expiresAt?: Date) {
  const hash = await bcrypt.hash('irrelevant', 4);
  const user = await prisma.user.create({
    data: {
      email: `health-${role}-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Test',
      lastName: role,
    },
  });
  const dog = await prisma.dog.create({ data: { name: `HealthDog-${randomUUID()}` } });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: user.id, role, expiresAt } });
  const collar = await prisma.collar.create({
    data: { serialNumber: `HEALTH-${randomUUID()}`, dogId: dog.id },
  });
  await prisma.healthRecord.create({
    data: { collarId: collar.id, heartRate: 90, recordedAt: new Date() },
  });
  return { user, dog, collar };
}

after(async () => {
  await prisma.$disconnect();
});

test('syncHealth triggers a push notification when an anomaly is detected', async (t) => {
  const { owner, dog } = await createOwnerWithCollar('PushAnomalyDog');

  const calls: Array<{ dogId: string; payload: unknown }> = [];
  t.mock.method(
    pushNotifications,
    'notifyDogAccessHolders',
    async (dogId: string, payload: unknown) => {
      calls.push({ dogId, payload });
    },
  );

  const reply = fakeReply();
  await syncHealth(
    fakeRequest(owner.id, { dogId: dog.id }, {
      records: [{ heartRate: 220, recordedAt: new Date().toISOString() }], // > 180 bpm -> anomaly
    }),
    reply as unknown as FastifyReply,
  );

  assert.equal((reply.payload as { synced: number }).synced, 1);
  assert.equal(calls.length, 1, 'an anomalous record must trigger exactly one push notification');
  assert.equal(calls[0].dogId, dog.id);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('GET /dogs/:dogId/health/latest refuses a dog_sitter whose access has expired', async () => {
  const { user, dog } = await createDogWithAccess('dog_sitter', new Date(Date.now() - 60 * 60 * 1000));

  await assert.rejects(
    () => getHealthLatest(fakeRequest(user.id, { dogId: dog.id }), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: user.id } });
});

test('GET /dogs/:dogId/health/latest allows a dog_sitter whose access is still within its window', async () => {
  const { user, dog } = await createDogWithAccess('dog_sitter', new Date(Date.now() + 60 * 60 * 1000));

  const reply = fakeReply();
  await getHealthLatest(fakeRequest(user.id, { dogId: dog.id }), reply as unknown as FastifyReply);
  assert.equal(reply.statusCode, 200);

  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: user.id } });
});

test('syncHealth does not trigger a push notification for a normal record', async (t) => {
  const { owner, dog } = await createOwnerWithCollar('PushNormalDog');

  const calls: Array<unknown> = [];
  t.mock.method(pushNotifications, 'notifyDogAccessHolders', async () => {
    calls.push(undefined);
  });

  const reply = fakeReply();
  await syncHealth(
    fakeRequest(owner.id, { dogId: dog.id }, {
      records: [{ heartRate: 90, recordedAt: new Date().toISOString() }], // within range
    }),
    reply as unknown as FastifyReply,
  );

  assert.equal((reply.payload as { synced: number }).synced, 1);
  assert.equal(calls.length, 0, 'a normal record must never trigger a push notification');

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});
