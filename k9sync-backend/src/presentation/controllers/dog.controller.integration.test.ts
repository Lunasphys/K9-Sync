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
import { inviteToDog, listDogUsers, revokeDogUser, pairCollar, getDog } from './dog.controller.js';
import { AuthController } from './auth.controller.js';

initPrisma(process.env.DATABASE_URL ?? '');
const prisma = getPrisma();
const dogController = { inviteToDog, listDogUsers, revokeDogUser, pairCollar, getDog };
const authController = new AuthController();

function fakeRequest(
  userId: string,
  params: Record<string, string> = {},
  body?: unknown,
): FastifyRequest {
  return { userId, params, body } as unknown as FastifyRequest;
}

function fakeAuthRequest(body: unknown): FastifyRequest {
  return { body } as unknown as FastifyRequest;
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

async function createOwnerWithDog(dogName: string) {
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
  return { owner, dog };
}

after(async () => {
  await prisma.$disconnect();
});

test('POST /dogs/:dogId/invite grants access immediately when the email already has an account', async () => {
  const { owner, dog } = await createOwnerWithDog('ImmediateGrantDog');
  const hash = await bcrypt.hash('irrelevant', 4);
  const invitee = await prisma.user.create({
    data: {
      email: `invitee-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Julie',
      lastName: 'Martin',
    },
  });

  const reply = fakeReply();
  await dogController.inviteToDog(
    fakeRequest(owner.id, { dogId: dog.id }, { email: invitee.email, role: 'family' }),
    reply as unknown as FastifyReply,
  );

  assert.equal(reply.statusCode, 201);
  const payload = reply.payload as { status: string; dogUser: { userId: string; role: string } };
  assert.equal(payload.status, 'granted');
  assert.equal(payload.dogUser.userId, invitee.id);

  const dogUser = await prisma.dogUser.findFirst({ where: { dogId: dog.id, userId: invitee.id } });
  assert.ok(dogUser);
  assert.equal(dogUser?.role, 'family');
  assert.equal(dogUser?.expiresAt, null);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
  await prisma.user.delete({ where: { id: invitee.id } });
});

test('POST /dogs/:dogId/invite defers the grant when the email has no account, and resolves it at registration', async () => {
  const { owner, dog } = await createOwnerWithDog('DeferredGrantDog');
  const inviteeEmail = `future-sitter-${randomUUID()}@test.local`;
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

  const reply = fakeReply();
  await dogController.inviteToDog(
    fakeRequest(owner.id, { dogId: dog.id }, { email: inviteeEmail, role: 'dog_sitter', expiresAt }),
    reply as unknown as FastifyReply,
  );

  assert.equal(reply.statusCode, 202);
  assert.equal((reply.payload as { status: string }).status, 'pending');

  const pending = await prisma.pendingInvite.findFirst({ where: { dogId: dog.id, email: inviteeEmail } });
  assert.ok(pending, 'a PendingInvite row must exist');
  assert.equal(pending?.role, 'dog_sitter');

  // The invited person now registers with that exact email
  const registerReply = fakeReply();
  await authController.register(
    fakeAuthRequest({
      email: inviteeEmail,
      password: 'Test1234!',
      firstName: 'Future',
      lastName: 'Sitter',
    }),
    registerReply as unknown as FastifyReply,
  );
  assert.equal(registerReply.statusCode, 201);
  const newUserId = (registerReply.payload as { user: { id: string } }).user.id;

  // The invitation must now be resolved into a real, active DogUser grant
  const dogUser = await prisma.dogUser.findFirst({ where: { dogId: dog.id, userId: newUserId } });
  assert.ok(dogUser, 'the pending invite must have been resolved into a DogUser at registration');
  assert.equal(dogUser?.role, 'dog_sitter');
  assert.ok(dogUser?.expiresAt);

  // And the pending invite must be consumed (not left dangling)
  const stillPending = await prisma.pendingInvite.findFirst({ where: { dogId: dog.id, email: inviteeEmail } });
  assert.equal(stillPending, null);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
  await prisma.user.delete({ where: { id: newUserId } });
});

test('POST /dogs/:dogId/invite refuses when the caller is not the owner', async () => {
  const { owner, dog } = await createOwnerWithDog('NonOwnerInviteDog');
  const hash = await bcrypt.hash('irrelevant', 4);
  const familyMember = await prisma.user.create({
    data: {
      email: `family-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Family',
      lastName: 'Member',
    },
  });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: familyMember.id, role: 'family' } });

  const reply = fakeReply();
  await assert.rejects(
    () =>
      dogController.inviteToDog(
        fakeRequest(familyMember.id, { dogId: dog.id }, {
          email: `whoever-${randomUUID()}@test.local`,
          role: 'family',
        }),
        reply as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
  await prisma.user.delete({ where: { id: familyMember.id } });
});

