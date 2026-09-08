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
import { getGpsLatest } from './gps.controller.js';

initPrisma(process.env.DATABASE_URL ?? '');
const prisma = getPrisma();

function fakeRequest(userId: string, params: Record<string, string>): FastifyRequest {
  return { userId, params } as unknown as FastifyRequest;
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
      email: `gps-${role}-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Test',
      lastName: role,
    },
  });
  const dog = await prisma.dog.create({ data: { name: `GpsDog-${randomUUID()}` } });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: user.id, role, expiresAt } });
  const collar = await prisma.collar.create({
    data: { serialNumber: `GPS-${randomUUID()}`, dogId: dog.id },
  });
  await prisma.gpsLocation.create({
    data: {
      collarId: collar.id,
      latitude: 45.7578,
      longitude: 4.832,
      recordedAt: new Date(),
    },
  });
  return { user, dog, collar };
}

async function cleanup(dogId: string, userId: string) {
  await prisma.dog.delete({ where: { id: dogId } });
  await prisma.user.delete({ where: { id: userId } });
}

after(async () => {
  await prisma.$disconnect();
});

test('GET /dogs/:dogId/gps/latest refuses a dog_sitter whose access has expired', async () => {
  const { user, dog } = await createDogWithAccess('dog_sitter', new Date(Date.now() - 60 * 60 * 1000));

  await assert.rejects(
    () => getGpsLatest(fakeRequest(user.id, { dogId: dog.id }), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await cleanup(dog.id, user.id);
});

test('GET /dogs/:dogId/gps/latest allows a family member (never expires)', async () => {
  const { user, dog } = await createDogWithAccess('family');

  const reply = fakeReply();
  await getGpsLatest(fakeRequest(user.id, { dogId: dog.id }), reply as unknown as FastifyReply);
  assert.equal(reply.statusCode, 200);

  await cleanup(dog.id, user.id);
});

test('GET /dogs/:dogId/gps/latest allows a dog_sitter whose access is still within its window', async () => {
  const { user, dog } = await createDogWithAccess('dog_sitter', new Date(Date.now() + 60 * 60 * 1000));

  const reply = fakeReply();
  await getGpsLatest(fakeRequest(user.id, { dogId: dog.id }), reply as unknown as FastifyReply);
  assert.equal(reply.statusCode, 200);

  await cleanup(dog.id, user.id);
});
