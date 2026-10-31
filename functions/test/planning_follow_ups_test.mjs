import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {randomUUID} from 'node:crypto';
import {deleteApp} from 'firebase-admin/app';
import {Timestamp} from 'firebase-admin/firestore';
import {mutatePlanningFollowUp, planningSourceId} from '../lib/planning_follow_ups.js';
import {executeOperationCommand} from '../lib/operation_commands.js';
import {executeOperationBudgetAssociation} from '../lib/operation_budget_associations.js';
import {executeDebtCommitmentCommand} from '../lib/debt_commitments.js';
import {app, db, seedUser as seedBaseUser} from './projection_test_support.mjs';

after(() => deleteApp(app));
const runId = randomUUID();
const seedUser = (id) => seedBaseUser(`${id}-${runId}`);
const source = {kind: 'expense', budgetId: 'barber:budget', itemId: 'barber:item', monthKey: '2026-10'};
const command = (action, requestId, overrides = {}) => ({...source, action, requestId,
  expectedGeneration: 0, expectedVersion: 0, ...overrides});
const create = (requestId, amountMinor = 25000) => ({action: 'create', requestId, idempotencyKey: requestId,
  expectedGeneration: 0, type: 'expense', accountId: 'cash', categoryId: 'food', currency: 'COP',
  amountMinor, monthKey: '2026-10', occurredAt: '2026-10-15T15:00:00Z', description: 'QA Barber',
  budgetId: source.budgetId, budgetItemId: source.itemId});
async function seed(name, withExpense = true) {
  const root = await seedUser(`planning-${name}`);
  await root.update({timeZone: 'America/Bogota', dataGeneration: 0, operationProjectionVersion: 1});
  await root.collection('accounts').doc('cash').update({openingBalanceMinor: 100000, currentBalanceMinor: 100000});
  const budget = root.collection('budgets').doc(source.budgetId);
  await budget.set({categoryId: 'food', currency: 'COP', flowType: 'expense', monthKey: source.monthKey,
    status: 'active', dataGeneration: 0, plannedAmountMinor: 50000, itemCount: 1});
  await budget.collection('items').doc(source.itemId).set({description: 'QA Barber', amountMinor: 50000, actualAmountMinor: 0, dayOfMonth: 15, status: 'active'});
  if (withExpense) await executeOperationCommand(db, root.id, create('planning-expense-0001'));
  return root;
}
async function financialSnapshot(root) {
  const result = {};
  for (const name of ['accounts', 'operations', 'monthlySummaries', 'ledgerEntries', 'budgets']) {
    const docs = await root.collection(name).get();
    result[name] = Object.fromEntries(docs.docs.map(doc => [doc.id, doc.data()]));
  }
  result.items = (await root.collection('budgets').doc(source.budgetId).collection('items').get()).docs.map(doc => doc.data());
  return result;
}
const tracking = root => root.collection('planningFollowUps').doc(planningSourceId(source));

test('Barber expense can finish below plan, replay in another key order, dismiss, snooze and resume without financial writes', async () => {
  const root = await seed('barber');
  const before = await financialSnapshot(root);
  const input = command('completeExpense', 'planning-finish-0001');
  const first = await mutatePlanningFollowUp(db, root.id, input);
  assert.equal(first.entryId, 'budget:barber:budget:barber:item');
  assert.equal(first.state, 'completed');
  assert.equal((await tracking(root).get()).data().version, 1);
  assert.deepEqual(await mutatePlanningFollowUp(db, root.id, Object.fromEntries(Object.entries(input).reverse())), first);
  await assert.rejects(mutatePlanningFollowUp(db, root.id, {...input, action: 'dismiss'}), {issue: 'planning-request-conflict'});
  await mutatePlanningFollowUp(db, root.id, command('dismiss', 'planning-dismiss-0001', {expectedVersion: 1}));
  await mutatePlanningFollowUp(db, root.id, command('snooze', 'planning-snooze-0001', {expectedVersion: 2, remindOn: '2026-11-01'}), new Date('2026-10-31T15:00:00Z'));
  await mutatePlanningFollowUp(db, root.id, command('resume', 'planning-resume-0001', {expectedVersion: 3}));
  assert.deepEqual(await financialSnapshot(root), before);
});