test('GET /dogs/:dogId/users lists active accesses with role and expiry', async () => {
  const { owner, dog } = await createOwnerWithDog('ListUsersDog');
  const hash = await bcrypt.hash('irrelevant', 4);
  const familyMember = await prisma.user.create({
    data: {
      email: `family-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Marie',
      lastName: 'Dupont',
    },
  });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: familyMember.id, role: 'family' } });

  const expiredSitter = await prisma.user.create({
    data: {
      email: `expired-sitter-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Expired',
      lastName: 'Sitter',
    },
  });
  await prisma.dogUser.create({
    data: {
      dogId: dog.id,
      userId: expiredSitter.id,
      role: 'dog_sitter',
      expiresAt: new Date(Date.now() - 60 * 60 * 1000), // expired 1h ago
    },
  });

  const reply = fakeReply();
  await listDogUsers(fakeRequest(owner.id, { dogId: dog.id }), reply as unknown as FastifyReply);

  assert.equal(reply.statusCode, 200);
  const list = reply.payload as Array<{ userId: string; role: string; expiresAt: string | null }>;
  const userIds = list.map((u) => u.userId);

  assert.ok(userIds.includes(owner.id));
  assert.ok(userIds.includes(familyMember.id));
  assert.ok(!userIds.includes(expiredSitter.id), 'an expired dog_sitter grant must not be listed as active');

  const ownerEntry = list.find((u) => u.userId === owner.id);
  assert.equal(ownerEntry?.role, 'owner');
  assert.equal(ownerEntry?.expiresAt, null);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
  await prisma.user.delete({ where: { id: familyMember.id } });
  await prisma.user.delete({ where: { id: expiredSitter.id } });
});

