import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {executeDebtCommand} from '../lib/debt_commands.js';
import {executeBalanceAdjustment} from '../lib/balance_adjustments.js';
import {applyOperationEvent} from '../lib/projection_store.js';
import {auditProjections} from '../lib/projection_audit.js';
import {app, db, seedUser, userDump} from './projection_test_support.mjs';

after(() => deleteApp(app));
const date = '2026-01-01T12:00:00Z';
const execute = (root, command) => executeDebtCommand(db, root.id, {
  expectedGeneration: 0,
  ...command,
}, {enabled: true});
const create = (overrides = {}) => ({requestId: 'create_debt_001', action: 'create', name: 'Synthetic', product: 'creditCard', currency: 'COP', referenceAt: date, debtMinor: 0, mode: 'existing', ...overrides});
const command = (accountId, requestId, action, extra = {}) => ({requestId, action, accountId, occurredAt: date, ...extra});
async function seed(id) {
  const root = await seedUser(`debt-${id}`);
  await root.update({timeZone: 'America/Bogota'});
  return root;
}
const account = async (root, id) => (await root.collection('accounts').doc(id).get()).data();
const summary = async (root) => (await root.collection('monthlySummaries').doc('2026-01_COP').get()).data();
async function cleanAudit(root) {
  const audit = await auditProjections(db, root.id);
  assert.equal(audit.complete, true, JSON.stringify(audit.issues));
  assert.deepEqual(audit.differences, []);
}

test('authentication and disabled activation fail before writing', async () => {
  const root = await seed('disabled');
  const before = await userDump(root);
  await assert.rejects(executeDebtCommand(db, undefined, create(), {enabled: true}), {issue: 'debt-session-expired'});
  await assert.rejects(executeDebtCommand(db, root.id, create()), {issue: 'debt-feature-disabled'});
  assert.deepEqual(await userDump(root), before);
});

test('card purchase, payment, partial refunds, credit balance and duplicate trigger delivery', async () => {
  const root = await seed('card');
  const result = await execute(root, create({limitMinor: 1000}));
  const id = result.accountId;
  const purchase = command(id, 'purchase_0001', 'purchase', {amountMinor: 1200, categoryId: 'food'});
  const bought = await execute(root, purchase);
  assert.equal(bought.overLimit, true);
  assert.equal((await account(root, id)).currentBalanceMinor, -1200);
  assert.equal((await summary(root)).expenseMinor, 1200);
  const op = (await root.collection('operations').doc(bought.operationIds[0]).get()).data();
  const once = await userDump(root);
  await Promise.all([execute(root, purchase), execute(root, purchase), applyOperationEvent(db, {userId: root.id, eventId: 'trigger_one', current: op})]);
  assert.deepEqual(await userDump(root), once);
  await execute(root, command(id, 'payment_0001', 'pay', {amountMinor: 1200, bankAccountId: 'bank'}));
  assert.equal((await account(root, 'bank')).currentBalanceMinor, 8800);
  assert.equal((await account(root, id)).currentBalanceMinor, 0);
  await execute(root, command(id, 'refund_00001', 'refund', {amountMinor: 500, originalOperationId: bought.operationIds[0]}));
  assert.equal((await account(root, id)).currentBalanceMinor, 500);
  assert.equal((await summary(root)).expenseMinor, 700);
  await assert.rejects(execute(root, command(id, 'refund_00002', 'refund', {amountMinor: 701, originalOperationId: bought.operationIds[0]})), {issue: 'debt-refund-exceeds-purchase'});
  await execute(root, command(id, 'refund_00003', 'refund', {amountMinor: 700, originalOperationId: bought.operationIds[0]}));
  assert.equal((await summary(root)).expenseMinor, 0);
  await cleanAudit(root);
});

test('existing loans do not create income; installments recognize new charges once', async () => {
  const root = await seed('loan');
  const {accountId: id} = await execute(root, create({product: 'bankLoan', debtMinor: undefined, principalMinor: 1000, chargesMinor: 100}));
  assert.equal((await account(root, 'bank')).currentBalanceMinor, 10000);
  const paid = await execute(root, command(id, 'loan_payment1', 'pay', {amountMinor: 450, bankAccountId: 'bank', principalMinor: 300, previousChargesMinor: 100, newChargesMinor: 50, categoryId: 'food'}));
  assert.equal(paid.operationIds.length, 2);
  assert.equal((await account(root, id)).principalMinor, 700);
  assert.equal((await account(root, id)).chargesMinor, 0);
  assert.equal((await account(root, id)).currentBalanceMinor, -700);
  assert.equal((await account(root, 'bank')).currentBalanceMinor, 9550);
  assert.equal((await summary(root)).expenseMinor, 50);
  assert.equal((await summary(root)).incomeMinor, 0);
  await execute(root, command(id, 'new_charge01', 'charge', {amountMinor: 100, categoryId: 'food'}));
  await execute(root, command(id, 'loan_payment2', 'pay', {amountMinor: 100, bankAccountId: 'bank', principalMinor: 0, previousChargesMinor: 100, newChargesMinor: 0}));
  assert.equal((await summary(root)).expenseMinor, 150);
  await cleanAudit(root);
});

