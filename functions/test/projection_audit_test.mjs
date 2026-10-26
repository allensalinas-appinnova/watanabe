import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {spawn} from 'node:child_process';
import {readFileSync, unlinkSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {auditExitCode, auditProjections, readAuditSnapshot} from '../lib/projection_audit.js';
import {applyOperationEvent} from '../lib/projection_store.js';
import {app, db, operation, seedUser, userDump} from './projection_test_support.mjs';

after(() => deleteApp(app));
async function add(root, id, value) {
  await root.collection('operations').doc(id).set({...value, description: 'PRIVATE OPERATION NOTE'});
  await applyOperationEvent(db, {userId: root.id, eventId: id, current: value});
}
const cli = (args) => new Promise((resolve, reject) => {
  const child = spawn(process.execPath, [fileURLToPath(new URL('../lib/audit_projections.js', import.meta.url)), ...args], {env: process.env});
  let stdout = '', stderr = '';
  child.stdout.on('data', (chunk) => { stdout += chunk; });
  child.stderr.on('data', (chunk) => { stderr += chunk; });
  child.on('error', reject);
  child.on('close', (code) => resolve({code, stdout, stderr}));
});

test('audit reconstructs opening balances, archived linked items, separate currencies and transfer totals without writes', async () => {
  const root = await seedUser('audit-correct');
  await add(root, 'linked', operation({budgetId: 'budget', budgetItemId: 'item'}));
  await add(root, 'income', operation({type: 'income', categoryId: 'salary', amountMinor: 200, currency: 'MXN', accountId: 'mxn'}));
  await add(root, 'brl', operation({amountMinor: 300, currency: 'BRL', accountId: 'brl'}));
  await add(root, 'transfer', operation({type: 'transfer', amountMinor: 900000000, sourceAccountId: 'cash', destinationAccountId: 'bank'}));
  await add(root, 'pending', operation({status: 'pending'}));
  await add(root, 'rejected', operation({status: 'rejected'}));
  const before = await userDump(root);
  const report = await auditProjections(db, root.id);
  assert.equal(report.complete, true);
  assert.deepEqual(report.differences, []);
  assert.equal(report.counts.confirmed, 4);
  assert.equal(auditExitCode(report), 0);
  assert.deepEqual(await userDump(root), before);
  assert.doesNotMatch(JSON.stringify(report), /PRIVATE/);
});

test('audit incorporates immutable balance-adjustment deltas without counting them as income or expense', async () => {
  const root = await seedUser('audit-adjustments');
  await add(root, 'expense', operation({accountId: 'bank', amountMinor: 1200}));
  await root.collection('accounts').doc('bank').update({currentBalanceMinor: 7000});
  await root.collection('balanceAdjustments').doc('adjust-command-123').set({
    adjustedAt: new Date(),
    adjustments: [{accountId: 'bank', currency: 'COP', previousBalanceMinor: 8800, targetBalanceMinor: 7000, deltaMinor: -1800}],
  });
  const summary = (await root.collection('monthlySummaries').doc('2026-10_COP').get()).data();
  assert.equal(summary.expenseMinor, 1200);
  const report = await auditProjections(db, root.id);
  assert.equal(report.complete, true);
  assert.deepEqual(report.differences, []);
  await root.collection('balanceAdjustments').doc('adjust-command-123').update({
    adjustments: [{accountId: 'bank', currency: 'COP', previousBalanceMinor: 8800, targetBalanceMinor: 7000, deltaMinor: -1000}],
  });
  const drift = await auditProjections(db, root.id);
  assert.equal(drift.complete, false);
  assert.ok(drift.issues.some((item) => item.code === 'invalid_adjustment_amount'));
});

test('audit reports corrupted balances, missing summaries and excess values on items without activity', async () => {
  const root = await seedUser('audit-drift');
  await add(root, 'expense', operation());
  await root.collection('accounts').doc('cash').update({currentBalanceMinor: 999});
  await root.collection('monthlySummaries').doc('2026-10_COP').delete();
  await root.collection('budgets').doc('budget').collection('items').doc('item').update({actualAmountMinor: 30});
  const before = await userDump(root);
  const report = await auditProjections(db, root.id);
  assert.equal(report.complete, true, JSON.stringify(report.issues));
  assert.equal(auditExitCode(report), 2);
  assert.ok(report.differences.some((d) => d.document === 'accounts/cash' && d.expected === 3800 && d.actual === 999));
  assert.ok(report.differences.some((d) => d.document === 'monthlySummaries/2026-10_COP' && d.field === 'document'));
  assert.ok(report.differences.some((d) => d.field === 'actualAmountMinor' && d.expected === 0 && d.actual === 30));
  assert.deepEqual(await userDump(root), before);
});

test('unreferenced monthly summaries retain zero expectations and all category residue is diagnosed', async () => {
  const root = await seedUser('audit-residue');
  await root.collection('monthlySummaries').doc('2026-09_COP').set({
    monthKey: '2026-09', currency: 'COP', incomeMinor: 100, expenseMinor: 0,
    transferInMinor: 0, transferOutMinor: 0, byCategory: {salary: 100, food: 0},
  });
  const report = await auditProjections(db, root.id);
  assert.equal(auditExitCode(report), 2);
  assert.equal(report.differences.length, 2);
  assert.ok(report.differences.some((d) => d.field === 'byCategory.salary' && d.expected === 0));
});

test('invalid canonical data and foreign or incompatible references yield incomplete sanitized diagnostics', async () => {
  const root = await seedUser('audit-invalid');
  for (const [id, overrides] of [
    ['account', {accountId: 'other-users-account'}],
    ['currency', {accountId: 'mxn'}],
    ['category', {categoryId: 'missing'}],
    ['budget', {budgetId: 'missing-budget', budgetItemId: 'item'}],
    ['partial', {budgetId: 'budget'}],
    ['mismatch', {budgetId: 'budget', budgetItemId: 'item', categoryId: 'travel'}],
    ['amount', {amountMinor: Number.MAX_SAFE_INTEGER + 1}],
  ]) await root.collection('operations').doc(id).set(operation(overrides));
  const before = await userDump(root);
  const report = await auditProjections(db, root.id);
  assert.equal(report.complete, false);
  assert.equal(auditExitCode(report), 1);
  assert.equal(report.issues.length, 7);
  assert.deepEqual(await userDump(root), before);
  assert.doesNotMatch(JSON.stringify(report), /PRIVATE/);
});

test('500-record cursors include all operations and items across page boundaries', async () => {
  const root = await seedUser('audit-pages');
  const batch = db.batch();
  for (let index = 0; index < 500; index++) batch.set(root.collection('operations').doc(`income-${String(index).padStart(3, '0')}`),
    operation({type: 'income', categoryId: 'salary', amountMinor: 1}));
  await batch.commit();
  await root.collection('operations').doc('last-page').set(operation({type: 'income', categoryId: 'salary', amountMinor: 200}));
  await root.collection('accounts').doc('cash').update({currentBalanceMinor: 5700});
  await root.collection('monthlySummaries').doc('2026-10_COP').set({
    monthKey: '2026-10', currency: 'COP', incomeMinor: 700, expenseMinor: 0,
    transferInMinor: 0, transferOutMinor: 0, byCategory: {salary: 700},
  });
  const itemBatch = db.batch();
  for (let index = 0; index < 500; index++) itemBatch.set(root.collection('budgets').doc('budget').collection('items').doc(`extra-${index}`), {});
  await itemBatch.commit();
  const before = await readAuditSnapshot(db, root.id);
  const report = await auditProjections(db, root.id);
  assert.equal(report.counts.operations, 501);
  assert.equal(report.counts.items, 501);
  assert.equal(auditExitCode(report), 0);
  assert.equal((await readAuditSnapshot(db, root.id)).fingerprint, before.fingerprint);
});

test('concurrent updates between snapshot passes force an incomplete result', async () => {
  const root = await seedUser('audit-concurrent');
  let calls = 0;
  const reader = async (database, userId) => {
    if (++calls === 2) await root.collection('accounts').doc('cash').update({currentBalanceMinor: 1});
    return readAuditSnapshot(database, userId);
  };
  const report = await auditProjections(db, root.id, reader);
  assert.equal(auditExitCode(report), 1);
  assert.ok(report.issues.some((issue) => issue.code === 'concurrent_change_detected'));
});

test('unsafe accumulated amounts mark the report incomplete without losing integer precision', async () => {
  const root = await seedUser('audit-overflow');
  const snapshot = await readAuditSnapshot(db, root.id);
  // Valid individual amounts can overflow when accumulated over a large history.
  const count = Math.floor(Number.MAX_SAFE_INTEGER / 100000000000) + 1;
  snapshot.operations = new Map(Array.from({length: count}, (_, index) => [String(index), operation({
    type: 'income', categoryId: 'salary', accountId: 'mxn', currency: 'MXN', amountMinor: 100000000000,
  })]));
  const {compareProjections} = await import('../lib/projection_audit.js');
  const report = compareProjections(snapshot);
  assert.equal(report.complete, false);
  assert.ok(report.issues.some((issue) => issue.code === 'invalid_integer'));
});

test('malformed projection values are sanitized and mark diagnosis incomplete', async () => {
  const root = await seedUser('audit-invalid-projection');
  await root.collection('accounts').doc('cash').update({currentBalanceMinor: 'PRIVATE BAD VALUE'});
  const before = await userDump(root);
  const report = await auditProjections(db, root.id);
  assert.equal(auditExitCode(report), 1);
  assert.ok(report.issues.some((issue) => issue.code === 'invalid_projection_value'));
  assert.equal(report.differences[0].actual, '<invalid>');
  assert.doesNotMatch(JSON.stringify(report), /PRIVATE/);
  assert.deepEqual(await userDump(root), before);
});

test('CLI requires explicit project/user, limits output paths, reports exit codes and keeps details private', async () => {
  const root = await seedUser('audit-cli');
  for (const args of [[], ['--project', 'demo-clearbudget'], ['--project', 'lumiomoney', '--user', root.id],
    ['--project', 'demo-clearbudget', '--user', '../other'], ['--project', 'demo-clearbudget', '--user', root.id, '--output', '../../report.json'],
    ['--project', 'demo-clearbudget', '--user', root.id, '--apply']]) {
    assert.equal((await cli(args)).code, 1);
  }
  let result = await cli(['--project', 'demo-clearbudget', '--user', root.id]);
  assert.equal(result.code, 0);
  assert.doesNotMatch(result.stdout + result.stderr, /PRIVATE|cash|audit-cli|5000/);
  await root.collection('accounts').doc('cash').update({currentBalanceMinor: 1});
  const file = `test-audit-${process.pid}.json`;
  const reportUrl = new URL(`../../.local/projection-audits/${file}`, import.meta.url);
  const before = await userDump(root);
  try {
    result = await cli(['--project', 'demo-clearbudget', '--user', root.id, '--output', file]);
    assert.equal(result.code, 2);
    const report = JSON.parse(readFileSync(reportUrl, 'utf8'));
    assert.equal(report.differences[0].expected, 5000);
    assert.doesNotMatch(JSON.stringify(report), /PRIVATE/);
    assert.equal((await cli(['--project', 'demo-clearbudget', '--user', root.id, '--output', file])).code, 1, 'existing report is not overwritten');
    assert.deepEqual(await userDump(root), before);
  } finally { unlinkSync(reportUrl); }
  await root.collection('operations').doc('invalid').set(operation({accountId: 'missing'}));
  assert.equal((await cli(['--project', 'demo-clearbudget', '--user', root.id])).code, 1);
});