test('DELETE /dogs/:dogId/users/:userId revokes a non-owner access', async () => {
  const { owner, dog } = await createOwnerWithDog('RevokeDog');
  const hash = await bcrypt.hash('irrelevant', 4);
  const familyMember = await prisma.user.create({
    data: {
      email: `family-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Thomas',
      lastName: 'Bernard',
    },
  });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: familyMember.id, role: 'family' } });

  const reply = fakeReply();
  await revokeDogUser(
    fakeRequest(owner.id, { dogId: dog.id, userId: familyMember.id }),
    reply as unknown as FastifyReply,
  );

  assert.equal(reply.statusCode, 204);
  const stillThere = await prisma.dogUser.findFirst({ where: { dogId: dog.id, userId: familyMember.id } });
  assert.equal(stillThere, null);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
  await prisma.user.delete({ where: { id: familyMember.id } });
});

test('DELETE /dogs/:dogId/users/:userId refuses to revoke the owner\'s own access', async () => {
  const { owner, dog } = await createOwnerWithDog('RevokeOwnerDog');

  const reply = fakeReply();
  await assert.rejects(
    () =>
      revokeDogUser(
        fakeRequest(owner.id, { dogId: dog.id, userId: owner.id }),
        reply as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  const ownerAccess = await prisma.dogUser.findFirst({ where: { dogId: dog.id, userId: owner.id } });
  assert.ok(ownerAccess, 'the owner access must still exist');

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('POST /dogs/:dogId/collar/pair provisions a brand-new serial number and pairs it', async () => {
  const { owner, dog } = await createOwnerWithDog('NewSerialDog');
  const serialNumber = `NEW-${randomUUID()}`;

  const reply = fakeReply();
  await pairCollar(
    fakeRequest(owner.id, { dogId: dog.id }, { serialNumber }),
    reply as unknown as FastifyReply,
  );

  assert.equal(reply.statusCode, 201);
  const collar = reply.payload as { serialNumber: string; dogId: string | null };
  assert.equal(collar.serialNumber, serialNumber);
  assert.equal(collar.dogId, dog.id);

  const inDb = await prisma.collar.findUnique({ where: { serialNumber } });
  assert.ok(inDb);
  assert.equal(inDb?.dogId, dog.id);

  // GET /dogs/:dogId must now expose the collar relation
  const getReply = fakeReply();
  await getDog(fakeRequest(owner.id, { dogId: dog.id }), getReply as unknown as FastifyReply);
  const dogPayload = getReply.payload as { collar: { serialNumber: string } | null };
  assert.equal(dogPayload.collar?.serialNumber, serialNumber);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('GET /dogs/:dogId exposes the geofenceZone relation — null when unset, populated once defined', async () => {
  const { owner, dog } = await createOwnerWithDog('GeofenceRelationDog');

  const noZoneReply = fakeReply();
  await getDog(fakeRequest(owner.id, { dogId: dog.id }), noZoneReply as unknown as FastifyReply);
  const noZonePayload = noZoneReply.payload as { geofenceZone: unknown };
  assert.equal(noZonePayload.geofenceZone, null);

  await prisma.geofenceZone.create({
    data: { dogId: dog.id, latitude: 45.7578, longitude: 4.832, radiusM: 50, isInside: true },
  });

  const withZoneReply = fakeReply();
  await getDog(fakeRequest(owner.id, { dogId: dog.id }), withZoneReply as unknown as FastifyReply);
  const withZonePayload = withZoneReply.payload as { geofenceZone: { radiusM: number } | null };
  assert.equal(withZonePayload.geofenceZone?.radiusM, 50);

  // cleanup
  await prisma.geofenceZone.deleteMany({ where: { dogId: dog.id } });
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('POST /dogs/:dogId/collar/pair claims an existing unclaimed collar', async () => {
  const { owner, dog } = await createOwnerWithDog('ClaimUnclaimedDog');
  const serialNumber = `UNCLAIMED-${randomUUID()}`;
  await prisma.collar.create({ data: { serialNumber, dogId: null } });

  const reply = fakeReply();
  await pairCollar(
    fakeRequest(owner.id, { dogId: dog.id }, { serialNumber }),
    reply as unknown as FastifyReply,
  );

  assert.equal(reply.statusCode, 200);
  const inDb = await prisma.collar.findUnique({ where: { serialNumber } });
  assert.equal(inDb?.dogId, dog.id);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('POST /dogs/:dogId/collar/pair is idempotent when re-pairing the same collar to the same dog', async () => {
  const { owner, dog } = await createOwnerWithDog('IdempotentPairDog');
  const serialNumber = `IDEMPOTENT-${randomUUID()}`;

  const firstReply = fakeReply();
  await pairCollar(
    fakeRequest(owner.id, { dogId: dog.id }, { serialNumber }),
    firstReply as unknown as FastifyReply,
  );
  assert.equal(firstReply.statusCode, 201);

  const secondReply = fakeReply();
  await pairCollar(
    fakeRequest(owner.id, { dogId: dog.id }, { serialNumber }),
    secondReply as unknown as FastifyReply,
  );
  assert.equal(secondReply.statusCode, 200);

  const count = await prisma.collar.count({ where: { serialNumber } });
  assert.equal(count, 1, 're-pairing must not create a duplicate collar row');

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('POST /dogs/:dogId/collar/pair refuses a serial already paired to another dog', async () => {
  const { owner: ownerA, dog: dogA } = await createOwnerWithDog('SerialOwnerADog');
  const { owner: ownerB, dog: dogB } = await createOwnerWithDog('SerialOwnerBDog');
  const serialNumber = `TAKEN-${randomUUID()}`;
  await prisma.collar.create({ data: { serialNumber, dogId: dogA.id } });

  const reply = fakeReply();
  await assert.rejects(
    () =>
      pairCollar(
        fakeRequest(ownerB.id, { dogId: dogB.id }, { serialNumber }),
        reply as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 409);
      return true;
    },
  );

  const stillDogA = await prisma.collar.findUnique({ where: { serialNumber } });
  assert.equal(stillDogA?.dogId, dogA.id);

  // cleanup
  await prisma.dog.delete({ where: { id: dogA.id } });
  await prisma.dog.delete({ where: { id: dogB.id } });
  await prisma.user.delete({ where: { id: ownerA.id } });
  await prisma.user.delete({ where: { id: ownerB.id } });
});

test('POST /dogs/:dogId/collar/pair refuses a second, different collar for a dog that already has one', async () => {
  const { owner, dog } = await createOwnerWithDog('AlreadyEquippedDog');
  const firstSerial = `FIRST-${randomUUID()}`;
  await prisma.collar.create({ data: { serialNumber: firstSerial, dogId: dog.id } });
  const secondSerial = `SECOND-${randomUUID()}`;

  const reply = fakeReply();
  await assert.rejects(
    () =>
      pairCollar(
        fakeRequest(owner.id, { dogId: dog.id }, { serialNumber: secondSerial }),
        reply as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 409);
      return true;
    },
  );

  assert.equal(await prisma.collar.count({ where: { serialNumber: secondSerial } }), 0);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
});

test('GET /dogs/:dogId refuses a dog_sitter whose access has expired', async () => {
  const { owner, dog } = await createOwnerWithDog('ExpiredSitterReadDog');
  const hash = await bcrypt.hash('irrelevant', 4);
  const sitter = await prisma.user.create({
    data: {
      email: `expired-sitter-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Expired',
      lastName: 'Sitter',
    },
  });
  await prisma.dogUser.create({
    data: {
      dogId: dog.id,
      userId: sitter.id,
      role: 'dog_sitter',
      expiresAt: new Date(Date.now() - 60 * 60 * 1000), // expired 1h ago
    },
  });

  await assert.rejects(
    () => getDog(fakeRequest(sitter.id, { dogId: dog.id }), fakeReply() as unknown as FastifyReply),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
  await prisma.user.delete({ where: { id: sitter.id } });
});

test('GET /dogs/:dogId allows a dog_sitter whose access is still within its window', async () => {
  const { owner, dog } = await createOwnerWithDog('ActiveSitterReadDog');
  const hash = await bcrypt.hash('irrelevant', 4);
  const sitter = await prisma.user.create({
    data: {
      email: `active-sitter-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Active',
      lastName: 'Sitter',
    },
  });
  await prisma.dogUser.create({
    data: {
      dogId: dog.id,
      userId: sitter.id,
      role: 'dog_sitter',
      expiresAt: new Date(Date.now() + 60 * 60 * 1000),
    },
  });

  const reply = fakeReply();
  await getDog(fakeRequest(sitter.id, { dogId: dog.id }), reply as unknown as FastifyReply);
  assert.equal(reply.statusCode, 200);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
  await prisma.user.delete({ where: { id: sitter.id } });
});

test('POST /dogs/:dogId/collar/pair refuses when the caller is not the owner', async () => {
  const { owner, dog } = await createOwnerWithDog('NonOwnerPairDog');
  const hash = await bcrypt.hash('irrelevant', 4);
  const familyMember = await prisma.user.create({
    data: {
      email: `family-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Family',
      lastName: 'Member',
    },
  });
  await prisma.dogUser.create({ data: { dogId: dog.id, userId: familyMember.id, role: 'family' } });
  const serialNumber = `NONOWNER-${randomUUID()}`;

  const reply = fakeReply();
  await assert.rejects(
    () =>
      pairCollar(
        fakeRequest(familyMember.id, { dogId: dog.id }, { serialNumber }),
        reply as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 403);
      return true;
    },
  );

  assert.equal(await prisma.collar.count({ where: { serialNumber } }), 0);

  // cleanup
  await prisma.dog.delete({ where: { id: dog.id } });
  await prisma.user.delete({ where: { id: owner.id } });
  await prisma.user.delete({ where: { id: familyMember.id } });
});
