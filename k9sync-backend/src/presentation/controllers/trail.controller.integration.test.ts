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
import { createTrail, getTrails, getTrailById } from './trail.controller.js';
import { syncGps } from './gps.controller.js';

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

async function createDogWithAccess(role: 'owner' | 'family' | 'dog_sitter', expiresAt?: Date) {
  const hash = await bcrypt.hash('irrelevant', 4);
  const user = await prisma.user.create({
    data: {
      email: `trail-${role}-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Test',
      lastName: role,
    },
  });
  const dog = await prisma.dog.create({ data: { name: `TrailDog-${randomUUID()}` } });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: user.id, role, expiresAt } });
  const collar = await prisma.collar.create({
    data: { serialNumber: `TRAIL-${randomUUID()}`, dogId: dog.id },
  });
  return { user, dog, collar };
}

async function createUserWithoutAccess() {
  const hash = await bcrypt.hash('irrelevant', 4);
  return prisma.user.create({
    data: {
      email: `trail-outsider-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Outsider',
      lastName: 'User',
    },
  });
}

async function cleanup(dogId: string, userId: string) {
  // Trail/GpsLocation cascade from Collar, Collar cascades from Dog.
  await prisma.dog.delete({ where: { id: dogId } });
  await prisma.user.delete({ where: { id: userId } });
}

after(async () => {
  await prisma.$disconnect();
});

const sampleTrailBody = () => ({
  startedAt: new Date('2026-09-01T10:00:00.000Z').toISOString(),
  endedAt: new Date('2026-09-01T10:30:00.000Z').toISOString(),
  distanceM: 1500,
  durationS: 1800,
  pointsCount: 42,
});

test('POST /dogs/:dogId/trails creates a trail summary and returns it with an id', async () => {
  const { user, dog } = await createDogWithAccess('owner');
  const reply = fakeReply();

  await createTrail(
    fakeRequest(user.id, { dogId: dog.id }, sampleTrailBody()),
    reply as unknown as FastifyReply,
  );

  assert.equal(reply.statusCode, 201);
  const payload = reply.payload as { id: string; distanceM: number; pointsCount: number };
  assert.ok(payload.id);
  assert.equal(payload.distanceM, 1500);
  assert.equal(payload.pointsCount, 42);

  const stored = await prisma.trail.findUnique({ where: { id: payload.id } });
  assert.ok(stored);

  await cleanup(dog.id, user.id);
});

test('GET /dogs/:dogId/trails lists trail summaries, most recent first', async () => {
  const { user, dog } = await createDogWithAccess('owner');

  const older = fakeReply();
  await createTrail(
    fakeRequest(user.id, { dogId: dog.id }, {
      ...sampleTrailBody(),
      startedAt: new Date('2026-09-01T08:00:00.000Z').toISOString(),
      endedAt: new Date('2026-09-01T08:20:00.000Z').toISOString(),
    }),
    older as unknown as FastifyReply,
  );
  const newer = fakeReply();
  await createTrail(
    fakeRequest(user.id, { dogId: dog.id }, {
      ...sampleTrailBody(),
      startedAt: new Date('2026-09-02T08:00:00.000Z').toISOString(),
      endedAt: new Date('2026-09-02T08:20:00.000Z').toISOString(),
    }),
    newer as unknown as FastifyReply,
  );

  const listReply = fakeReply();
  await getTrails(fakeRequest(user.id, { dogId: dog.id }), listReply as unknown as FastifyReply);

  const list = listReply.payload as Array<{ id: string; startedAt: string }>;
  assert.equal(list.length, 2);
  assert.equal(list[0].id, (newer.payload as { id: string }).id, 'most recent trail must come first');
  assert.equal(list[1].id, (older.payload as { id: string }).id);

  await cleanup(dog.id, user.id);
});

