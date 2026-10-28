import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {Timestamp} from 'firebase-admin/firestore';
import {executeEmailImportCommand, importDigest, listEmailImportCandidates,
  parseImportDraft, stageEmailImportCandidate} from '../lib/email_imports.js';
import {applyOperationEvent} from '../lib/projection_store.js';
import {auditProjections} from '../lib/projection_audit.js';
import {app, db, seedUser, userDump} from './projection_test_support.mjs';

after(() => deleteApp(app));
const now = new Date('2026-10-22T20:00:00Z');
const draft = {type: 'expense', amountMinor: 1200, currency: 'COP',
  occurredAt: '2026-10-01T02:00:00.000Z', description: 'Synthetic merchant',
  accountId: 'bank', categoryId: 'food'};
const policy = (uid) => ({allowedUids: [uid], now: () => now});
async function fixture(name, options = {}) {
  const root = await seedUser(`email-import-${name}`);
  await root.update({timeZone: 'America/Bogota'});
  const id = await stageEmailImportCandidate(db, root.id, {
    mailboxKey: importDigest('synthetic-mailbox'), messageId: 'synthetic-message',
    bank: 'bancolombia', formatVersion: 'synthetic_v1', suggestion: draft,
    evidence: 'Synthetic evidence only', ...options,
  }, now);
  return {root, id, call: (changes = {}) => executeEmailImportCommand(db, root.id, {
    requestId: 'synthetic-command-1', expectedGeneration: 0, candidateId: id, action: 'approve',
    expectedVersion: 1, draft, ...changes,
  }, policy(root.id))};
}

test('pilot is deny-by-default, authenticated and isolated by UID', async () => {
  const {root, id} = await fixture('auth');
  const command = {requestId: 'synthetic-command-1', expectedGeneration: 0, candidateId: id, action: 'discard', expectedVersion: 1};
  await assert.rejects(executeEmailImportCommand(db, undefined, command, policy(root.id)), {status: 'unauthenticated'});
  await assert.rejects(executeEmailImportCommand(db, root.id, command, {allowedUids: []}), {issue: 'import-pilot-disabled'});
  await assert.rejects(executeEmailImportCommand(db, 'someone-else', command, policy('someone-else')), {issue: 'import-profile-missing'});
  await seedUser('someone-else');
  await assert.rejects(executeEmailImportCommand(db, 'someone-else', command, policy('someone-else')), {issue: 'import-candidate-missing'});
  await assert.rejects(listEmailImportCandidates(db, root.id, {}, {allowedUids: []}), {status: 'permission-denied'});
});

test('staging is non-financial and repeated ingestion preserves reviewed corrections', async () => {
  const {root, id, call} = await fixture('staging');
  assert.equal((await root.collection('operations').get()).size, 0);
  assert.equal((await root.collection('ledgerEntries').get()).size, 0);
  assert.equal((await root.collection('accounts').doc('bank').get()).data().currentBalanceMinor, 10000);
  await call({action: 'edit', draft: {...draft, description: 'Corrected'}});
  await stageEmailImportCandidate(db, root.id, {mailboxKey: importDigest('synthetic-mailbox'),
    messageId: 'synthetic-message', bank: 'bancolombia', formatVersion: 'synthetic_v2',
    suggestion: {}, evidence: 'Later message'}, now);
  const saved = (await root.collection('emailImportCandidates').doc(id).get()).data();
  assert.equal(saved.version, 2);
  assert.equal(saved.draft.description, 'Corrected');
  assert.equal((await root.collection('operations').get()).size, 0);
});

test('Gmail approval cannot use debt accounts through its generic operation path', async () => {
  const {root, call} = await fixture('debt-bypass');
  await root.collection('accounts').doc('bank').update({nature: 'debt', type: 'creditCard'});
  const before = await userDump(root);
  await assert.rejects(call(), {issue: 'import-account-incompatible'});
  assert.deepEqual(await userDump(root), before);
});

