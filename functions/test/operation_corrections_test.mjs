import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {applyOperationEvent} from '../lib/projection_store.js';
import {executeOperationCorrection} from '../lib/operation_corrections.js';
import {app, db} from './projection_test_support.mjs';

after(() => deleteApp(app));

test('editing a confirmed expense updates the operation and all projections atomically and idempotently', async () => {
  const uid = `edit-${Date.now()}`;
  const root = db.doc(`users/${uid}`);
  const operationRef = root.collection('operations').doc('original-operation');
  const original = {
    id: 'original-operation', idempotencyKey: 'original-operation', type: 'expense', amountMinor: 1200,
    currency: 'COP', accountId: 'bank', categoryId: 'food', monthKey: '2026-10',
    occurredAt: new Date('2026-10-20T15:00:00Z'), description: 'Old description', status: 'confirmed',
    dataGeneration: 0, revision: 0,
  };
  const batch = db.batch();
  batch.set(root, {dataGeneration: 0, timeZone: 'America/Bogota', resetStatus: 'ready'});
  batch.set(root.collection('accounts').doc('bank'), {
    currency: 'COP', nature: 'money', status: 'active', openingBalanceMinor: 10000, currentBalanceMinor: 8800,
  });
  batch.set(root.collection('categories').doc('food'), {type: 'expense', isArchived: false});
  batch.set(root.collection('categories').doc('travel'), {type: 'expense', isArchived: false});
  batch.set(root.collection('monthlySummaries').doc('2026-10_COP'), {
    monthKey: '2026-10', currency: 'COP', expenseMinor: 1200, incomeMinor: 0,
    transferInMinor: 0, transferOutMinor: 0, byCategory: {food: -1200},
  });
  batch.set(operationRef, original);
  await batch.commit();

  const command = {
    requestId: 'edit-command-0001', expectedGeneration: 0, expectedRevision: 0,
    operationId: 'original-operation', amountMinor: 2500, currency: 'COP', accountId: 'bank',
    categoryId: 'travel', monthKey: '2026-11', occurredAt: '2026-11-02T15:00:00.000Z',
    description: 'Corrected description',
  };
  const result = await executeOperationCorrection(db, uid, command);
  assert.deepEqual(result, {operationId: 'original-operation', revision: 1});

  const updated = (await operationRef.get()).data();
  assert.equal(updated.amountMinor, 2500);
  assert.equal(updated.categoryId, 'travel');
  assert.equal(updated.description, 'Corrected description');
  assert.equal(updated.revision, 1);
  assert.equal((await root.collection('accounts').doc('bank').get()).data().currentBalanceMinor, 7500);
  assert.equal((await root.collection('monthlySummaries').doc('2026-10_COP').get()).data().expenseMinor, 0);
  const november = (await root.collection('monthlySummaries').doc('2026-11_COP').get()).data();
  assert.equal(november.expenseMinor, 2500);
  assert.equal(november.byCategory.travel, -2500);

  // The asynchronous projection trigger must not apply the callable's atomic deltas a second time.
  await applyOperationEvent(db, {userId: uid, eventId: 'correction-trigger', previous: original, current: updated});
  // A delayed original creation event must not apply the old expense after the
  // correction has advanced the live operation revision.
  await applyOperationEvent(db, {userId: uid, eventId: 'delayed-create-trigger', current: original});
  assert.equal((await root.collection('accounts').doc('bank').get()).data().currentBalanceMinor, 7500);

  const replay = await executeOperationCorrection(db, uid, command);
  assert.deepEqual(replay, result);
  await assert.rejects(
    executeOperationCorrection(db, uid, {...command, description: 'different payload'}),
    (error) => error.issue === 'operation-edit-request-conflict',
  );
  await assert.rejects(
    executeOperationCorrection(db, uid, {...command, requestId: 'second-edit-command', expectedRevision: 0}),
    (error) => error.issue === 'operation-changed-elsewhere',
  );
});
