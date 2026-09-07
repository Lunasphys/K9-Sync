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
import { AuthController } from './auth.controller.js';
import { mailer } from '../../shared/mailer.js';

initPrisma(process.env.DATABASE_URL ?? '');
const prisma = getPrisma();
const controller = new AuthController();

function fakeRequest(body?: unknown): FastifyRequest {
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

after(async () => {
  await prisma.$disconnect();
});

test(
  'POST /auth/refresh — two concurrent calls with the same refresh token: one succeeds, ' +
    'the other fails cleanly with 401 instead of crashing with an unhandled Prisma error',
  async () => {
    const passwordHash = await bcrypt.hash('irrelevant', 4);
    const user = await prisma.user.create({
      data: {
        email: `refresh-race-${randomUUID()}@test.local`,
        passwordHash,
        firstName: 'Race',
        lastName: 'Condition',
      },
    });

    const rawToken = randomUUID();
    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        token: await bcrypt.hash(rawToken, 4),
        expiresAt: new Date(Date.now() + 86400000),
      },
    });

    // Reproduces the scenario from the app: several in-flight API calls all
    // 401 around the same time and each independently calls /auth/refresh
    // with the same stored raw refresh token, concurrently.
    const replyA = fakeReply();
    const replyB = fakeReply();
    const [resultA, resultB] = await Promise.allSettled([
      controller.refresh(fakeRequest({ refreshToken: rawToken }), replyA as unknown as FastifyReply),
      controller.refresh(fakeRequest({ refreshToken: rawToken }), replyB as unknown as FastifyReply),
    ]);

    const outcomes = [
      { result: resultA, reply: replyA },
      { result: resultB, reply: replyB },
    ];
    const fulfilled = outcomes.filter((o) => o.result.status === 'fulfilled');
    const rejected = outcomes.filter((o) => o.result.status === 'rejected');

    // Exactly one call wins the race and gets new tokens.
    assert.equal(fulfilled.length, 1, 'exactly one concurrent refresh must succeed');
    assert.equal(fulfilled[0].reply.statusCode, 200);
    const winnerPayload = fulfilled[0].reply.payload as {
      accessToken: string;
      refreshToken: string;
    };
    assert.ok(winnerPayload.accessToken);
    assert.ok(winnerPayload.refreshToken);
    assert.notEqual(winnerPayload.refreshToken, rawToken, 'must be a freshly rotated token');

    // The other call must fail cleanly — a 401 UnauthorizedError, never an
    // unhandled Prisma "record to delete does not exist" crash (the original
    // bug: a raw `delete({ where: { id } })` on a row a concurrent request
    // had already removed).
    assert.equal(rejected.length, 1, 'exactly one concurrent refresh must fail');
    const error = (rejected[0].result as PromiseRejectedResult).reason as {
      statusCode?: number;
      code?: string;
      name?: string;
    };
    assert.equal(error.statusCode, 401, 'the loser must get a clean 401, not a 500 crash');
    assert.notEqual(
      error.name,
      'PrismaClientKnownRequestError',
      'the raw Prisma delete-not-found error must never leak past the controller',
    );

    // No leftover state: the old token is gone, exactly one new token exists.
    assert.equal(await prisma.refreshToken.count({ where: { userId: user.id } }), 1);

    // cleanup
    await prisma.refreshToken.deleteMany({ where: { userId: user.id } });
    await prisma.user.delete({ where: { id: user.id } });
  },
);