test('GET /dogs/:dogId/trails/:trailId returns the trail detail with its GPS points', async () => {
  const { user, dog, collar } = await createDogWithAccess('owner');

  const createReply = fakeReply();
  await createTrail(
    fakeRequest(user.id, { dogId: dog.id }, sampleTrailBody()),
    createReply as unknown as FastifyReply,
  );
  const trailId = (createReply.payload as { id: string }).id;

  const syncReply = fakeReply();
  await syncGps(
    fakeRequest(user.id, { dogId: dog.id }, {
      trailId,
      locations: [
        { latitude: 45.75, longitude: 4.83, recordedAt: new Date('2026-09-01T10:00:00.000Z').toISOString() },
        { latitude: 45.76, longitude: 4.84, recordedAt: new Date('2026-09-01T10:05:00.000Z').toISOString() },
      ],
    }),
    syncReply as unknown as FastifyReply,
  );
  assert.equal((syncReply.payload as { synced: number }).synced, 2);

  const detailReply = fakeReply();
  await getTrailById(
    fakeRequest(user.id, { dogId: dog.id, trailId }),
    detailReply as unknown as FastifyReply,
  );

  assert.equal(detailReply.statusCode, 200);
  const detail = detailReply.payload as { id: string; points: Array<{ latitude: number; trailId: string }> };
  assert.equal(detail.id, trailId);
  assert.equal(detail.points.length, 2);
  assert.equal(detail.points[0].trailId, trailId);

  // Cross-check via the collar directly, independent of the endpoint under test.
  const linkedCount = await prisma.gpsLocation.count({ where: { collarId: collar.id, trailId } });
  assert.equal(linkedCount, 2);

  await cleanup(dog.id, user.id);
});

test('GET /dogs/:dogId/trails/:trailId returns 404 for a trail that does not belong to this dog', async () => {
  const dogA = await createDogWithAccess('owner');
  const dogB = await createDogWithAccess('owner');

  const createReply = fakeReply();
  await createTrail(
    fakeRequest(dogA.user.id, { dogId: dogA.dog.id }, sampleTrailBody()),
    createReply as unknown as FastifyReply,
  );
  const trailId = (createReply.payload as { id: string }).id;

  const detailReply = fakeReply();
  await getTrailById(
    fakeRequest(dogB.user.id, { dogId: dogB.dog.id, trailId }),
    detailReply as unknown as FastifyReply,
  );
  assert.equal(detailReply.statusCode, 404);

  await cleanup(dogA.dog.id, dogA.user.id);
  await cleanup(dogB.dog.id, dogB.user.id);
});

test('family member can list and read trails (read access, not owner-only)', async () => {
  const { user, dog, collar } = await createDogWithAccess('family');

  const trail = await prisma.trail.create({
    data: {
      collarId: collar.id,
      startedAt: new Date('2026-09-01T10:00:00.000Z'),
      endedAt: new Date('2026-09-01T10:30:00.000Z'),
      distanceM: 1000,
      durationS: 1200,
      pointsCount: 10,
    },
  });

  const listReply = fakeReply();
  await getTrails(fakeRequest(user.id, { dogId: dog.id }), listReply as unknown as FastifyReply);
  assert.equal(listReply.statusCode, 200);
  assert.equal((listReply.payload as unknown[]).length, 1);

  const detailReply = fakeReply();
  await getTrailById(
    fakeRequest(user.id, { dogId: dog.id, trailId: trail.id }),
    detailReply as unknown as FastifyReply,
  );
  assert.equal(detailReply.statusCode, 200);

  await cleanup(dog.id, user.id);
});

test('a user without access to the dog is refused on create, list and detail', async () => {
  const { user: owner, dog, collar } = await createDogWithAccess('owner');
  const outsider = await createUserWithoutAccess();

  const trail = await prisma.trail.create({
    data: {
      collarId: collar.id,
      startedAt: new Date('2026-09-01T10:00:00.000Z'),
      endedAt: new Date('2026-09-01T10:30:00.000Z'),
      distanceM: 1000,
      durationS: 1200,
      pointsCount: 10,
    },
  });

  await assert.rejects(
    () => createTrail(fakeRequest(outsider.id, { dogId: dog.id }, sampleTrailBody()), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await assert.rejects(
    () => getTrails(fakeRequest(outsider.id, { dogId: dog.id }), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await assert.rejects(
    () =>
      getTrailById(
        fakeRequest(outsider.id, { dogId: dog.id, trailId: trail.id }),
        fakeReply() as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.deleteMany({ where: { id: { in: [owner.id, outsider.id] } } });
});

test('GET /dogs/:dogId/trails refuses a dog_sitter whose access has expired', async () => {
  const { user, dog } = await createDogWithAccess('dog_sitter', new Date(Date.now() - 60 * 60 * 1000));

  await assert.rejects(
    () => getTrails(fakeRequest(user.id, { dogId: dog.id }), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await cleanup(dog.id, user.id);
});

test('GET /dogs/:dogId/trails allows a dog_sitter whose access is still within its window', async () => {
  const { user, dog } = await createDogWithAccess('dog_sitter', new Date(Date.now() + 60 * 60 * 1000));

  const reply = fakeReply();
  await getTrails(fakeRequest(user.id, { dogId: dog.id }), reply as unknown as FastifyReply);
  assert.equal(reply.statusCode, 200);

  await cleanup(dog.id, user.id);
});
