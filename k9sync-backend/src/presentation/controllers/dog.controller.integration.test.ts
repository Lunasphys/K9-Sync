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
import { inviteToDog, listDogUsers, revokeDogUser } from './dog.controller.js';
import { AuthController } from './auth.controller.js';

initPrisma(process.env.DATABASE_URL ?? '');
const prisma = getPrisma();
const dogController = { inviteToDog, listDogUsers, revokeDogUser };
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
