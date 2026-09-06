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
import { UserController } from './user.controller.js';

initPrisma(process.env.DATABASE_URL ?? '');
const prisma = getPrisma();
const controller = new UserController();

function fakeRequest(userId: string, body?: unknown): FastifyRequest {
  return { userId, body } as unknown as FastifyRequest;
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

after(async () => {
  await prisma.$disconnect();
});

test('DELETE /users/me removes the user and cascades to their owned dog and all its telemetry', async () => {
  const passwordHash = await bcrypt.hash('irrelevant', 4);
  const user = await prisma.user.create({
    data: {
      email: `delete-me-${randomUUID()}@test.local`,
      passwordHash,
      firstName: 'Test',
      lastName: 'Delete',
    },
  });

  await prisma.refreshToken.create({
    data: {
      userId: user.id,
      token: await bcrypt.hash('refresh', 4),
      expiresAt: new Date(Date.now() + 86400000),
    },
  });

  const dog = await prisma.dog.create({ data: { name: 'CascadeTestDog' } });
  await prisma.dogUser.create({
    data: { dogId: dog.id, userId: user.id, role: 'owner' },
  });
  const collar = await prisma.collar.create({
    data: { serialNumber: `TEST-${randomUUID()}`, dogId: dog.id },
  });
  await prisma.gpsLocation.create({
    data: { collarId: collar.id, latitude: 45.0, longitude: 4.0, recordedAt: new Date() },
  });
  await prisma.healthRecord.create({
    data: { collarId: collar.id, heartRate: 90, recordedAt: new Date() },
  });
  await prisma.activityRecord.create({
    data: { collarId: collar.id, steps: 100, recordedAt: new Date() },
  });
  await prisma.alert.create({
    data: { dogId: dog.id, type: 'test', title: 'Test alert' },
  });

  // Sanity check — everything exists before deletion
  assert.equal(await prisma.user.count({ where: { id: user.id } }), 1);
  assert.equal(await prisma.dog.count({ where: { id: dog.id } }), 1);
  assert.equal(await prisma.collar.count({ where: { id: collar.id } }), 1);
  assert.equal(await prisma.gpsLocation.count({ where: { collarId: collar.id } }), 1);
  assert.equal(await prisma.healthRecord.count({ where: { collarId: collar.id } }), 1);
  assert.equal(await prisma.activityRecord.count({ where: { collarId: collar.id } }), 1);
  assert.equal(await prisma.alert.count({ where: { dogId: dog.id } }), 1);
  assert.equal(await prisma.refreshToken.count({ where: { userId: user.id } }), 1);
  assert.equal(await prisma.dogUser.count({ where: { userId: user.id } }), 1);

  const reply = fakeReply();
  await controller.deleteMe(
    fakeRequest(user.id, { password: 'irrelevant' }),
    reply as unknown as FastifyReply,
  );

  assert.equal(reply.statusCode, 204);

  // Everything must be gone
  assert.equal(await prisma.user.count({ where: { id: user.id } }), 0);
  assert.equal(await prisma.dog.count({ where: { id: dog.id } }), 0);
  assert.equal(await prisma.collar.count({ where: { id: collar.id } }), 0);
  assert.equal(await prisma.gpsLocation.count({ where: { collarId: collar.id } }), 0);
  assert.equal(await prisma.healthRecord.count({ where: { collarId: collar.id } }), 0);
  assert.equal(await prisma.activityRecord.count({ where: { collarId: collar.id } }), 0);
  assert.equal(await prisma.alert.count({ where: { dogId: dog.id } }), 0);
  assert.equal(await prisma.refreshToken.count({ where: { userId: user.id } }), 0);
  assert.equal(await prisma.dogUser.count({ where: { userId: user.id } }), 0);
});

test('deleting an account does not delete a dog shared with another user', async () => {
  const hash = await bcrypt.hash('irrelevant', 4);
  const owner = await prisma.user.create({
    data: {
      email: `owner-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Owner',
      lastName: 'User',
    },
  });
  const familyMember = await prisma.user.create({
    data: {
      email: `family-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Family',
      lastName: 'User',
    },
  });
  const dog = await prisma.dog.create({ data: { name: 'SharedDog' } });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: owner.id, role: 'owner' } });
  await prisma.dogUser.create({
    data: { dogId: dog.id, userId: familyMember.id, role: 'family' },
  });

  // The family member (non-owner) deletes their own account
  const reply = fakeReply();
  await controller.deleteMe(
    fakeRequest(familyMember.id, { password: 'irrelevant' }),
    reply as unknown as FastifyReply,
  );

  // The family member's account is gone, but the dog and the owner's access remain
  assert.equal(await prisma.user.count({ where: { id: familyMember.id } }), 0);
  assert.equal(await prisma.dog.count({ where: { id: dog.id } }), 1);
  assert.equal(
    await prisma.dogUser.count({ where: { dogId: dog.id, userId: owner.id } }),
    1,
  );

  // cleanup — the owner's account was never deleted by this test
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('DELETE /users/me refuses deletion with an incorrect password and deletes nothing', async () => {
  const passwordHash = await bcrypt.hash('correct-password', 4);
  const user = await prisma.user.create({
    data: {
      email: `wrongpw-${randomUUID()}@test.local`,
      passwordHash,
      firstName: 'Wrong',
      lastName: 'Password',
    },
  });
  const dog = await prisma.dog.create({ data: { name: 'StillHereDog' } });
  await prisma.dogUser.create({
    data: { dogId: dog.id, userId: user.id, role: 'owner' },
  });

  const reply = fakeReply();
  await assert.rejects(
    () =>
      controller.deleteMe(
        fakeRequest(user.id, { password: 'wrong-password' }),
        reply as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 401);
      return true;
    },
  );

  // Nothing was deleted — account and dog both still exist
  assert.equal(await prisma.user.count({ where: { id: user.id } }), 1);
  assert.equal(await prisma.dog.count({ where: { id: dog.id } }), 1);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: user.id } });
});