test('completion requires an active confirmed expense; authentication, generation, versions and concurrent commands are checked', async () => {
  const root = await seed('validation', false);
  await assert.rejects(mutatePlanningFollowUp(db, undefined, command('dismiss', 'planning-invalid-0001')), {status: 'unauthenticated'});
  await assert.rejects(mutatePlanningFollowUp(db, root.id, command('completeExpense', 'planning-invalid-0002')), {issue: 'planning-expense-needs-record'});
  await assert.rejects(mutatePlanningFollowUp(db, root.id, command('dismiss', 'planning-invalid-0003', {expectedGeneration: 1})), {issue: 'planning-stale-generation'});
  const results = await Promise.allSettled(['planning-parallel-0001', 'planning-parallel-0002'].map(id => mutatePlanningFollowUp(db, root.id, command('dismiss', id))));
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  assert.equal(results.filter(result => result.status === 'rejected' && result.reason.issue === 'planning-state-changed').length, 1);
  assert.equal((await tracking(root).get()).data().version, 1);
  await assert.rejects(mutatePlanningFollowUp(db, 'planning-other-user', command('dismiss', 'planning-other-0001')), {issue: 'planning-profile-unavailable'});
});

test('generation 1 accepts missing generation only for budget records created after reset completion', async () => {
  const current = await seedUser('planning-generation-current');
  await current.update({dataGeneration: 1, resetStatus: 'ready', resetCompletedAt: Timestamp.fromDate(new Date(Date.now() - 60_000))});
  const currentBudget = current.collection('budgets').doc('legacy-current-budget');
  await currentBudget.set({categoryId: 'food', currency: 'COP', flowType: 'expense', monthKey: source.monthKey, status: 'active'});
  await currentBudget.collection('items').doc('legacy-current-item').set({description: 'QA current item', amountMinor: 50000, status: 'active'});
  const currentSource = {...source, budgetId: currentBudget.id, itemId: 'legacy-current-item'};
  const accepted = await mutatePlanningFollowUp(db, current.id, {...command('dismiss', 'planning-generation-current-001'), ...currentSource, expectedGeneration: 1});
  assert.equal(accepted.state, 'dismissed');
  assert.equal(accepted.dataGeneration, 1);

  const old = await seedUser('planning-generation-old');
  const oldBudget = old.collection('budgets').doc('legacy-old-budget');
  await oldBudget.set({categoryId: 'food', currency: 'COP', flowType: 'expense', monthKey: source.monthKey, status: 'active'});
  await oldBudget.collection('items').doc('legacy-old-item').set({description: 'QA old item', amountMinor: 50000, status: 'active'});
  await old.update({dataGeneration: 1, resetStatus: 'ready', resetCompletedAt: Timestamp.fromDate(new Date(Date.now() + 60_000))});
  const oldSource = {...source, budgetId: oldBudget.id, itemId: 'legacy-old-item'};
  await assert.rejects(
    mutatePlanningFollowUp(db, old.id, {...command('dismiss', 'planning-generation-old-001'), ...oldSource, expectedGeneration: 1}),
    {issue: 'planning-entry-unavailable'},
  );

  const stale = await seedUser('planning-generation-explicit-stale');
  await stale.update({dataGeneration: 1, resetStatus: 'ready', resetCompletedAt: Timestamp.fromDate(new Date(Date.now() - 60_000))});
  const staleBudget = stale.collection('budgets').doc('legacy-explicit-stale-budget');
  await staleBudget.set({categoryId: 'food', currency: 'COP', flowType: 'expense', monthKey: source.monthKey, status: 'active', dataGeneration: 0});
  await staleBudget.collection('items').doc('legacy-explicit-stale-item').set({description: 'QA stale item', amountMinor: 50000, status: 'active', dataGeneration: 0});
  const staleSource = {...source, budgetId: staleBudget.id, itemId: 'legacy-explicit-stale-item'};
  await assert.rejects(
    mutatePlanningFollowUp(db, stale.id, {...command('dismiss', 'planning-generation-explicit-001'), ...staleSource, expectedGeneration: 1}),
    {issue: 'planning-entry-unavailable'},
  );

  const ambiguous = await seedUser('planning-generation-ambiguous');
  await ambiguous.update({dataGeneration: 1, resetStatus: 'ready'});
  const ambiguousBudget = ambiguous.collection('budgets').doc('legacy-ambiguous-budget');
  await ambiguousBudget.set({categoryId: 'food', currency: 'COP', flowType: 'expense', monthKey: source.monthKey, status: 'active'});
  await ambiguousBudget.collection('items').doc('legacy-ambiguous-item').set({description: 'QA ambiguous item', amountMinor: 50000, status: 'active'});
  const ambiguousSource = {...source, budgetId: ambiguousBudget.id, itemId: 'legacy-ambiguous-item'};
  await assert.rejects(
    mutatePlanningFollowUp(db, ambiguous.id, {...command('dismiss', 'planning-generation-ambiguous-001'), ...ambiguousSource, expectedGeneration: 1}),
    {issue: 'planning-entry-unavailable'},
  );
});

