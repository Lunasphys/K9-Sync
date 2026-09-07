// Integration test — exercises the real Fastify HTTP layer (body/content-type
// parsing) via app.inject(), not just the controller in isolation. Does not
// require Postgres: /auth/logout with an empty body never touches Prisma.
// Run manually: npm run test:integration
import './load-env.js';
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from './app.js';

async function makeApp() {
  const app = await buildApp();
  await app.ready();
  return app;
}

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

test('POST /auth/logout with genuinely malformed (non-empty) JSON is still rejected, not silently treated as an empty body', async () => {
  const app = await makeApp();
  try {
    const res = await app.inject({
      method: 'POST',
      url: '/v1/auth/logout',
      headers: { 'content-type': 'application/json' },
      payload: '{not valid json',
    });
    assert.notEqual(res.statusCode, 204);
  } finally {
    await app.close();
  }
});
