const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { ref, set, get } = require('firebase/database');

let env;
const host = process.env.FIREBASE_DATABASE_EMULATOR_HOST || '127.0.0.1:9000';
const [hostname, port] = host.split(':');
const id = 'a'.repeat(32);
const path = 'users/run-owner/runs/' + id;
const summary = () => ({
  startedAt: Date.now() - 10000, durationSec: 85, distanceM: 104,
});

before(async () => {
  // A separate namespace lets the pre-existing tests clear their own fixture DB.
  env = await initializeTestEnvironment({
    projectId: 'demo-bimbi-runs',
    database: {
      host: hostname, port: Number(port),
      rules: fs.readFileSync('../database.rules.json', 'utf8'),
    },
  });
});
beforeEach(async () => env.clearDatabase());
after(async () => env?.cleanup());
const owner = () => env.authenticatedContext('run-owner', { email_verified: true }).database();

test('two clients read the same totals and repeat writes are idempotent', async () => {
  const run = summary();
  const first = ref(owner(), path);
  const second = ref(owner(), path);
  await assertSucceeds(set(first, run));
  await assertSucceeds(set(first, run));
  const data = await assertSucceeds(get(second));
  assert.deepEqual(data.val(), run);
  const rows = await get(ref(owner(), 'users/run-owner/runs'));
  assert.equal(rows.size, 1);
});

test('guest, unverified owner and other account cannot read or change saved runs', async () => {
  await set(ref(owner(), path), summary());
  const actors = [
    env.unauthenticatedContext(),
    env.authenticatedContext('run-owner', { email_verified: false }),
    env.authenticatedContext('other', { email_verified: true }),
  ];
  for (const actor of actors) {
    await assertFails(get(ref(actor.database(), 'users/run-owner/runs')));
    await assertFails(set(ref(actor.database(), path), summary()));
    await assertFails(set(ref(actor.database(), path), { deleted: true }));
  }
});

test('coordinates, unexpected fields and malformed totals are rejected', async () => {
  const row = ref(owner(), path);
  const run = summary();
  for (const value of [
    { ...run, route: [[0, 0]] }, { ...run, latitude: 0 },
    { ...run, distanceM: -1 }, { ...run, durationSec: 8.5 },
    { ...run, distanceM: 1291 }, { ...run, startedAt: Date.now() + 600000 },
    { ...run, endedAt: Date.now() }, { ...run, deleted: true },
    { startedAt: run.startedAt, distanceM: 10 },
  ]) {
    await assertFails(set(row, value));
  }
  await assertFails(set(ref(owner(), 'users/run-owner/runs/bad-id'), run));
});

test('deletion removes the totals and prevents a stale retry from restoring them', async () => {
  const row = ref(owner(), path);
  const run = summary();
  await assertSucceeds(set(row, run));
  await assertFails(set(row, { ...run, distanceM: 105 }));
  await assertSucceeds(set(row, { deleted: true }));
  await assertSucceeds(set(row, { deleted: true }));
  assert.deepEqual((await get(row)).val(), { deleted: true });
  await assertFails(set(row, null));
  await assertFails(set(row, run));
});