test('POST /auth/refresh — a token already consumed by a prior refresh is rejected with 401', async () => {
  const passwordHash = await bcrypt.hash('irrelevant', 4);
  const user = await prisma.user.create({
    data: {
      email: `refresh-reuse-${randomUUID()}@test.local`,
      passwordHash,
      firstName: 'Reuse',
      lastName: 'Test',
    },
  });

  const rawToken = randomUUID();
  await prisma.refreshToken.create({
    data: {
      userId: user.id,
      token: await bcrypt.hash(rawToken, 4),
      expiresAt: new Date(Date.now() + 86400000),
    },
  });

  // First use — succeeds and rotates the token.
  const firstReply = fakeReply();
  await controller.refresh(
    fakeRequest({ refreshToken: rawToken }),
    firstReply as unknown as FastifyReply,
  );
  assert.equal(firstReply.statusCode, 200);

  // Second use of the now-stale raw token — sequential, not concurrent —
  // must also fail with a clean 401.
  const secondReply = fakeReply();
  await assert.rejects(
    () =>
      controller.refresh(
        fakeRequest({ refreshToken: rawToken }),
        secondReply as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 401);
      return true;
    },
  );

  // cleanup
  await prisma.refreshToken.deleteMany({ where: { userId: user.id } });
  await prisma.user.delete({ where: { id: user.id } });
});

// ── Password reset ───────────────────────────────────────────────────────────

async function createUser(prefix: string) {
  const hash = await bcrypt.hash('OldPassword1', 12);
  return prisma.user.create({
    data: {
      email: `${prefix}-${randomUUID()}@test.local`,
      passwordHash: hash,
      firstName: 'Reset',
      lastName: 'Test',
    },
  });
}

test('POST /auth/forgot-password generates a hashed reset code and emails it', async (t) => {
  const user = await createUser('forgot');

  const sent: Array<{ to: string; code: string; expiresInMinutes: number }> = [];
  t.mock.method(
    mailer,
    'sendPasswordResetEmail',
    async (to: string, code: string, expiresInMinutes: number) => {
      sent.push({ to, code, expiresInMinutes });
    },
  );

  const reply = fakeReply();
  await controller.forgotPassword(fakeRequest({ email: user.email }), reply as unknown as FastifyReply);

  // Never leaks whether the account exists via the response.
  assert.equal(reply.statusCode, 202);

  assert.equal(sent.length, 1);
  assert.equal(sent[0].to, user.email);
  assert.match(sent[0].code, /^\d{6}$/, 'code must be exactly 6 digits');

  const stored = await prisma.passwordResetToken.findFirst({ where: { userId: user.id } });
  assert.ok(stored, 'a PasswordResetToken row must be created');
  assert.ok(
    await bcrypt.compare(sent[0].code, stored!.token),
    'the stored token must be a bcrypt hash of the emailed code, never the code itself',
  );

  // cleanup
  await prisma.passwordResetToken.deleteMany({ where: { userId: user.id } });
  await prisma.user.delete({ where: { id: user.id } });
});

test('POST /auth/forgot-password responds 202 for an unknown email too, without creating anything', async () => {
  const reply = fakeReply();
  await controller.forgotPassword(
    fakeRequest({ email: `nobody-${randomUUID()}@test.local` }),
    reply as unknown as FastifyReply,
  );
  assert.equal(reply.statusCode, 202, 'must not reveal that the account does not exist');
});

test('POST /auth/reset-password with a valid code sets the new password and invalidates every existing session', async () => {
  const user = await createUser('reset-success');
  const code = '123456';
  await prisma.passwordResetToken.create({
    data: {
      userId: user.id,
      token: await bcrypt.hash(code, 12),
      expiresAt: new Date(Date.now() + 15 * 60 * 1000),
    },
  });
  // Simulate two logged-in devices — both sessions must die on reset.
  await prisma.refreshToken.createMany({
    data: [
      { userId: user.id, token: await bcrypt.hash('device-a', 4), expiresAt: new Date(Date.now() + 86400000) },
      { userId: user.id, token: await bcrypt.hash('device-b', 4), expiresAt: new Date(Date.now() + 86400000) },
    ],
  });

  const reply = fakeReply();
  await controller.resetPassword(
    fakeRequest({ email: user.email, code, newPassword: 'BrandNewPassword1' }),
    reply as unknown as FastifyReply,
  );

  assert.equal(reply.statusCode, 204);

  const updated = await prisma.user.findUnique({ where: { id: user.id } });
  assert.ok(await bcrypt.compare('BrandNewPassword1', updated!.passwordHash));
  assert.equal(
    await bcrypt.compare('OldPassword1', updated!.passwordHash),
    false,
    'the old password must no longer work',
  );

  assert.equal(
    await prisma.refreshToken.count({ where: { userId: user.id } }),
    0,
    'every existing session must be invalidated by a password reset',
  );
  assert.equal(
    await prisma.passwordResetToken.count({ where: { userId: user.id } }),
    0,
    'the used code (and any other outstanding one) must be gone',
  );

  // cleanup
  await prisma.user.delete({ where: { id: user.id } });
});

