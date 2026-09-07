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
