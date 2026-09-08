// Integration test — exercises the real Fastify HTTP layer (body/content-type
// parsing, error handler) via app.inject(), not just the controller in
// isolation. The /auth/logout tests below don't need Postgres, but the
// dog-access tests do (create a real user + dog).
// Run manually: npm run test:integration
import './load-env.js';
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { buildApp } from './app.js';
import { initPrisma, getPrisma } from './config/database.js';

initPrisma(process.env.DATABASE_URL ?? '');
const prisma = getPrisma();

async function makeApp() {
  const app = await buildApp();
  await app.ready();
  return app;
}

after(async () => {
  await prisma.$disconnect();
});

test('POST /auth/logout with Content-Type: application/json and an empty body succeeds (204), no server error', async () => {
  const app = await makeApp();
  try {
    const res = await app.inject({
      method: 'POST',
      url: '/v1/auth/logout',
      headers: { 'content-type': 'application/json' },
      payload: '',
    });
    assert.equal(res.statusCode, 204);
  } finally {
    await app.close();
  }
});

test('POST /auth/logout with no body and no Content-Type header succeeds (204)', async () => {
  const app = await makeApp();
  try {
    const res = await app.inject({ method: 'POST', url: '/v1/auth/logout' });
    assert.equal(res.statusCode, 204);
  } finally {
    await app.close();
  }
});

test('POST /auth/logout with a valid empty JSON object body still succeeds (204) — unchanged behavior', async () => {
  const app = await makeApp();
  try {
    const res = await app.inject({
      method: 'POST',
      url: '/v1/auth/logout',
      headers: { 'content-type': 'application/json' },
      payload: '{}',
    });
    assert.equal(res.statusCode, 204);
  } finally {
    await app.close();
  }
});

test('POST /auth/logout with genuinely malformed (non-empty) JSON is rejected with a clean 400, not treated as empty or a 500', async () => {
  const app = await makeApp();
  try {
    const res = await app.inject({
      method: 'POST',
      url: '/v1/auth/logout',
      headers: { 'content-type': 'application/json' },
      payload: '{not valid json',
    });
    // The content-type parser sets statusCode 400 on the SyntaxError; now that
    // the error handler below respects a bolted-on .statusCode on any thrown
    // value, this parse error surfaces as a real 400 instead of a 500.
    assert.equal(res.statusCode, 400);
  } finally {
    await app.close();
  }
});

test('GET /dogs/:dogId/alerts returns a real 403, not 500, for a user with no access to the dog', async () => {
  const app = await makeApp();
  try {
    const hash = await bcrypt.hash('irrelevant', 4);
    const user = await prisma.user.create({
      data: {
        email: `no-access-403-${randomUUID()}@test.local`,
        passwordHash: hash,
        firstName: 'No',
        lastName: 'Access',
      },
    });
    // A dog this user has no DogUser row for at all.
    const dog = await prisma.dog.create({ data: { name: 'ForbiddenAlertsDog' } });
    const token = jwt.sign({ sub: user.id }, process.env.JWT_ACCESS_SECRET ?? '', {
      expiresIn: '15m',
    });

    const res = await app.inject({
      method: 'GET',
      url: `/v1/dogs/${dog.id}/alerts`,
      headers: { authorization: `Bearer ${token}` },
    });

    assert.equal(res.statusCode, 403, 'must be a real 403, not a 500 "Unhandled error"');
    const body = JSON.parse(res.payload);
    assert.equal(body.error.code, 'FORBIDDEN');

    // cleanup
    await prisma.dog.delete({ where: { id: dog.id } });
    await prisma.user.delete({ where: { id: user.id } });
  } finally {
    await app.close();
  }
});

test('GET /dogs/:dogId/alerts refuses a dog_sitter whose access has expired', async () => {
  const app = await makeApp();
  try {
    const hash = await bcrypt.hash('irrelevant', 4);
    const sitter = await prisma.user.create({
      data: {
        email: `alerts-expired-sitter-${randomUUID()}@test.local`,
        passwordHash: hash,
        firstName: 'Expired',
        lastName: 'Sitter',
      },
    });
    const dog = await prisma.dog.create({ data: { name: 'ExpiredSitterAlertsDog' } });
    await prisma.dogUser.create({
      data: {
        dogId: dog.id,
        userId: sitter.id,
        role: 'dog_sitter',
        expiresAt: new Date(Date.now() - 60 * 60 * 1000), // expired 1h ago
      },
    });
    const token = jwt.sign({ sub: sitter.id }, process.env.JWT_ACCESS_SECRET ?? '', {
      expiresIn: '15m',
    });

    const res = await app.inject({
      method: 'GET',
      url: `/v1/dogs/${dog.id}/alerts`,
      headers: { authorization: `Bearer ${token}` },
    });

    assert.equal(res.statusCode, 403, 'an expired dog_sitter grant must not still read alerts');

    // cleanup
    await prisma.dog.delete({ where: { id: dog.id } });
    await prisma.user.delete({ where: { id: sitter.id } });
  } finally {
    await app.close();
  }
});
