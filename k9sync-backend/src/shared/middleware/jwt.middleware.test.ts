import { test } from 'node:test';
import assert from 'node:assert/strict';
import jwt from 'jsonwebtoken';
import type { FastifyReply, FastifyRequest } from 'fastify';
import { jwtAuth } from './jwt.middleware.js';

const SECRET = 'test_secret_at_least_32_characters_long_0123456789';
process.env.JWT_ACCESS_SECRET = SECRET;

function fakeRequest(authorization?: string): FastifyRequest {
  return { headers: { authorization } } as unknown as FastifyRequest;
}

const fakeReply = {} as FastifyReply;

test('jwtAuth rejects a request with no Authorization header', async () => {
  const req = fakeRequest(undefined);
  await assert.rejects(() => jwtAuth(req, fakeReply), /Missing authorization header/);
});

test('jwtAuth rejects a header that is not a Bearer token', async () => {
  const req = fakeRequest('Basic somecreds');
  await assert.rejects(() => jwtAuth(req, fakeReply), /Missing authorization header/);
});

test('jwtAuth rejects the previously exploitable forged token format', async () => {
  // Reproduces the old vulnerable scheme this middleware used to accept:
  // base64(JSON payload) + '.' + secret.slice(0, 8) — a constant suffix, not a real
  // signature over the payload. Any holder of one legitimate token could forge a
  // token for an arbitrary `sub` this way. Must now be rejected.
  const forgedPayload = Buffer.from(
    JSON.stringify({ sub: '00000000-0000-0000-0000-000000000000', iat: Date.now() }),
  ).toString('base64');
  const forgedToken = `${forgedPayload}.${SECRET.slice(0, 8)}`;

  const req = fakeRequest(`Bearer ${forgedToken}`);
  await assert.rejects(() => jwtAuth(req, fakeReply), /Invalid token signature/);
  assert.equal(req.userId, undefined);
});

test('jwtAuth rejects a garbage/malformed token', async () => {
  const req = fakeRequest('Bearer not-a-real-token');
  await assert.rejects(() => jwtAuth(req, fakeReply), /Invalid token signature/);
});

test('jwtAuth rejects a token signed with a different secret', async () => {
  const token = jwt.sign({ sub: 'user-1' }, 'a-completely-different-secret-value-here', {
    expiresIn: '15m',
  });
  const req = fakeRequest(`Bearer ${token}`);
  await assert.rejects(() => jwtAuth(req, fakeReply), /Invalid token signature/);
});

test('jwtAuth rejects an expired token', async () => {
  const expiredToken = jwt.sign({ sub: 'user-1' }, SECRET, { expiresIn: -10 });
  const req = fakeRequest(`Bearer ${expiredToken}`);
  await assert.rejects(() => jwtAuth(req, fakeReply), /Token expired/);
});

test('jwtAuth accepts a validly signed, non-expired token and sets req.userId', async () => {
  const token = jwt.sign({ sub: 'user-42' }, SECRET, { expiresIn: '15m' });
  const req = fakeRequest(`Bearer ${token}`);
  await jwtAuth(req, fakeReply);
  assert.equal(req.userId, 'user-42');
});