test('approval creates canonical entries once and existing trigger applies projections once', async () => {
  const {root, call} = await fixture('approve');
  const result = await call();
  assert.equal(result.status, 'approved');
  assert.deepEqual(await call(), result);
  assert.equal((await root.collection('operations').get()).size, 1);
  assert.equal((await root.collection('ledgerEntries').get()).size, 1);
  const operation = (await root.collection('operations').doc(result.operationId).get()).data();
  assert.equal(operation.monthKey, '2026-09'); // Profile date, not UTC/email date.
  assert.equal(operation.status, 'confirmed');
  assert.equal((await root.collection('accounts').doc('bank').get()).data().currentBalanceMinor, 10000);
  const event = {userId: root.id, operationId: result.operationId, eventId: 'synthetic-approval-event', current: operation};
  await applyOperationEvent(db, event);
  await applyOperationEvent(db, event);
  assert.equal((await root.collection('accounts').doc('bank').get()).data().currentBalanceMinor, 8800);
  assert.equal((await root.collection('operations').doc(result.operationId).collection('entries').get()).size, 1);
  const saved = (await root.collection('emailImportCandidates').doc(result.candidateId).get()).data();
  assert.equal(saved.evidence, undefined);
  assert.equal(saved.draft, undefined);
  const report = await auditProjections(db, root.id);
  assert.equal(report.complete, true);
  assert.deepEqual(report.differences, []);
});

test('concurrent approvals, even different request IDs, converge to one movement', async () => {
  const {root, call} = await fixture('concurrent');
  const results = await Promise.all(Array.from({length: 4}, (_, index) => call({requestId: `parallel-command-${index}`})));
  assert(results.every((row) => row.operationId === results[0].operationId));
  assert.equal((await root.collection('operations').get()).size, 1);
  assert.equal((await root.collection('ledgerEntries').get()).size, 1);
});

test('same request with changed content conflicts; stale drafts cannot overwrite edits', async () => {
  const {root, call} = await fixture('stale');
  await call({action: 'edit'});
  const saved = await userDump(root);
  await assert.rejects(call({action: 'edit', draft: {...draft, amountMinor: 20}}), {issue: 'import-request-conflict'});
  await assert.rejects(call({requestId: 'new-command-stale'}), {issue: 'import-candidate-stale'});
  assert.deepEqual(await userDump(root), saved);
});

test('invalid references, archived accounts, categories and amounts leave no partial writes', async () => {
  const {root, call} = await fixture('validation');
  for (const change of [
    {accountId: 'cash'}, {accountId: 'other-user-account'}, {currency: 'MXN'},
    {categoryId: 'salary'}, {categoryId: 'missing'}, {amountMinor: 0},
    {amountMinor: 1_000_000_001}, {amountMinor: 1.5}, {description: '<script>bad</script>'},
    {occurredAt: '2026-02-30T00:00:00Z'}, {occurredAt: '2026-10-23T00:00:00Z'},
    {sourceAccountId: 'bank'}, {budgetId: 'budget'},
  ]) {
    const before = await userDump(root);
    await assert.rejects(call({draft: {...draft, ...change}}));
    assert.deepEqual(await userDump(root), before);
  }
  await root.collection('categories').doc('food').update({isArchived: true});
  await assert.rejects(call(), {issue: 'import-category-incompatible'});
});

test('transfers require two compatible active accounts and produce paired entries', async () => {
  const {root, call} = await fixture('transfer');
  await root.collection('accounts').doc('second').set({currency: 'COP', status: 'active',
    currentBalanceMinor: 0, openingBalanceMinor: 0});
  const transfer = {type: 'transfer', amountMinor: 1200, currency: 'COP',
    occurredAt: draft.occurredAt, description: 'Synthetic transfer',
    sourceAccountId: 'bank', destinationAccountId: 'second'};
  await assert.rejects(call({draft: {...transfer, destinationAccountId: 'mxn'}}), {issue: 'import-account-incompatible'});
  await assert.rejects(call({draft: {...transfer, destinationAccountId: 'bank'}}), {issue: 'import-invalid-transfer'});
  const result = await call({draft: transfer});
  const entries = (await root.collection('ledgerEntries').get()).docs.map((doc) => doc.data().deltaMinor).sort((a, b) => a - b);
  assert.deepEqual(entries, [-1200, 1200]);
  const current = (await root.collection('operations').doc(result.operationId).get()).data();
  await applyOperationEvent(db, {userId: root.id, operationId: result.operationId, eventId: 'transfer-event', current});
  const summaries = await root.collection('monthlySummaries').get();
  assert.equal(summaries.docs[0].data().incomeMinor, 0);
  assert.equal(summaries.docs[0].data().expenseMinor, 0);
});