test('canceling or unlinking the last expense reopens atomically; multiple records and amount corrections preserve completion', async () => {
  const root = await seed('reopen');
  await executeOperationCommand(db, root.id, create('planning-expense-0002', 10000));
  await mutatePlanningFollowUp(db, root.id, command('completeExpense', 'planning-close-0001'));
  await executeOperationCommand(db, root.id, {action: 'correct', requestId: 'planning-edit-0001', expectedGeneration: 0,
    expectedRevision: 0, operationId: 'planning-expense-0001', amountMinor: 20000, currency: 'COP', accountId: 'cash',
    categoryId: 'food', monthKey: '2026-10', occurredAt: '2026-10-15T15:00:00Z', description: 'QA corrected'});
  assert.equal((await tracking(root).get()).data().state, 'completed');
  await executeOperationCommand(db, root.id, {action: 'cancel', operationId: 'planning-expense-0001', expectedGeneration: 0});
  assert.equal((await tracking(root).get()).data().state, 'completed');
  await executeOperationBudgetAssociation(db, root.id, {action: 'setOperationBudgetItem', requestId: 'planning-unlink-0001', expectedGeneration: 0,
    expectedRevision: 0, operationId: 'planning-expense-0002', budgetId: null, itemId: null});
  const reopened = (await tracking(root).get()).data();
  assert.equal(reopened.state, 'open'); assert.equal(reopened.reason, 'record-changed'); assert.equal(reopened.version, 2);
  await assert.rejects(mutatePlanningFollowUp(db, root.id, command('completeExpense', 'planning-close-0002', {expectedVersion: 2})), {issue: 'planning-expense-needs-record'});
});

test('snooze uses calendar days in the profile zone across months and leap years', async () => {
  const root = await seed('calendar');
  const now = new Date('2028-03-01T02:00:00Z'); // Still Feb 29 in Bogota.
  for (const [index, remindOn] of ['2028-02-29', '2028-02-30', '2028-03-29'].entries()) {
    await assert.rejects(mutatePlanningFollowUp(db, root.id, command('snooze', `planning-date-bad-${index}`, {remindOn}), now), {issue: 'planning-snooze-out-of-range'});
  }
  const result = await mutatePlanningFollowUp(db, root.id, command('snooze', 'planning-date-valid', {remindOn: '2028-03-28'}), now);
  assert.equal(result.remindOn, '2028-03-28');
});

