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
import { syncActivity, getSleepSummary, getActivitySummary } from './activity.controller.js';
import { pushNotifications } from '../../shared/push_notifications.js';

initPrisma(process.env.DATABASE_URL ?? '');
const prisma = getPrisma();

function fakeRequest(
  userId: string,
  params: Record<string, string>,
  query: Record<string, string> = {},
  body?: unknown,
): FastifyRequest {
  return { userId, params, query, body } as unknown as FastifyRequest;
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
    data: { serialNumber: `ACT-${randomUUID()}`, dogId: dog.id },
  });
  return { owner, dog, collar };
}

// A freshly-created dog that has never had a collar paired — the state a
// brand-new user is in right after adding their dog.
async function createOwnerWithoutCollar(dogName: string) {
  const hash = await bcrypt.hash('irrelevant', 4);
  const owner = await prisma.user.create({
    data: {
      email: `owner-nocollar-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Owner',
      lastName: 'User',
    },
  });
  const dog = await prisma.dog.create({ data: { name: dogName } });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: owner.id, role: 'owner' } });
  return { owner, dog };
}

async function createDogWithAccess(role: 'family' | 'dog_sitter', expiresAt?: Date) {
  const hash = await bcrypt.hash('irrelevant', 4);
  const user = await prisma.user.create({
    data: {
      email: `activity-${role}-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Test',
      lastName: role,
    },
  });
  const dog = await prisma.dog.create({ data: { name: `ActivityDog-${randomUUID()}` } });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: user.id, role, expiresAt } });
  const collar = await prisma.collar.create({
    data: { serialNumber: `ACT-ACCESS-${randomUUID()}`, dogId: dog.id },
  });
  return { user, dog, collar };
}

after(async () => {
  await prisma.$disconnect();
});

test('GET /dogs/:dogId/activity/summary returns a zeroed summary, not a 404, for a freshly-created dog with no collar paired', async () => {
  const { owner, dog } = await createOwnerWithoutCollar('ActivitySummaryNoCollarDog');

  const reply = fakeReply();
  await getActivitySummary(fakeRequest(owner.id, { dogId: dog.id }), reply as unknown as FastifyReply);

  assert.equal(reply.statusCode, 200);
  assert.deepEqual(reply.payload, {
    date: (reply.payload as { date: string }).date,
    totalSteps: 0,
    activeMinutes: 0,
    restMinutes: 0,
    anomalyCount: 0,
    recordCount: 0,
  });

  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('GET /dogs/:dogId/activity/sleep returns an empty breakdown, not a 404, for a freshly-created dog with no collar paired', async () => {
  const { owner, dog } = await createOwnerWithoutCollar('ActivitySleepNoCollarDog');

  const reply = fakeReply();
  await getSleepSummary(fakeRequest(owner.id, { dogId: dog.id }), reply as unknown as FastifyReply);

  assert.equal(reply.statusCode, 200);
  assert.deepEqual(reply.payload, { days: 1, totalRecords: 0, phases: [] });

  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('syncActivity triggers a push notification when an anomaly is detected', async (t) => {
  const { owner, dog } = await createOwnerWithCollar('ActivityPushDog');

  const calls: Array<{ dogId: string }> = [];
  t.mock.method(pushNotifications, 'notifyDogAccessHolders', async (dogId: string) => {
    calls.push({ dogId });
  });

  const reply = fakeReply();
  await syncActivity(
    fakeRequest(owner.id, { dogId: dog.id }, {}, {
      records: [{ anomalyDetected: true, anomalyType: 'fall', recordedAt: new Date().toISOString() }],
    }),
    reply as unknown as FastifyReply,
  );

  assert.equal((reply.payload as { synced: number }).synced, 1);
  assert.equal(calls.length, 1, 'an activity anomaly must trigger exactly one push notification');
  assert.equal(calls[0].dogId, dog.id);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('syncActivity does not trigger a push notification without an anomaly', async (t) => {
  const { owner, dog } = await createOwnerWithCollar('ActivityNoPushDog');

  const calls: Array<unknown> = [];
  t.mock.method(pushNotifications, 'notifyDogAccessHolders', async () => {
    calls.push(undefined);
  });

  const reply = fakeReply();
  await syncActivity(
    fakeRequest(owner.id, { dogId: dog.id }, {}, {
      records: [{ steps: 500, recordedAt: new Date().toISOString() }],
    }),
    reply as unknown as FastifyReply,
  );

  assert.equal((reply.payload as { synced: number }).synced, 1);
  assert.equal(calls.length, 0);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('GET /dogs/:dogId/sleep aggregates sleep phase records within the requested window', async () => {
  const { owner, dog, collar } = await createOwnerWithCollar('SleepAggDog');
  const now = Date.now();
  const minutesAgo = (m: number) => new Date(now - m * 60_000);

  await prisma.activityRecord.createMany({
    data: [
      { collarId: collar.id, sleepPhase: 'awake', recordedAt: minutesAgo(10) },
      { collarId: collar.id, sleepPhase: 'light', recordedAt: minutesAgo(20) },
      { collarId: collar.id, sleepPhase: 'light', recordedAt: minutesAgo(30) },
      { collarId: collar.id, sleepPhase: 'deep', recordedAt: minutesAgo(40) },
      // Outside the default 1-day window — must not be counted
      { collarId: collar.id, sleepPhase: 'deep', recordedAt: minutesAgo(2 * 24 * 60) },
    ],
  });

  const reply = fakeReply();
  await getSleepSummary(
    fakeRequest(owner.id, { dogId: dog.id }, {}),
    reply as unknown as FastifyReply,
  );

  const payload = reply.payload as {
    days: number;
    totalRecords: number;
    phases: Array<{ phase: string; count: number; percentage: number }>;
  };
  assert.equal(payload.days, 1);
  assert.equal(payload.totalRecords, 4);
  const byPhase = Object.fromEntries(payload.phases.map((p) => [p.phase, p.count]));
  assert.equal(byPhase.awake, 1);
  assert.equal(byPhase.light, 2);
  assert.equal(byPhase.deep, 1);
  const lightEntry = payload.phases.find((p) => p.phase === 'light');
  assert.equal(lightEntry?.percentage, 50);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('GET /dogs/:dogId/activity refuses a dog_sitter whose access has expired', async () => {
  const { user, dog } = await createDogWithAccess('dog_sitter', new Date(Date.now() - 60 * 60 * 1000));

  await assert.rejects(
    () => getActivitySummary(fakeRequest(user.id, { dogId: dog.id }), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: user.id } });
});

test('GET /dogs/:dogId/activity allows a dog_sitter whose access is still within its window', async () => {
  const { user, dog } = await createDogWithAccess('dog_sitter', new Date(Date.now() + 60 * 60 * 1000));

  const reply = fakeReply();
  await getActivitySummary(fakeRequest(user.id, { dogId: dog.id }), reply as unknown as FastifyReply);
  assert.equal(reply.statusCode, 200);

  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: user.id } });
});

test('GET /dogs/:dogId/sleep returns an empty breakdown when there is no data yet', async () => {
  const { owner, dog } = await createOwnerWithCollar('SleepEmptyDog');

  const reply = fakeReply();
  await getSleepSummary(
    fakeRequest(owner.id, { dogId: dog.id }, {}),
    reply as unknown as FastifyReply,
  );

  const payload = reply.payload as { totalRecords: number; phases: unknown[] };
  assert.equal(payload.totalRecords, 0);
  assert.equal(payload.phases.length, 0);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});