test('manual duplicates require individual acknowledgment; identical amounts are not auto-dropped', async () => {
  const {root, call} = await fixture('duplicates');
  await root.collection('operations').doc('manually-entered').set({...draft,
    occurredAt: Timestamp.fromDate(new Date(draft.occurredAt)), status: 'confirmed'});
  await assert.rejects(call(), {issue: 'import-duplicate-review-required'});
  assert.equal((await root.collection('emailImportCommands').get()).size, 0);
  const result = await call({duplicatesReviewed: true});
  assert.equal(result.status, 'approved');
  assert.equal((await root.collection('operations').get()).size, 2);
});

test('bank references prevent a second message from approving the same bank transaction', async () => {
  const {root, call} = await fixture('reference', {bankReferenceKey: importDigest('same-reference')});
  await call();
  const id = await stageEmailImportCandidate(db, root.id, {
    mailboxKey: importDigest('synthetic-mailbox'), messageId: 'another-message',
    bank: 'bancolombia', formatVersion: 'synthetic_v1', suggestion: draft,
    evidence: 'Synthetic', bankReferenceKey: importDigest('same-reference'),
  }, now);
  await assert.rejects(call({candidateId: id, requestId: 'another-command', duplicatesReviewed: true}),
    {issue: 'import-source-already-approved'});
  assert.equal((await root.collection('operations').get()).size, 1);
});

test('deleting the approved movement does not re-enable ingestion or approval', async () => {
  const {root, call} = await fixture('deleted');
  const result = await call();
  await root.collection('operations').doc(result.operationId).delete();
  const replay = await call({requestId: 'deleted-command-2'});
  assert.equal(replay.operationId, result.operationId);
  assert.equal((await root.collection('operations').get()).size, 0);
});

test('expired and discarded candidates cannot approve; discarding does not affect finance', async () => {
  const expired = await fixture('expired');
  await expired.root.collection('emailImportCandidates').doc(expired.id).update({expiresAt: Timestamp.fromMillis(now.getTime())});
  await assert.rejects(expired.call(), {issue: 'import-candidate-expired'});
  const {root, call} = await fixture('discard');
  const result = await call({action: 'discard', draft: undefined});
  assert.equal(result.status, 'discarded');
  await assert.rejects(call({requestId: 'discard-command-2'}), {issue: 'import-candidate-resolved'});
  assert.equal((await root.collection('operations').get()).size, 0);
});

test('server listing pages all candidates and never returns credentials, resolved or expired records', async () => {
  const {root, id} = await fixture('listing');
  const batch = db.batch();
  const template = (await root.collection('emailImportCandidates').doc(id).get()).data();
  for (let index = 0; index < 55; index++) batch.set(root.collection('emailImportCandidates').doc(`page_${String(index).padStart(3, '0')}`), template);
  batch.set(root.collection('emailImportCredentials').doc('gmail'), {token: 'NEVER EXPOSE'});
  batch.set(root.collection('emailImportCandidates').doc('resolved'), {...template, status: 'discarded'});
  batch.set(root.collection('emailImportCandidates').doc('expired'), {...template, expiresAt: Timestamp.fromMillis(0)});
  await batch.commit();
  const results = [];
  let cursor;
  do {
    const page = await listEmailImportCandidates(db, root.id, cursor ? {cursor} : {}, policy(root.id));
    results.push(...page.candidates);
    cursor = page.nextCursor;
  } while (cursor);
  assert.equal(results.length, 56);
  assert.equal(JSON.stringify(results).includes('NEVER EXPOSE'), false);
  assert.equal(JSON.stringify(results).includes('sourceKey'), false);
  await assert.rejects(listEmailImportCandidates(db, root.id, {cursor: '../../other'}, policy(root.id)));
});

test('strict ingestion refuses HTML, arbitrary suggestion values and invalid amounts', async () => {
  for (const suggestion of [{description: '<script>'}, {description: {secret: true}}, {amountMinor: 0}, {extra: 'x'}]) {
    await assert.rejects(stageEmailImportCandidate(db, 'synthetic', {
      mailboxKey: importDigest('x'), messageId: 'x', bank: 'davivienda',
      formatVersion: 'synthetic', suggestion, evidence: 'Synthetic',
    }));
  }
  assert.throws(() => parseImportDraft({...draft, currency: 'cop'}, now));
});