test('GET /users/me/export returns only the authenticated user\'s own data', async () => {
  const hash = await bcrypt.hash('irrelevant', 4);

  const user = await prisma.user.create({
    data: {
      email: `export-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Export',
      lastName: 'Tester',
    },
  });
  const otherUser = await prisma.user.create({
    data: {
      email: `other-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Other',
      lastName: 'User',
    },
  });

  // This user's own dog, with a collar and telemetry
  const dog = await prisma.dog.create({ data: { name: 'ExportDog', breed: 'Labrador' } });
  await prisma.dogUser.create({
    data: { dogId: dog.id, userId: user.id, role: 'owner' },
  });
  const collar = await prisma.collar.create({
    data: { serialNumber: `EXPORT-${randomUUID()}`, dogId: dog.id },
  });
  await prisma.gpsLocation.create({
    data: { collarId: collar.id, latitude: 45.1, longitude: 4.1, recordedAt: new Date() },
  });
  await prisma.healthRecord.create({
    data: { collarId: collar.id, heartRate: 95, recordedAt: new Date() },
  });
  await prisma.activityRecord.create({
    data: { collarId: collar.id, steps: 500, recordedAt: new Date() },
  });
  await prisma.alert.create({
    data: { dogId: dog.id, type: 'health', title: 'Export test alert' },
  });

  // Another user's dog — must never leak into this user's export
  const otherDog = await prisma.dog.create({ data: { name: 'OtherDog' } });
  await prisma.dogUser.create({
    data: { dogId: otherDog.id, userId: otherUser.id, role: 'owner' },
  });
  const otherCollar = await prisma.collar.create({
    data: { serialNumber: `OTHER-${randomUUID()}`, dogId: otherDog.id },
  });
  await prisma.gpsLocation.create({
    data: { collarId: otherCollar.id, latitude: 1, longitude: 1, recordedAt: new Date() },
  });

  const reply = fakeReply();
  await controller.exportMyData(fakeRequest(user.id), reply as unknown as FastifyReply);

  assert.equal(reply.statusCode, 200);
  const payload = reply.payload as {
    user: { id: string; email: string; passwordHash?: string };
    dogs: Array<{
      id: string;
      gpsLocations: unknown[];
      healthRecords: unknown[];
      activityRecords: unknown[];
      alerts: unknown[];
    }>;
  };

  // Contains this user's own profile — and never the password hash
  assert.equal(payload.user.id, user.id);
  assert.equal(payload.user.email, user.email);
  assert.equal(payload.user.passwordHash, undefined);

  // Contains exactly this user's owned dog, with its full telemetry
  assert.equal(payload.dogs.length, 1);
  assert.equal(payload.dogs[0].id, dog.id);
  assert.equal(payload.dogs[0].gpsLocations.length, 1);
  assert.equal(payload.dogs[0].healthRecords.length, 1);
  assert.equal(payload.dogs[0].activityRecords.length, 1);
  assert.equal(payload.dogs[0].alerts.length, 1);

  // Never contains the other user's dog or its telemetry
  const dogIds = payload.dogs.map((d) => d.id);
  assert.ok(!dogIds.includes(otherDog.id));

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: user.id } });
  await prisma.dog.delete({ where: { id: otherDog.id } });
  await prisma.user.delete({ where: { id: otherUser.id } });
});