test('receiving a new loan atomically creates bank and debt projections without income', async () => {
  const root = await seed('received');
  const {accountId: id} = await execute(root, create({product: 'personalLoan', debtMinor: undefined, principalMinor: 2000, chargesMinor: 0, mode: 'received', bankAccountId: 'bank'}));
  assert.equal((await account(root, id)).openingBalanceMinor, 0);
  assert.equal((await account(root, id)).currentBalanceMinor, -2000);
  assert.equal((await account(root, 'bank')).currentBalanceMinor, 12000);
  assert.equal((await summary(root)).incomeMinor, 0);
  await cleanAudit(root);
});

test('missing split, overpayment of capital, account isolation and reused IDs rollback everything', async () => {
  const root = await seed('atomic');
  const {accountId: id} = await execute(root, create({product: 'bankLoan', debtMinor: undefined, principalMinor: 100, chargesMinor: 0}));
  const before = await userDump(root);
  for (const extra of [
    {amountMinor: 100, principalMinor: 100},
    {amountMinor: 101, principalMinor: 101, previousChargesMinor: 0, newChargesMinor: 0},
    {amountMinor: 100, principalMinor: 100, previousChargesMinor: 0, newChargesMinor: 0, bankAccountId: 'mxn'},
    {amountMinor: 100, principalMinor: 100, previousChargesMinor: 0, newChargesMinor: 0, bankAccountId: 'foreign'},
  ]) await assert.rejects(execute(root, command(id, 'invalid_pay01', 'pay', {bankAccountId: 'bank', ...extra})));
  await assert.rejects(execute(root, create({name: 'Changed'})), {issue: 'debt-request-conflict'});
  assert.deepEqual(await userDump(root), before);
});

test('concurrent payments and corrections serialize; immutable reversal history reconstructs', async () => {
  const root = await seed('correction');
  const {accountId: id} = await execute(root, create());
  const purchase = command(id, 'purchase_0001', 'purchase', {amountMinor: 100, categoryId: 'food'});
  await execute(root, purchase);
  await execute(root, {requestId: 'correct_00001', accountId: id, action: 'correct', originalRequestId: purchase.requestId, replacement: {action: 'purchase', occurredAt: date, amountMinor: 200, categoryId: 'food'}});
  await execute(root, {requestId: 'correct_00002', accountId: id, action: 'correct', originalRequestId: 'correct_00001', replacement: {action: 'purchase', occurredAt: date, amountMinor: 200, categoryId: 'food'}});
  assert.equal((await account(root, id)).currentBalanceMinor, -200);
  assert.equal((await summary(root)).expenseMinor, 200);
  await assert.rejects(execute(root, {requestId: 'reverse_00002', accountId: id, action: 'reverse', originalRequestId: purchase.requestId}), {issue: 'debt-already-reversed'});
  await Promise.all([1, 2].map((n) => execute(root, command(id, `concurrent_0${n}`, 'pay', {amountMinor: 50, bankAccountId: 'bank'}))));
  assert.equal((await account(root, id)).currentBalanceMinor, -100);
  await cleanAudit(root);
});

test('refunding, correcting the refund, and voiding it maintain the cumulative refundable limit', async () => {
  const root = await seed('refund-correction');
  const {accountId: id} = await execute(root, create());
  const bought = await execute(root, command(id, 'purchase_0001', 'purchase', {amountMinor: 1000, categoryId: 'food'}));
  await execute(root, command(id, 'refund_00001', 'refund', {amountMinor: 300, originalOperationId: bought.operationIds[0]}));
  await execute(root, {requestId: 'correct_refund1', action: 'correct', accountId: id, originalRequestId: 'refund_00001', replacement: {action: 'refund', occurredAt: date, amountMinor: 200, originalOperationId: bought.operationIds[0]}});
  assert.equal((await summary(root)).expenseMinor, 800);
  await execute(root, {requestId: 'reverse_refund1', action: 'reverse', accountId: id, originalRequestId: 'correct_refund1'});
  assert.equal((await summary(root)).expenseMinor, 1000);
  await execute(root, {requestId: 'reverse_purchase1', action: 'reverse', accountId: id, originalRequestId: 'purchase_0001'});
  assert.equal((await account(root, id)).currentBalanceMinor, 0);
  await cleanAudit(root);
});

