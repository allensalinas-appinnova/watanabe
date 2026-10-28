import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {auditProjections, compareProjections, readAuditSnapshot} from '../lib/projection_audit.js';
import {reconcileProjectionRepair} from '../lib/projection_reconciliation.js';
import {executeOperationCommand} from '../lib/operation_commands.js';
import {applyOperationEvent} from '../lib/projection_store.js';
import {app, db, operation, seedUser, userDump} from './projection_test_support.mjs';

after(() => deleteApp(app));

async function fixture(suffix) {
  const root = await seedUser(`repair-${suffix}-${Date.now()}`);
  await root.update({dataGeneration: 1, resetStatus: 'ready', timeZone: 'America/Bogota'});
  const expense = operation({amountMinor: 195000, dataGeneration: 1});
  const income = operation({type: 'income', amountMinor: 200000, categoryId: 'salary', dataGeneration: 1});
  const originalAdjustment = {
    requestId: 'legacy-technical-repair', dataGeneration: 1, digest: 'legacy-digest',
    adjustedAt: new Date('2026-10-27T23:00:00Z'), reason: 'PRIVATE OPERATOR NOTE',
    adjustments: [{accountId: 'cash', currency: 'COP', previousBalanceMinor: 85000, targetBalanceMinor: 105000, deltaMinor: 20000}],
  };
  const batch = db.batch();
  batch.update(root.collection('accounts').doc('cash'), {openingBalanceMinor: 0, currentBalanceMinor: 105000});
  batch.set(root.collection('operations').doc('expense'), expense);
  batch.set(root.collection('operations').doc('income'), income);
  batch.set(root.collection('balanceAdjustments').doc('real-opening-adjustment'), {
    adjustedAt: new Date('2026-10-25T12:00:00Z'),
    adjustments: [{accountId: 'cash', currency: 'COP', previousBalanceMinor: 0, targetBalanceMinor: 100000, deltaMinor: 100000}],
  });
  batch.set(root.collection('balanceAdjustments').doc('legacy-technical-repair'), originalAdjustment);
  batch.set(root.collection('monthlySummaries').doc('2026-10_COP'), {
    monthKey: '2026-10', currency: 'COP', incomeMinor: 200000, expenseMinor: 215000,
    transferInMinor: 0, transferOutMinor: 0, byCategory: {food: -215000, salary: 200000},
  });
  await batch.commit();
  const snapshot = await readAuditSnapshot(db, root.id);
  const financialAdjustments = new Map(snapshot.balanceAdjustments);
  financialAdjustments.delete('legacy-technical-repair');
  const reviewed = compareProjections({...snapshot, balanceAdjustments: financialAdjustments});
  const plan = {
    requestId: 'approved-repair-request', expectedGeneration: 1,
    expectedFingerprint: snapshot.fingerprint, legacyAdjustmentId: 'legacy-technical-repair',
    expectedDifferences: reviewed.differences, operator: 'synthetic-operator',
    reason: 'Explicitly approved technical repair; preserve money and fix derived totals.',
  };
  return {root, plan, expense, originalAdjustment};
}

test('technical repair preserves balances/history, archives the source and reconciles every checked projection', async () => {
  const {root, plan, originalAdjustment} = await fixture('complete');
  const before = await userDump(root);
  assert.equal((await auditProjections(db, root.id)).differences.length, 3);
  const result = await reconcileProjectionRepair(db, root.id, plan);
  assert.equal(result.correctedFields, 2);
  const after = await userDump(root);
  for (const [path, record] of Object.entries(before)) {
    if (/\/(accounts|operations|categories|budgets|ledgerEntries)\//.test(path)) {
      assert.deepEqual(after[path], record, `${path} must remain unchanged`);
    }
  }
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 105000);
  assert.equal((await root.collection('balanceAdjustments').doc('legacy-technical-repair').get()).exists, false);
  assert.equal((await root.collection('balanceAdjustments').doc('real-opening-adjustment').get()).exists, true);
  const receipt = (await root.collection('projectionRepairs').doc(plan.requestId).get()).data();
  assert.equal(receipt.kind, 'projection-only');
  assert.deepEqual(receipt.originalAdjustment.adjustments, originalAdjustment.adjustments);
  assert.equal(receipt.originalAdjustment.reason, originalAdjustment.reason);
  assert.equal(receipt.preservedAccountBalances.cash, 105000);
  assert.equal(receipt.after.complete, true);
  assert.deepEqual(receipt.after.differences, []);
  assert.equal((await root.get()).data().operationProjectionVersion, undefined, 'repair must not bypass migration');
  const audit = await auditProjections(db, root.id);
  assert.equal(audit.complete, true);
  assert.deepEqual(audit.differences, []);
  assert.doesNotMatch(JSON.stringify(audit), /PRIVATE/);
});