test('debt follow-up resolves historical terms, rejects skipped or paused months and never marks a debt paid', async () => {
  const root = await seed('debt');
  const ref = root.collection('debtCommitments').doc('vehicle');
  const plan = {status: 'active', dataGeneration: 0, version: 2, firstDueMonth: '2026-01', lastDueMonth: '2026-09',
    amountMinor: 2000, dueDay: 10, debtAccountId: 'vehicle', currency: 'COP'};
  await ref.set(plan);
  await ref.collection('versions').doc('1').set({...plan, version: 1, lastDueMonth: null, effectiveFromMonth: '2026-01'});
  await ref.collection('versions').doc('2').set({...plan, version: 2, effectiveFromMonth: '2026-12'});
  const debt = {kind: 'debt', commitmentId: 'vehicle', monthKey: '2026-10', expectedGeneration: 0, expectedVersion: 0};
  const before = await financialSnapshot(root);
  await mutatePlanningFollowUp(db, root.id, {...debt, action: 'dismiss', requestId: 'planning-debt-dismiss'});
  await assert.rejects(mutatePlanningFollowUp(db, root.id, {...debt, action: 'completeExpense', requestId: 'planning-debt-complete'}), {issue: 'planning-invalid-source'});
  await ref.update({skippedMonths: ['2026-11']});
  await assert.rejects(mutatePlanningFollowUp(db, root.id, {...debt, monthKey: '2026-11', action: 'dismiss', requestId: 'planning-debt-skipped'}), {issue: 'planning-entry-unavailable'});
  await ref.update({pauseRanges: [{fromMonth: '2026-10', untilMonth: '2026-11'}]});
  await assert.rejects(mutatePlanningFollowUp(db, root.id, {...debt, action: 'resume', expectedVersion: 1, requestId: 'planning-debt-paused'}), {issue: 'planning-entry-unavailable'});
  assert.deepEqual(await financialSnapshot(root), before);
});

test('structured identities do not alias when source IDs contain separators', () => {
  assert.notEqual(planningSourceId({...source, budgetId: 'a:b', itemId: 'c'}), planningSourceId({...source, budgetId: 'a', itemId: 'b:c'}));
});

test('one-installment edits preserve future terms and subsequent edits preserve prior months', async () => {
  const root = await seed('edit-scope');
  await root.collection('accounts').doc('vehicle').set({nature: 'debt', currency: 'COP', status: 'active'});
  const ref = root.collection('debtCommitments').doc('vehicle');
  const plan = {status: 'active', dataGeneration: 0, version: 1, firstDueMonth: '2026-01', lastDueMonth: null,
    amountMinor: 2400000, dueDay: 31, debtAccountId: 'vehicle', currency: 'COP', remindersEnabled: false};
  await ref.set(plan);
  await ref.collection('versions').doc('1').set({...plan, effectiveFromMonth: '2026-01'});
  const single = {action: 'editOccurrence', requestId: 'planning-edit-single-001', expectedGeneration: 0,
    commitmentId: 'vehicle', monthKey: '2026-10', amountMinor: 1200000, dueDay: 20};
  const result = await executeDebtCommitmentCommand(db, root.id, single);
  assert.deepEqual(await executeDebtCommitmentCommand(db, root.id, single), result);
  assert.equal((await ref.get()).data().amountMinor, 2400000);
  assert.equal((await ref.collection('occurrences').doc('vehicle_2026-10').get()).data().terms.amountMinor, 1200000);
  await executeDebtCommitmentCommand(db, root.id, {action: 'edit', requestId: 'planning-edit-future-001', expectedGeneration: 0,
    commitmentId: 'vehicle', effectiveFromMonth: '2026-11', amountMinor: 3000000, dueDay: 25});
  assert.equal((await ref.collection('versions').doc('1').get()).data().amountMinor, 2400000);
  assert.equal((await ref.collection('occurrences').doc('vehicle_2026-10').get()).data().terms.amountMinor, 1200000);
  assert.equal((await ref.get()).data().amountMinor, 3000000);
});

test('a reversed original expense cannot justify completion', async () => {
  const root = await seed('reversed', false);
  const record = {...create('planning-original'), status: 'confirmed', dataGeneration: 0, projectionDirection: 1};
  await root.collection('operations').doc('planning-original').set(record);
  await root.collection('operations').doc('planning-reversal').set({...record, projectionDirection: -1, reversalOf: 'planning-original'});
  await assert.rejects(mutatePlanningFollowUp(db, root.id, command('completeExpense', 'planning-reversed-001')), {issue: 'planning-expense-needs-record'});
});
