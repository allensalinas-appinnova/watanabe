import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {executeUserDataReset} from '../lib/user_data_reset.js';
import {applyOperationEvent} from '../lib/projection_store.js';
import {app, db, seedUser, userDump} from './projection_test_support.mjs';

after(() => deleteApp(app));
const command = (requestId = 'reset-command-001', expectedGeneration = 0) => ({
  requestId, expectedGeneration, confirmed: true,
});

test('reset recursively removes user data, preserves global catalog and Firebase identity state', async () => {
  const root = await seedUser('reset-complete');
  await root.update({locale: 'es', appearancePreferences: {mode: 'dark', palette: 'lumio'}});
  await root.collection('operations').doc('nested-operation').collection('entries').doc('entry').set({private: true});
  await root.collection('coachWeeklyReviews').doc('2026-10-19').set({kind: 'weekly'});
  await root.collection('emailImportCandidates').doc('candidate').collection('nested').doc('evidence').set({private: true});
  await root.collection('budgetCommands').doc('receipt-001').set({private: true});
  await db.doc('categoryCatalog/shared-expense').set({type: 'expense'});

  const result = await executeUserDataReset(db, root.id, command());
  assert.deepEqual(result, {requestId: 'reset-command-001', dataGeneration: 1, status: 'complete'});
  const remaining = await userDump(root);
  assert.deepEqual(Object.keys(remaining), [root.path]);
  assert.equal(remaining[root.path].data.dataGeneration, 1);
  assert.equal(remaining[root.path].data.resetStatus, 'ready');
  assert.equal(remaining[root.path].data.resetRequestId, 'reset-command-001');
  assert.equal(remaining[root.path].data.resetPreviousGeneration, 0);
  assert.equal(remaining[root.path].data.onboardingStatus, 'not_started');
  assert.equal('locale' in remaining[root.path].data, false);
  assert.equal((await db.doc('categoryCatalog/shared-expense').get()).exists, true);
  assert.equal((await root.collection('accounts').get()).size, 0);
  assert.equal((await root.collection('operations').get()).size, 0);
  assert.equal((await root.collection('budgetCommands').get()).size, 0);
  await assert.doesNotReject(applyOperationEvent(db, {
    userId: root.id,
    operationId: 'delayed-reset-operation',
    eventId: 'delayed-debt-trigger',
    current: {
      type: 'expense', amountMinor: 1200, currency: 'COP', monthKey: '2026-10',
      accountId: 'deleted-account', categoryId: 'deleted-category', status: 'confirmed',
      debtCommandId: 'deleted-receipt', idempotencyKey: 'delayed-operation', dataGeneration: 0,
    },
  }));
  assert.equal((await root.collection('accounts').get()).size, 0);
});

test('same request retries a partial reset and completed replay; other users and stale requests are isolated', async () => {
  const root = await seedUser('reset-retry');
  await root.update({dataGeneration: 1, resetStatus: 'resetting', resetRequestId: 'reset-command-002', resetPreviousGeneration: 0});
  await root.collection('accounts').doc('partial').set({name: 'partial'});
  const first = await executeUserDataReset(db, root.id, command('reset-command-002'));
  assert.equal(first.dataGeneration, 1);
  assert.deepEqual(await executeUserDataReset(db, root.id, command('reset-command-002')), first);
  await assert.rejects(executeUserDataReset(db, root.id, command('another-command-002', 0)), {issue: 'reset-generation-conflict'});
  await assert.rejects(executeUserDataReset(db, undefined, command()), {status: 'unauthenticated'});
  await assert.rejects(executeUserDataReset(db, 'other-reset-user', command()), {issue: 'reset-profile-missing'});
});

test('a live worker lease prevents concurrent deletion; an expired lease is resumable', async () => {
  const root = await seedUser('reset-worker-lease');
  await root.update({dataGeneration: 1, resetStatus: 'resetting', resetRequestId: 'reset-command-003', resetPreviousGeneration: 0,
    resetWorkerToken: 'active-worker', resetLeaseUntil: Date.now() + 60_000});
  await assert.rejects(executeUserDataReset(db, root.id, command('reset-command-003')), {issue: 'reset-already-in-progress'});
  await root.update({resetLeaseUntil: Date.now() - 1});
  const resumed = await executeUserDataReset(db, root.id, command('reset-command-003'));
  assert.equal(resumed.status, 'complete');
  assert.equal((await root.get()).data().resetWorkerToken, undefined);
});

test('reset rejects malformed and unconfirmed commands without changing the profile', async () => {
  const root = await seedUser('reset-invalid');
  const before = (await root.get()).data();
  for (const payload of [
    {...command(), confirmed: false},
    {...command(), unexpected: true},
    {...command(), expectedGeneration: -1},
    {...command(), requestId: 'short'},
  ]) {
    await assert.rejects(executeUserDataReset(db, root.id, payload), {status: 'invalid-argument'});
    assert.deepEqual((await root.get()).data(), before);
  }
});
