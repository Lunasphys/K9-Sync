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

test('POST/GET /users/me/consents records consents and returns the latest state per type', async () => {
  const hash = await bcrypt.hash('irrelevant', 4);
  const user = await prisma.user.create({
    data: {
      email: `consent-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Consent',
      lastName: 'Tester',
    },
  });

  const postReply = fakeReply();
  await controller.postConsents(
    fakeRequest(user.id, {
      consents: [
        { type: 'terms_of_service', accepted: true, version: '1.0' },
        { type: 'gps_data_collection', accepted: true, version: '1.0' },
        { type: 'health_data_collection', accepted: false, version: '1.0' },
      ],
    }),
    postReply as unknown as FastifyReply,
  );
  assert.equal(postReply.statusCode, 201);
  assert.equal((postReply.payload as { recorded: number }).recorded, 3);

  const getReply1 = fakeReply();
  await controller.getConsents(fakeRequest(user.id), getReply1 as unknown as FastifyReply);
  const state1 = (
    getReply1.payload as { consents: Record<string, { accepted: boolean; version: string }> }
  ).consents;
  assert.equal(state1.terms_of_service.accepted, true);
  assert.equal(state1.gps_data_collection.accepted, true);
  assert.equal(state1.health_data_collection.accepted, false);

  // The user later revokes GPS consent — this appends a new row, it never
  // rewrites the previous one (append-only audit trail).
  const postReply2 = fakeReply();
  await controller.postConsents(
    fakeRequest(user.id, {
      consents: [{ type: 'gps_data_collection', accepted: false, version: '1.0' }],
    }),
    postReply2 as unknown as FastifyReply,
  );
  assert.equal(postReply2.statusCode, 201);

  const getReply2 = fakeReply();
  await controller.getConsents(fakeRequest(user.id), getReply2 as unknown as FastifyReply);
  const state2 = (
    getReply2.payload as { consents: Record<string, { accepted: boolean; version: string }> }
  ).consents;
  assert.equal(state2.gps_data_collection.accepted, false, 'latest state must reflect the revocation');
  assert.equal(state2.terms_of_service.accepted, true, 'unrelated consent types must be unaffected');

  // The full history is preserved — two rows for gps_data_collection, not an update
  const gpsHistory = await prisma.consentLog.findMany({
    where: { userId: user.id, type: 'gps_data_collection' },
  });
  assert.equal(gpsHistory.length, 2);

  // cleanup
  await prisma.consentLog.deleteMany({ where: { userId: user.id } });
  await prisma.user.delete({ where: { id: user.id } });
});

test('deleting an account detaches (never deletes) their consent logs', async () => {
  const hash = await bcrypt.hash('irrelevant', 4);
  const user = await prisma.user.create({
    data: {
      email: `consent-delete-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Detach',
      lastName: 'Test',
    },
  });
  const consent = await prisma.consentLog.create({
    data: { userId: user.id, type: 'terms_of_service', accepted: true, version: '1.0' },
  });

  const reply = fakeReply();
  await controller.deleteMe(
    fakeRequest(user.id, { password: 'irrelevant' }),
    reply as unknown as FastifyReply,
  );
  assert.equal(reply.statusCode, 204);

  const stillThere = await prisma.consentLog.findUnique({ where: { id: consent.id } });
  assert.ok(stillThere, 'the consent log row must survive account deletion');
  assert.equal(stillThere?.userId, null, 'its user link must be detached, not the row deleted');
  assert.equal(stillThere?.accepted, true);

  // cleanup
  await prisma.consentLog.delete({ where: { id: consent.id } });
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
  await prisma.geofenceZone.create({
    data: { dogId: dog.id, latitude: 45.1, longitude: 4.1, radiusM: 50 },
  });
  await prisma.vetRecord.create({
    data: { dogId: dog.id, title: 'Export vet check', date: new Date() },
  });
  await prisma.trail.create({
    data: {
      collarId: collar.id,
      startedAt: new Date(),
      endedAt: new Date(),
      distanceM: 100,
      durationS: 60,
      pointsCount: 2,
    },
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
  await prisma.geofenceZone.create({
    data: { dogId: otherDog.id, latitude: 1, longitude: 1, radiusM: 50 },
  });
  await prisma.vetRecord.create({
    data: { dogId: otherDog.id, title: 'Other vet check', date: new Date() },
  });
  await prisma.trail.create({
    data: {
      collarId: otherCollar.id,
      startedAt: new Date(),
      endedAt: new Date(),
      distanceM: 50,
      durationS: 30,
      pointsCount: 1,
    },
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
      geofenceZone: { radiusM: number } | null;
      vetRecords: Array<{ title: string }>;
      trails: Array<{ distanceM: number }>;
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

  // ... and its geofencing zone, vet record book, and trail history
  assert.ok(payload.dogs[0].geofenceZone);
  assert.equal(payload.dogs[0].geofenceZone?.radiusM, 50);
  assert.equal(payload.dogs[0].vetRecords.length, 1);
  assert.equal(payload.dogs[0].vetRecords[0].title, 'Export vet check');
  assert.equal(payload.dogs[0].trails.length, 1);
  assert.equal(payload.dogs[0].trails[0].distanceM, 100);

  // Never contains the other user's dog or its telemetry
  const dogIds = payload.dogs.map((d) => d.id);
  assert.ok(!dogIds.includes(otherDog.id));

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: user.id } });
  await prisma.dog.delete({ where: { id: otherDog.id } });
  await prisma.user.delete({ where: { id: otherUser.id } });
});

test('POST /users/me/push-token stores the token on the authenticated user', async () => {
  const hash = await bcrypt.hash('irrelevant', 4);
  const user = await prisma.user.create({
    data: {
      email: `push-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Push',
      lastName: 'Tester',
    },
  });

  const reply = fakeReply();
  await controller.registerPushToken(
    fakeRequest(user.id, { token: 'fcm-token-abc123' }),
    reply as unknown as FastifyReply,
  );
  assert.equal(reply.statusCode, 204);

  const stored = await prisma.user.findUnique({ where: { id: user.id } });
  assert.equal(stored?.pushToken, 'fcm-token-abc123');

  // Re-registering (e.g. token rotation, new device login) overwrites it —
  // one token per account, the latest device wins.
  const secondReply = fakeReply();
  await controller.registerPushToken(
    fakeRequest(user.id, { token: 'fcm-token-xyz789' }),
    secondReply as unknown as FastifyReply,
  );
  const updated = await prisma.user.findUnique({ where: { id: user.id } });
  assert.equal(updated?.pushToken, 'fcm-token-xyz789');

  // cleanup
  await prisma.user.delete({ where: { id: user.id } });
});
