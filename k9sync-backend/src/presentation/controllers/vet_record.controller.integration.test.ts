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
import {
  createVetRecord,
  getVetRecords,
  updateVetRecord,
  deleteVetRecord,
} from './vet_record.controller.js';

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
      email: `vet-${role}-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Test',
      lastName: role,
    },
  });
  const dog = await prisma.dog.create({ data: { name: `VetDog-${randomUUID()}` } });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: user.id, role, expiresAt } });
  return { user, dog };
}

async function createUserWithoutAccess() {
  const hash = await bcrypt.hash('irrelevant', 4);
  return prisma.user.create({
    data: {
      email: `vet-outsider-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Outsider',
      lastName: 'User',
    },
  });
}

async function cleanup(dogId: string, userId: string) {
  await prisma.dog.delete({ where: { id: dogId } });
  await prisma.user.delete({ where: { id: userId } });
}

after(async () => {
  await prisma.$disconnect();
});

const sampleBody = (overrides: Record<string, unknown> = {}) => ({
  title: 'Vaccin annuel',
  date: new Date('2026-10-01T09:00:00.000Z').toISOString(),
  ...overrides,
});

test('POST /dogs/:dogId/vet-records creates an entry (owner)', async () => {
  const { user, dog } = await createDogWithAccess('owner');
  const reply = fakeReply();

  await createVetRecord(fakeRequest(user.id, { dogId: dog.id }, sampleBody({ notes: 'Rappel annuel' })), reply as unknown as FastifyReply);

  assert.equal(reply.statusCode, 201);
  const payload = reply.payload as { id: string; title: string; done: boolean; notes: string | null };
  assert.ok(payload.id);
  assert.equal(payload.title, 'Vaccin annuel');
  assert.equal(payload.done, false, 'defaults to not done');
  assert.equal(payload.notes, 'Rappel annuel');

  const stored = await prisma.vetRecord.findUnique({ where: { id: payload.id } });
  assert.ok(stored);

  await cleanup(dog.id, user.id);
});

test('POST /dogs/:dogId/vet-records refuses an invalid body (missing title)', async () => {
  const { user, dog } = await createDogWithAccess('owner');

  await assert.rejects(
    () => createVetRecord(fakeRequest(user.id, { dogId: dog.id }, { date: sampleBody().date }), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 400);
      return true;
    },
  );

  await cleanup(dog.id, user.id);
});

test('GET /dogs/:dogId/vet-records lists entries sorted by date, earliest first', async () => {
  const { user, dog } = await createDogWithAccess('owner');

  const later = fakeReply();
  await createVetRecord(
    fakeRequest(user.id, { dogId: dog.id }, sampleBody({ title: 'Contrôle dentaire', date: '2026-12-01T09:00:00.000Z' })),
    later as unknown as FastifyReply,
  );
  const earlier = fakeReply();
  await createVetRecord(
    fakeRequest(user.id, { dogId: dog.id }, sampleBody({ title: 'Vaccin rage', date: '2026-09-15T09:00:00.000Z' })),
    earlier as unknown as FastifyReply,
  );

  const listReply = fakeReply();
  await getVetRecords(fakeRequest(user.id, { dogId: dog.id }), listReply as unknown as FastifyReply);

  const list = listReply.payload as Array<{ id: string; title: string }>;
  assert.equal(list.length, 2);
  assert.equal(list[0].id, (earlier.payload as { id: string }).id, 'earliest date must come first');
  assert.equal(list[1].id, (later.payload as { id: string }).id);

  await cleanup(dog.id, user.id);
});

test('PATCH /dogs/:dogId/vet-records/:recordId marks an entry as done', async () => {
  const { user, dog } = await createDogWithAccess('family');

  const createReply = fakeReply();
  await createVetRecord(fakeRequest(user.id, { dogId: dog.id }, sampleBody()), createReply as unknown as FastifyReply);
  const recordId = (createReply.payload as { id: string }).id;

  const updateReply = fakeReply();
  await updateVetRecord(
    fakeRequest(user.id, { dogId: dog.id, recordId }, { done: true }),
    updateReply as unknown as FastifyReply,
  );

  assert.equal(updateReply.statusCode, 200);
  assert.equal((updateReply.payload as { done: boolean }).done, true);

  const stored = await prisma.vetRecord.findUnique({ where: { id: recordId } });
  assert.equal(stored?.done, true);

  await cleanup(dog.id, user.id);
});