test('lost repair response, concurrent retries and conflicting reuse cannot apply the correction twice', async () => {
  const {root, plan} = await fixture('idempotent');
  const results = await Promise.all([
    reconcileProjectionRepair(db, root.id, plan), reconcileProjectionRepair(db, root.id, plan),
  ]);
  assert.deepEqual(results[0], results[1]);
  const beforeRetry = await userDump(root);
  assert.deepEqual(await reconcileProjectionRepair(db, root.id, plan), results[0]);
  assert.deepEqual(await userDump(root), beforeRetry);
  await assert.rejects(reconcileProjectionRepair(db, root.id, {...plan, reason: 'Another command'}), /repair_request_conflict/);
  assert.equal((await root.collection('projectionRepairs').get()).size, 1);
});

test('changed source, stale generation, reset and unexpected differences abort without partial writes', async () => {
  const {root, plan} = await fixture('guards');
  const before = await userDump(root);
  await assert.rejects(reconcileProjectionRepair(db, root.id, {...plan, expectedGeneration: 0}), /repair_stale_generation/);
  await assert.rejects(reconcileProjectionRepair(db, root.id, {...plan, expectedDifferences: []}), /invalid_repair_plan/);
  await assert.rejects(reconcileProjectionRepair(db, root.id, {
    ...plan, expectedDifferences: plan.expectedDifferences.slice(0, 1),
  }), /repair_unreviewed_differences/);
  assert.deepEqual(await userDump(root), before);
  await root.update({resetStatus: 'resetting'});
  await assert.rejects(reconcileProjectionRepair(db, root.id, plan), /repair_user_unavailable/);
  await root.update({resetStatus: 'ready'});
  await assert.rejects(reconcileProjectionRepair(db, root.id, plan), /repair_snapshot_changed/);
  assert.equal((await root.collection('projectionRepairs').get()).size, 0);
  assert.equal((await root.collection('balanceAdjustments').doc('legacy-technical-repair').get()).exists, true);
  assert.equal((await root.collection('monthlySummaries').doc('2026-10_COP').get()).data().expenseMinor, 215000);
});

test('a genuine balance adjustment cannot be reclassified by silently changing money', async () => {
  const {root, plan} = await fixture('real-adjustment');
  await root.collection('balanceAdjustments').doc('legacy-technical-repair').delete();
  const snapshot = await readAuditSnapshot(db, root.id);
  await assert.rejects(reconcileProjectionRepair(db, root.id, {
    ...plan, legacyAdjustmentId: 'real-opening-adjustment', expectedFingerprint: snapshot.fingerprint,
  }), /repair_balance_changed/);
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 105000);
  assert.equal((await root.collection('balanceAdjustments').doc('real-opening-adjustment').get()).exists, true);
});

test('after reconciliation, a budget income migrates and retries exactly once, including delayed old trigger events', async () => {
  const {root, plan, expense} = await fixture('resume');
  await reconcileProjectionRepair(db, root.id, plan);
  const budget = root.collection('budgets').doc('income-plan');
  await budget.set({flowType: 'income', categoryId: 'salary', currency: 'COP', monthKey: '2026-10', status: 'active'});
  await budget.collection('items').doc('income-item').set({status: 'active', actualAmountMinor: 0});
  const command = {
    action: 'create', requestId: 'queued-budget-income', idempotencyKey: 'queued-budget-income', expectedGeneration: 1,
    type: 'income', amountMinor: 10000, currency: 'COP', accountId: 'cash', categoryId: 'salary',
    budgetId: 'income-plan', budgetItemId: 'income-item', monthKey: '2026-10',
    occurredAt: '2026-10-28T15:00:00Z', description: '',
  };
  const result = await executeOperationCommand(db, root.id, command);
  assert.deepEqual(await executeOperationCommand(db, root.id, command), result);
  await applyOperationEvent(db, {userId: root.id, operationId: 'expense', eventId: 'late-legacy-event', current: expense});
  assert.equal((await root.get()).data().operationProjectionVersion, 1);
  assert.equal((await root.collection('operations').get()).size, 3);
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 115000);
  assert.equal((await budget.collection('items').doc('income-item').get()).data().actualAmountMinor, 10000);
  const summary = (await root.collection('monthlySummaries').doc('2026-10_COP').get()).data();
  assert.equal(summary.expenseMinor, 195000);
  assert.equal(summary.incomeMinor, 210000);
  const report = await auditProjections(db, root.id);
  assert.equal(report.complete, true);
  assert.deepEqual(report.differences, []);
});