test('correcting a reconciliation targets the balance after reversal, not the old cache', async () => {
  const root = await seed('adjust-correction');
  const {accountId: id} = await execute(root, create());
  await execute(root, command(id, 'adjust_00001', 'adjust', {targetDebtMinor: 200}));
  await execute(root, {requestId: 'correct_adjust1', action: 'correct', accountId: id, originalRequestId: 'adjust_00001', replacement: {action: 'adjust', occurredAt: date, targetDebtMinor: 300}});
  assert.equal((await account(root, id)).currentBalanceMinor, -300);
  await cleanAudit(root);
});

test('projection corruption rolls back every source row and receipt; retry recovers', async () => {
  const root = await seed('rollback');
  const {accountId: id} = await execute(root, create());
  const ref = root.collection('monthlySummaries').doc('2026-01_COP');
  await ref.set({incomeMinor: 'invalid', expenseMinor: 0});
  const before = await userDump(root);
  const purchase = command(id, 'purchase_0001', 'purchase', {amountMinor: 100, categoryId: 'food'});
  await assert.rejects(execute(root, purchase));
  assert.deepEqual(await userDump(root), before);
  await ref.set({monthKey: '2026-01', currency: 'COP', incomeMinor: 0, expenseMinor: 0, transferInMinor: 0, transferOutMinor: 0});
  await execute(root, purchase);
  await cleanAudit(root);
});

test('an asynchronous money operation and a synchronous loan payment serialize on their common bank', async () => {
  const root = await seed('legacy-concurrency');
  const {accountId: id} = await execute(root, create({product: 'bankLoan', debtMinor: undefined, principalMinor: 1000, chargesMinor: 0}));
  const legacy = {type: 'expense', accountId: 'bank', categoryId: 'food', amountMinor: 100, currency: 'COP', monthKey: '2026-01', status: 'confirmed'};
  await root.collection('operations').doc('legacy_money').set(legacy);
  await Promise.all([
    applyOperationEvent(db, {userId: root.id, eventId: 'legacy_money_event', current: legacy}),
    execute(root, command(id, 'loan_payment1', 'pay', {amountMinor: 200, bankAccountId: 'bank', principalMinor: 200, previousChargesMinor: 0, newChargesMinor: 0})),
  ]);
  assert.equal((await account(root, 'bank')).currentBalanceMinor, 9700);
  await cleanAudit(root);
});

test('debt reconciliation, initial-date bounds, archive and generic adjustment bypass', async () => {
  const root = await seed('adjust');
  const {accountId: id} = await execute(root, create());
  await execute(root, command(id, 'adjust_00001', 'adjust', {targetDebtMinor: 200}));
  assert.equal((await account(root, id)).currentBalanceMinor, -200);
  assert.equal(await summary(root), undefined);
  await assert.rejects(execute(root, command(id, 'old_purchase1', 'purchase', {occurredAt: '2025-12-01T00:00:00Z', amountMinor: 100, categoryId: 'food'})), {issue: 'debt-before-opening'});
  await assert.rejects(execute(root, {requestId: 'archive_0001', action: 'archive', accountId: id}), {issue: 'debt-balance-not-zero'});
  await assert.rejects(executeBalanceAdjustment(db, root.id, {requestId: 'generic_0001', expectedGeneration: 0, adjustments: [{accountId: id, currency: 'COP', targetBalanceMinor: 0}]}), {issue: 'balance-adjustment-debt-command-required'});
  await execute(root, command(id, 'adjust_00002', 'adjust', {targetDebtMinor: 0}));
  await execute(root, {requestId: 'archive_0001', action: 'archive', accountId: id});
  await cleanAudit(root);
});

test('refunds retain archived same-month budget references but never rewrite prior months', async () => {
  const root = await seed('budget-refund');
  const budget = root.collection('budgets').doc('budget');
  await budget.update({status: 'active', monthKey: '2026-01'});
  await budget.collection('items').doc('item').update({status: 'active'});
  const {accountId: id} = await execute(root, create());
  const bought = await execute(root, command(id, 'purchase_0001', 'purchase', {amountMinor: 1000, categoryId: 'food', budgetId: 'budget', budgetItemId: 'item'}));
  await budget.update({status: 'archived'});
  await budget.collection('items').doc('item').update({status: 'archived'});
  await execute(root, command(id, 'refund_00001', 'refund', {amountMinor: 300, originalOperationId: bought.operationIds[0]}));
  await execute(root, command(id, 'refund_00002', 'refund', {occurredAt: '2026-02-01T12:00:00Z', amountMinor: 700, originalOperationId: bought.operationIds[0]}));
  assert.equal((await budget.collection('items').doc('item').get()).data().actualAmountMinor, 700);
  assert.equal((await summary(root)).expenseMinor, 700);
  assert.equal((await root.collection('monthlySummaries').doc('2026-02_COP').get()).data().expenseMinor, -700);
  await cleanAudit(root);
});