test('POST /auth/reset-password refuses an invalid code and leaves the password unchanged', async () => {
  const user = await createUser('reset-invalid');
  await prisma.passwordResetToken.create({
    data: {
      userId: user.id,
      token: await bcrypt.hash('123456', 12),
      expiresAt: new Date(Date.now() + 15 * 60 * 1000),
    },
  });

  const reply = fakeReply();
  await assert.rejects(
    () =>
      controller.resetPassword(
        fakeRequest({ email: user.email, code: '999999', newPassword: 'BrandNewPassword1' }),
        reply as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 401);
      return true;
    },
  );

  const stillThere = await prisma.user.findUnique({ where: { id: user.id } });
  assert.ok(await bcrypt.compare('OldPassword1', stillThere!.passwordHash));

  // cleanup
  await prisma.passwordResetToken.deleteMany({ where: { userId: user.id } });
  await prisma.user.delete({ where: { id: user.id } });
});

test('POST /auth/reset-password refuses an expired code', async () => {
  const user = await createUser('reset-expired');
  const code = '123456';
  await prisma.passwordResetToken.create({
    data: {
      userId: user.id,
      token: await bcrypt.hash(code, 12),
      expiresAt: new Date(Date.now() - 60 * 1000), // 1 minute in the past
    },
  });

  const reply = fakeReply();
  await assert.rejects(
    () =>
      controller.resetPassword(
        fakeRequest({ email: user.email, code, newPassword: 'BrandNewPassword1' }),
        reply as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 401);
      return true;
    },
  );

  // cleanup
  await prisma.passwordResetToken.deleteMany({ where: { userId: user.id } });
  await prisma.user.delete({ where: { id: user.id } });
});

test('POST /auth/reset-password refuses a code that was already used', async () => {
  const user = await createUser('reset-reuse');
  const code = '123456';
  await prisma.passwordResetToken.create({
    data: {
      userId: user.id,
      token: await bcrypt.hash(code, 12),
      expiresAt: new Date(Date.now() + 15 * 60 * 1000),
    },
  });

  // First use — succeeds and consumes the code.
  const firstReply = fakeReply();
  await controller.resetPassword(
    fakeRequest({ email: user.email, code, newPassword: 'FirstNewPassword1' }),
    firstReply as unknown as FastifyReply,
  );
  assert.equal(firstReply.statusCode, 204);

  // Second use of the same code — must be rejected, not silently accepted.
  const secondReply = fakeReply();
  await assert.rejects(
    () =>
      controller.resetPassword(
        fakeRequest({ email: user.email, code, newPassword: 'SecondNewPassword1' }),
        secondReply as unknown as FastifyReply,
      ),
    (err: unknown) => {
      assert.equal((err as { statusCode?: number }).statusCode, 401);
      return true;
    },
  );

  // The password from the first (successful) reset must still be in effect.
  const finalUser = await prisma.user.findUnique({ where: { id: user.id } });
  assert.ok(await bcrypt.compare('FirstNewPassword1', finalUser!.passwordHash));

  // cleanup
  await prisma.user.delete({ where: { id: user.id } });
});
