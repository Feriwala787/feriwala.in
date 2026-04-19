const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const path = require('node:path');

const SERVER_START_TIMEOUT_MS = 10000;

async function waitForHealth(baseUrl, timeoutMs) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    try {
      const res = await fetch(`${baseUrl}/api/health`);
      if (res.status === 200) return;
    } catch (err) {
      // server not ready yet
    }
    await new Promise(resolve => setTimeout(resolve, 150));
  }
  throw new Error('Timed out waiting for server health endpoint');
}

test('health endpoints respond with expected status shape when DB is unavailable', async () => {
  const port = 3310;
  const baseUrl = `http://127.0.0.1:${port}`;

  const server = spawn(process.execPath, ['src/server.js'], {
    cwd: path.resolve(__dirname, '..'),
    env: {
      ...process.env,
      PORT: String(port),
      HEALTHCHECK_TIMEOUT_MS: '250',
      DB_RETRY_INTERVAL_MS: '1000',
      MONGODB_URI: '',
      PG_HOST: '127.0.0.1',
      PG_PORT: '5432',
      PG_DATABASE: 'feriwala',
      PG_USER: 'invalid',
      PG_PASSWORD: 'invalid',
    },
    stdio: 'ignore',
  });

  try {
    await waitForHealth(baseUrl, SERVER_START_TIMEOUT_MS);

    const healthRes = await fetch(`${baseUrl}/api/health`);
    assert.equal(healthRes.status, 200);
    const healthBody = await healthRes.json();
    assert.equal(healthBody.status, 'ok');

    const deepRes = await fetch(`${baseUrl}/api/health/deep`);
    assert.equal(deepRes.status, 503);
    const deepBody = await deepRes.json();
    assert.equal(deepBody.status, 'degraded');
    assert.equal(typeof deepBody.services?.mongo?.ready, 'boolean');
    assert.equal(typeof deepBody.services?.postgres?.ready, 'boolean');
    assert.equal(deepBody.services.mongo.ready, false);
  } finally {
    server.kill('SIGTERM');
  }
});