test('PATCH /dogs/:dogId/vet-records/:recordId returns 404 for a record that does not belong to this dog', async () => {
  const dogA = await createDogWithAccess('owner');
  const dogB = await createDogWithAccess('owner');

  const createReply = fakeReply();
  await createVetRecord(fakeRequest(dogA.user.id, { dogId: dogA.dog.id }, sampleBody()), createReply as unknown as FastifyReply);
  const recordId = (createReply.payload as { id: string }).id;

  const updateReply = fakeReply();
  await updateVetRecord(
    fakeRequest(dogB.user.id, { dogId: dogB.dog.id, recordId }, { done: true }),
    updateReply as unknown as FastifyReply,
  );
  assert.equal(updateReply.statusCode, 404);

  await cleanup(dogA.dog.id, dogA.user.id);
  await cleanup(dogB.dog.id, dogB.user.id);
});

test('DELETE /dogs/:dogId/vet-records/:recordId removes the entry', async () => {
  const { user, dog } = await createDogWithAccess('owner');

  const createReply = fakeReply();
  await createVetRecord(fakeRequest(user.id, { dogId: dog.id }, sampleBody()), createReply as unknown as FastifyReply);
  const recordId = (createReply.payload as { id: string }).id;

  const deleteReply = fakeReply();
  await deleteVetRecord(fakeRequest(user.id, { dogId: dog.id, recordId }), deleteReply as unknown as FastifyReply);
  assert.equal(deleteReply.statusCode, 204);

  const stored = await prisma.vetRecord.findUnique({ where: { id: recordId } });
  assert.equal(stored, null);

  await cleanup(dog.id, user.id);
});

test('a user without access to the dog is refused on create, list, update and delete', async () => {
  const { user: owner, dog } = await createDogWithAccess('owner');
  const outsider = await createUserWithoutAccess();

  const record = await prisma.vetRecord.create({
    data: { dogId: dog.id, title: 'Vaccin annuel', date: new Date('2026-10-01T09:00:00.000Z') },
  });

  await assert.rejects(
    () => createVetRecord(fakeRequest(outsider.id, { dogId: dog.id }, sampleBody()), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await assert.rejects(
    () => getVetRecords(fakeRequest(outsider.id, { dogId: dog.id }), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await assert.rejects(
    () =>
      updateVetRecord(
        fakeRequest(outsider.id, { dogId: dog.id, recordId: record.id }, { done: true }),
        fakeReply() as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await assert.rejects(
    () => deleteVetRecord(fakeRequest(outsider.id, { dogId: dog.id, recordId: record.id }), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.deleteMany({ where: { id: { in: [owner.id, outsider.id] } } });
});

// ── dog_sitter: read-only ────────────────────────────────────────────────────

test('a dog_sitter within their access window can read vet records', async () => {
  const { user, dog } = await createDogWithAccess('dog_sitter', new Date(Date.now() + 60 * 60 * 1000));
  await prisma.vetRecord.create({
    data: { dogId: dog.id, title: 'Vaccin annuel', date: new Date('2026-10-01T09:00:00.000Z') },
  });

  const reply = fakeReply();
  await getVetRecords(fakeRequest(user.id, { dogId: dog.id }), reply as unknown as FastifyReply);
  assert.equal(reply.statusCode, 200);
  assert.equal((reply.payload as unknown[]).length, 1);

  await cleanup(dog.id, user.id);
});

test('a dog_sitter within their access window is refused on create, update and delete', async () => {
  const { user, dog } = await createDogWithAccess('dog_sitter', new Date(Date.now() + 60 * 60 * 1000));
  const record = await prisma.vetRecord.create({
    data: { dogId: dog.id, title: 'Vaccin annuel', date: new Date('2026-10-01T09:00:00.000Z') },
  });

  await assert.rejects(
    () => createVetRecord(fakeRequest(user.id, { dogId: dog.id }, sampleBody()), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await assert.rejects(
    () =>
      updateVetRecord(
        fakeRequest(user.id, { dogId: dog.id, recordId: record.id }, { done: true }),
        fakeReply() as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await assert.rejects(
    () => deleteVetRecord(fakeRequest(user.id, { dogId: dog.id, recordId: record.id }), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  // Never touched — the record must survive all three refused attempts.
  const stillThere = await prisma.vetRecord.findUnique({ where: { id: record.id } });
  assert.ok(stillThere);
  assert.equal(stillThere.done, false);

  await cleanup(dog.id, user.id);
});

test('a dog_sitter whose access has expired cannot even read vet records', async () => {
  const { user, dog } = await createDogWithAccess('dog_sitter', new Date(Date.now() - 60 * 60 * 1000));

  await assert.rejects(
    () => getVetRecords(fakeRequest(user.id, { dogId: dog.id }), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  await cleanup(dog.id, user.id);
});
