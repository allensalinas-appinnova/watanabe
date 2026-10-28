import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test, {after, before, beforeEach} from 'node:test';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {Timestamp, deleteField, serverTimestamp, setLogLevel} from 'firebase/firestore';

setLogLevel('silent');

const rules = readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8');
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-clearbudget',
    firestore: {host: '127.0.0.1', port: 59180, rules},
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

const userProfile = () => ({
  locale: 'es',
  countryCode: 'CO',
  timeZone: 'America/Bogota',
  defaultCurrency: 'COP',
  onboardingStatus: 'complete',
  categoryCatalogVersion: 1,
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now(),
});

test('debt accounts and command-owned operations reject every client write and alternate path', async () => {
  const opening = {name: 'Synthetic', type: 'creditCard', nature: 'debt', currency: 'COP', openingBalanceMinor: 0, currentBalanceMinor: 0, includeInDashboard: true, status: 'active', createdAt: Timestamp.now(), updatedAt: Timestamp.now()};
  const operation = {type: 'expense', accountId: 'card', categoryId: 'food', currency: 'COP', amountMinor: 100, monthKey: '2026-01', occurredAt: Timestamp.now(), description: '', status: 'confirmed', idempotencyKey: 'debt_test_01', createdAt: Timestamp.now(), updatedAt: Timestamp.now()};
  await environment.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await admin.doc('users/alice').set(userProfile());
    await admin.doc('users/alice/accounts/card').set(opening);
    await admin.doc('users/alice/accounts/money').set({...opening, type: 'cash', nature: 'money'});
    await admin.doc('users/alice/categories/food').set({type: 'expense'});
    await admin.doc('users/alice/operations/debt_test_01').set({...operation, debtCommandId: 'receipt_0001'});
    await admin.doc('users/alice/debtCommands/receipt_0001').set({projectionsApplied: true});
  });
  const alice = environment.authenticatedContext('alice').firestore();
  await assertSucceeds(alice.doc('users/alice/accounts/card').get());
  await assertFails(alice.doc('users/alice/accounts/newcard').set(opening));
  await assertFails(alice.doc('users/alice/accounts/newcard').set({...opening, nature: 'money'}));
  for (const patch of [{name: 'Changed'}, {currentBalanceMinor: 1}, {principalMinor: 0}, {nature: 'money'}, {status: 'archived'}, {includeInDashboard: false}]) await assertFails(alice.doc('users/alice/accounts/card').update(patch));
  for (const patch of [{status: 'rejected'}, {debtCommandId: deleteField()}, {projectionDirection: -1}]) await assertFails(alice.doc('users/alice/operations/debt_test_01').update(patch));
  await assertFails(alice.doc('users/alice/operations/new_op_001').set({...operation, idempotencyKey: 'new_op_001'}));
  await assertFails(alice.doc('users/alice/operations/new_op_002').set({...operation, type: 'transfer', sourceAccountId: 'money', destinationAccountId: 'card', idempotencyKey: 'new_op_002'}));
  await assertFails(alice.doc('users/alice/ledgerEntries/forged').set({operationId: 'debt_test_01', accountId: 'card', currency: 'COP', deltaMinor: 10, occurredAt: Timestamp.now()}));
  for (const collection of ['debtCommands', 'debtReversals', 'debtRefunds']) {
    await assertFails(alice.doc(`users/alice/${collection}/forged`).set({projectionsApplied: true}));
    await assertFails(environment.authenticatedContext('bob').firestore().collection(`users/alice/${collection}`).get());
    await assertFails(environment.unauthenticatedContext().firestore().collection(`users/alice/${collection}`).get());
  }
  await assertFails(alice.doc('users/alice/debtCommands/receipt_0001').get());
});

test('admin portal collections are callable-only and unavailable to every direct client', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('adminOperators/owner').set({email: 'admin@example.test', role: 'owner', status: 'active'});
    await db.doc('adminDailyMetrics/latest').set({generatedAt: Timestamp.now(), metrics: {authUserCount: 1}});
    await db.doc('adminAudit/event_001').set({actorUid: 'owner', action: 'overview.read', createdAt: Timestamp.now()});
  });
  for (const context of [environment.authenticatedContext('owner').firestore(),
    environment.authenticatedContext('alice').firestore(), environment.unauthenticatedContext().firestore()]) {
    for (const path of ['adminOperators/owner', 'adminDailyMetrics/latest', 'adminAudit/event_001']) {
      await assertFails(context.doc(path).get());
      await assertFails(context.doc(path).set({forged: true}));
    }
    for (const collection of ['adminOperators', 'adminDailyMetrics', 'adminAudit']) {
      await assertFails(context.collection(collection).get());
    }
  }
});

test('debt commitments and payment links are owner-readable and server-write-only', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('users/alice').set(userProfile());
    await db.doc('users/alice/debtCommitments/vehicle').set({status: 'active', currency: 'COP'});
    await db.doc('users/alice/debtCommitments/vehicle/versions/1').set({amountMinor: 240000000});
    await db.doc('users/alice/debtCommitments/vehicle/occurrences/vehicle_2026-10').set({monthKey: '2026-10'});
    await db.doc('users/alice/debtPayments/payment_0001').set({status: 'unallocated'});
    await db.doc('users/alice/debtPaymentLinks/payment_0001').set({commitmentId: 'vehicle'});
    await db.doc('users/alice/debtCommitmentCommands/command_0001').set({digest: 'private'});
  });
  const alice = environment.authenticatedContext('alice').firestore();
  await assertSucceeds(alice.doc('users/alice/debtCommitments/vehicle').get());
  await assertSucceeds(alice.doc('users/alice/debtCommitments/vehicle/versions/1').get());
  await assertSucceeds(alice.doc('users/alice/debtCommitments/vehicle/occurrences/vehicle_2026-10').get());
  await assertSucceeds(alice.doc('users/alice/debtPayments/payment_0001').get());
  await assertSucceeds(alice.doc('users/alice/debtPaymentLinks/payment_0001').get());
  for (const context of [alice, environment.authenticatedContext('bob').firestore(), environment.unauthenticatedContext().firestore()]) {
    await assertFails(context.doc('users/alice/debtCommitments/vehicle').set({status: 'active'}));
    await assertFails(context.doc('users/alice/debtCommitments/vehicle/versions/2').set({amountMinor: 1}));
    await assertFails(context.doc('users/alice/debtCommitments/vehicle/occurrences/vehicle_2026-11').set({skipped: true}));
    await assertFails(context.doc('users/alice/debtPayments/payment_0002').set({status: 'allocated'}));
    await assertFails(context.doc('users/alice/debtPaymentLinks/payment_0002').set({commitmentId: 'vehicle'}));
    await assertFails(context.doc('users/alice/debtCommitmentCommands/command_0001').get());
  }
  for (const context of [environment.authenticatedContext('bob').firestore(), environment.unauthenticatedContext().firestore()]) {
    await assertFails(context.doc('users/alice/debtCommitments/vehicle').get());
    await assertFails(context.doc('users/alice/debtPayments/payment_0001').get());
    await assertFails(context.doc('users/alice/debtPaymentLinks/payment_0001').get());
  }
});

test('user data generation is server-owned and invalidates stale writes after reset', async () => {
  const db = environment.authenticatedContext('alice').firestore();
  const profile = db.doc('users/alice');
  await assertSucceeds(profile.set({...userProfile(), dataGeneration: 0}));
  const makeAccount = (dataGeneration) => ({
    name: 'Wallet', type: 'cash', currency: 'COP', openingBalanceMinor: 100,
    currentBalanceMinor: 100, includeInDashboard: true, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(), dataGeneration,
  });
  await assertSucceeds(db.doc('users/alice/accounts/current').set(makeAccount(0)));
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc('users/alice').update({
      dataGeneration: 1, resetStatus: 'ready', onboardingStatus: 'not_started',
    });
  });
  await assertFails(db.doc('users/alice/accounts/stale').set(makeAccount(0)));
  await assertSucceeds(db.doc('users/alice/accounts/new-generation').set(makeAccount(1)));
  await assertFails(profile.update({dataGeneration: 2}));
  await assertFails(profile.update({resetStatus: 'resetting'}));
  await assertFails(db.doc('users/alice/coachDailyCheckIns/2026-10-24')
    .set({...coachCompletion('daily', '2026-10-24'), dataGeneration: 0}));
  await assertSucceeds(db.doc('users/alice/coachDailyCheckIns/2026-10-24')
    .set({...coachCompletion('daily', '2026-10-24'), dataGeneration: 1}));
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc('users/alice').update({resetStatus: 'resetting'});
  });
  await assertFails(db.doc('users/alice/accounts/blocked').set(makeAccount(1)));
  await assertFails(db.doc('users/alice/coachDailyCheckIns/2026-10-24')
    .set({...coachCompletion('daily', '2026-10-24'), dataGeneration: 1}));
});

const coachPreferences = () => ({
  dailyEnabled: true, weeklyEnabled: true,
  dailyHour: 20, dailyMinute: 0, dailyWeekdays: [1, 2, 3, 4, 5, 6, 7],
  weeklyWeekday: 7, weeklyHour: 18, weeklyMinute: 30,
});
const coachCompletion = (kind, periodKey = '2026-10-22') => ({
  periodKey, kind, noMovements: false, reviewedAt: serverTimestamp(),
});

test('email imports are server-only, including evidence, credentials and deduplication receipts', async () => {
  const collections = ['emailImportCandidates', 'emailImportCredentials', 'emailImportCommands',
    'emailImportSources', 'emailImportReferences'];
  await environment.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await admin.doc('users/alice').set(userProfile());
    for (const collection of collections) {
      await admin.doc(`users/alice/${collection}/sample`).set({status: 'pending', evidence: 'PRIVATE'});
    }
  });
  for (const context of [environment.authenticatedContext('alice'),
    environment.authenticatedContext('bob'), environment.unauthenticatedContext()]) {
    for (const collection of collections) {
      const ref = context.firestore().collection(`users/alice/${collection}`);
      await assertFails(ref.doc('sample').get());
      await assertFails(ref.get());
      await assertFails(context.firestore().collectionGroup(collection).get());
      await assertFails(ref.doc('new').set({status: 'approved', operationId: 'forged'}));
      await assertFails(ref.doc('sample').update({status: 'approved', uid: 'bob'}));
      await assertFails(ref.doc('sample').delete());
    }
  }
});

test('coach preferences support legacy absence, exact schema, boundaries and owner access', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const profile = alice.doc('users/alice');
  await assertSucceeds(profile.set({...userProfile(), coachPreferences: coachPreferences()}));
  await assertSucceeds(profile.update({coachPreferences: {
    dailyEnabled: false, weeklyEnabled: false, dailyHour: 0, dailyMinute: 59,
    dailyWeekdays: [7], weeklyWeekday: 1, weeklyHour: 23, weeklyMinute: 0,
  }}));
  await assertSucceeds(profile.update({coachPreferences: deleteField()}));
  await assertSucceeds(profile.update({coachPreferences: coachPreferences()}));
  await assertSucceeds(environment.authenticatedContext('legacy').firestore()
    .doc('users/legacy').set(userProfile()));
  for (const context of [environment.authenticatedContext('bob'), environment.unauthenticatedContext()]) {
    const other = context.firestore().doc('users/alice');
    await assertFails(other.get());
    await assertFails(other.set({...userProfile(), coachPreferences: coachPreferences()}));
    await assertFails(other.update({coachPreferences: coachPreferences()}));
  }
});

test('coach preferences reject malformed creates, replacements and required-field deletion', async () => {
  const profile = environment.authenticatedContext('alice').firestore().doc('users/alice');
  const candidate = environment.authenticatedContext('candidate').firestore().doc('users/candidate');
  await assertSucceeds(profile.set({...userProfile(), coachPreferences: coachPreferences()}));
  const invalid = [null, false, [], 'preferences', {...coachPreferences(), unexpected: true}];
  for (const field of ['dailyEnabled', 'weeklyEnabled']) {
    for (const value of [null, 1, 'true']) invalid.push({...coachPreferences(), [field]: value});
  }
  for (const [field, maximum] of [
    ['dailyHour', 23], ['weeklyHour', 23], ['dailyMinute', 59], ['weeklyMinute', 59],
    ['weeklyWeekday', 7],
  ]) {
    for (const value of [-1, maximum + 1, 1.5, '1', null, true]) {
      invalid.push({...coachPreferences(), [field]: value});
    }
  }
  invalid.push({...coachPreferences(), weeklyWeekday: 0});
  for (const days of [[], [1, 1], [0], [8], [1.5], ['1'], [true], [null],
    [1, 2, 3, 4, 5, 6, 7, 1], '1', null]) {
    invalid.push({...coachPreferences(), dailyWeekdays: days});
  }
  // Exercise every array position rather than validating only the first day.
  for (let index = 0; index < 7; index++) {
    const days = [1, 2, 3, 4, 5, 6, 7];
    days[index] = '7';
    invalid.push({...coachPreferences(), dailyWeekdays: days});
  }
  for (const field of Object.keys(coachPreferences())) {
    const missing = coachPreferences();
    delete missing[field];
    invalid.push(missing);
    await assertFails(profile.update({[`coachPreferences.${field}`]: deleteField()}));
  }
  for (const value of invalid) {
    await assertFails(candidate.set({...userProfile(), coachPreferences: value}));
    await assertFails(profile.update({coachPreferences: value}));
  }
  await assertFails(profile.update({'coachPreferences.unexpected': true}));
});

test('coach routine preferences are optional, owner-only and exact typed profile fields', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const profile = alice.doc('users/alice');
  const valid = {configured: true, dailyEnabled: true, weeklyEnabled: false};
  await assertSucceeds(profile.set(userProfile())); // Legacy profiles need no migration.
  await assertSucceeds(profile.update({coachRoutinePreferences: valid}));
  await assertSucceeds(profile.update({coachRoutinePreferences: {
    configured: true, dailyEnabled: false, weeklyEnabled: true,
  }}));
  await assertSucceeds(profile.update({coachRoutinePreferences: deleteField()}));
  const invalid = [null, false, [], 'routine', {...valid, extra: true}];
  for (const field of Object.keys(valid)) {
    for (const value of [null, 0, 1, 'true']) invalid.push({...valid, [field]: value});
    const missing = {...valid};
    delete missing[field];
    invalid.push(missing);
  }
  for (const value of invalid) {
    await assertFails(profile.update({coachRoutinePreferences: value}));
    await assertFails(environment.authenticatedContext('candidate').firestore()
      .doc('users/candidate').set({...userProfile(), coachRoutinePreferences: value}));
  }
  await assertFails(profile.update({'coachRoutinePreferences.extra': true}));
  for (const context of [environment.authenticatedContext('bob'), environment.unauthenticatedContext()]) {
    await assertFails(context.firestore().doc('users/alice')
      .update({coachRoutinePreferences: valid}));
  }
  await assertFails(profile.update({unapprovedProfileField: true}));
});

for (const [collectionName, kind] of [
  ['coachDailyCheckIns', 'daily'], ['coachWeeklyReviews', 'weekly'],
]) {
  test(`${collectionName}: owner completion, updates, replay and scoped queries`, async () => {
    const db = environment.authenticatedContext('alice').firestore();
    await assertSucceeds(db.doc('users/alice').set(userProfile()));
    const completions = db.collection(`users/alice/${collectionName}`);
    const completion = completions.doc('2026-10-22');
    await assertSucceeds(completion.set(coachCompletion(kind)));
    await assertSucceeds(completion.set(coachCompletion(kind))); // Replay refreshes server time.
    await assertSucceeds(completion.update({reviewedAt: serverTimestamp(), noMovements: kind === 'daily'}));
    await assertSucceeds(completion.get());
    assert.equal((await completion.get()).data().noMovements, kind === 'daily');
    await assertSucceeds(completions.orderBy('periodKey', 'desc').limit(28).get());
    await assertSucceeds(completions.where('periodKey', '>=', '2026-10-01')
      .where('periodKey', '<=', '2026-10-31').orderBy('periodKey').get());
    await assertSucceeds(completions.orderBy('__name__').startAt('2026-10-01').endAt('2026-10-31').get());
    await assertFails(completion.delete());
    for (const context of [environment.authenticatedContext('bob'), environment.unauthenticatedContext()]) {
      const foreign = context.firestore().collection(`users/alice/${collectionName}`);
      await assertFails(foreign.doc(completion.id).get());
      await assertFails(foreign.get());
      await assertFails(foreign.where('periodKey', '==', completion.id).get());
      await assertFails(foreign.doc('2026-10-23').set(coachCompletion(kind, '2026-10-23')));
      await assertFails(foreign.doc(completion.id).update({reviewedAt: serverTimestamp()}));
      await assertFails(foreign.doc(completion.id).delete());
      await assertFails(context.firestore().collectionGroup(collectionName).get());
    }
    await assertFails(db.collectionGroup(collectionName).get());
  });

  test(`${collectionName}: strict create/update schema, dates, server time and parent existence`, async () => {
    const db = environment.authenticatedContext('alice').firestore();
    const profile = db.doc('users/alice');
    const completions = db.collection(`users/alice/${collectionName}`);
    const completion = completions.doc('2026-10-22');
    await assertFails(completion.set(coachCompletion(kind)));
    await assertSucceeds(profile.set(userProfile()));
    const invalid = [
      {periodKey: '2026-10-23'}, {periodKey: 20261022}, {kind: kind === 'daily' ? 'weekly' : 'daily'},
      {kind: true}, {noMovements: 'false'}, {noMovements: 0}, {noMovements: null},
      {reviewedAt: Timestamp.fromMillis(0)}, {reviewedAt: Timestamp.fromMillis(4102444800000)},
      {reviewedAt: '2026-10-22'}, {reviewedAt: null}, {extra: true}, {ownerId: 'bob'},
    ].map((patch) => ({...coachCompletion(kind), ...patch}));
    if (kind === 'weekly') invalid.push({...coachCompletion(kind), noMovements: true});
    for (const field of Object.keys(coachCompletion(kind))) {
      const missing = coachCompletion(kind);
      delete missing[field];
      invalid.push(missing);
    }
    for (const value of invalid) await assertFails(completion.set(value));
    for (const date of ['2026-00-22', '2026-13-22', '2026-10-00', '2026-10-32',
      '2026-1-01', '26-10-22', '2026-10-22suffix', 'x'.repeat(1000)]) {
      await assertFails(completions.doc(date).set(coachCompletion(kind, date)));
    }
    for (const date of ['2026-01-01', '2026-12-31']) {
      await assertSucceeds(completions.doc(date).set(coachCompletion(kind, date)));
    }
    await assertSucceeds(completion.set(coachCompletion(kind)));
    for (const value of invalid) {
      await assertFails(completion.set(value));
      if (Object.keys(coachCompletion(kind)).every((field) => field in value)) {
        await assertFails(completion.update(value));
      }
    }
    for (const field of Object.keys(coachCompletion(kind))) {
      await assertFails(completion.update({[field]: deleteField(),
        ...(field === 'reviewedAt' ? {} : {reviewedAt: serverTimestamp()}),
      }));
    }
    // A patch omitting fields preserves them; a replacement/deletion may not.
    await assertSucceeds(completion.update({reviewedAt: serverTimestamp()}));
    await environment.withSecurityRulesDisabled(async (context) => context.firestore().doc(profile.path).delete());
    await assertFails(completion.update({reviewedAt: serverTimestamp()}));
  });
}

test('unauthenticated users cannot read user data or the category catalog', async () => {
  const db = environment.unauthenticatedContext().firestore();
  await assertFails(db.collection('categoryCatalog').doc('food').get());
  await assertFails(db.collection('users').doc('alice').get());
});

test('user data is isolated and authenticated catalog reads are allowed', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  await assertSucceeds(alice.collection('categoryCatalog').doc('food').get());
  await assertSucceeds(alice.collection('users').doc('alice').set(userProfile()));
  await assertFails(bob.collection('users').doc('alice').get());
});

test('default categories must be written in bounded batches to respect rules access limits', async () => {
  const categoryIds = Array.from({length: 20}, (_, index) => `default_${index}`);
  await environment.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await admin.doc('users/alice').set({...userProfile(), onboardingStatus: 'in_progress'});
    for (const [index, id] of categoryIds.entries()) {
      await admin.doc(`categoryCatalog/${id}`).set({id, type: index % 2 === 0 ? 'expense' : 'income'});
    }
  });

  const alice = environment.authenticatedContext('alice').firestore();
  const categories = alice.collection('users/alice/categories');
  const categoryData = (id, index) => ({
    catalogId: id,
    type: index % 2 === 0 ? 'expense' : 'income',
    name: id,
    icon: 'more_horiz',
    sortOrder: index,
    isSystem: true,
    isArchived: false,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    dataGeneration: 0,
  });

  const oversizedBatch = alice.batch();
  categoryIds.forEach((id, index) => oversizedBatch.set(categories.doc(id), categoryData(id, index)));
  await assertFails(oversizedBatch.commit());

  for (let start = 0; start < categoryIds.length; start += 8) {
    const batch = alice.batch();
    categoryIds.slice(start, start + 8).forEach((id, offset) => {
      const index = start + offset;
      batch.set(categories.doc(id), categoryData(id, index));
    });
    await assertSucceeds(batch.commit());
  }
});

test('home preferences are owner-updatable, typed, bounded, and cannot add profile fields', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  const profile = alice.collection('users').doc('alice');
  await assertSucceeds(profile.set(userProfile()));
  const validPreferences = {
    widgets: {
      totalBalance: false,
      incomeSummary: true,
      expenseSummary: true,
      expenseBudgetRatio: true,
      incomeBudgetRatio: true,
      recentActivity: false,
    },
    hiddenBudgetCategoryIds: ['food', 'transport'],
  };
  await assertSucceeds(profile.update({homePreferences: validPreferences}));
  await assertSucceeds(profile.update({'homePreferences.widgets.coachNextStep': true}));
  await assertSucceeds(profile.update({'homePreferences.widgets.coachNextStep': false}));
  await assertFails(profile.update({'homePreferences.widgets.coachNextStep': 'true'}));
  await assertSucceeds(profile.update({'homePreferences.widgets.coachNextStep': deleteField()}));
  for (const field of Object.keys(validPreferences.widgets)) {
    await assertFails(profile.update({[`homePreferences.widgets.${field}`]: deleteField()}));
  }
  await assertSucceeds(profile.update({homePreferences: deleteField()}));
  await assertFails(profile.update({homePreferences: {...validPreferences, admin: true}}));
  await assertFails(profile.update({homePreferences: {...validPreferences, widgets: {
    ...validPreferences.widgets, unknown: true,
  }}}));
  await assertFails(profile.update({homePreferences: {...validPreferences, widgets: {
    ...validPreferences.widgets, totalBalance: 'false',
  }}}));
  await assertFails(profile.update({homePreferences: {
    ...validPreferences, hiddenBudgetCategoryIds: Array(101).fill('category'),
  }}));
  await assertFails(profile.update({unauthorizedProfileField: true}));
  await assertFails(bob.doc('users/alice').update({homePreferences: validPreferences}));
});

test('appearance preferences are owner-updatable with only supported mode and palette values', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  const profile = alice.doc('users/alice');
  await assertSucceeds(profile.set(userProfile())); // legacy profile without this optional field
  const valid = {mode: 'system', palette: 'lumio'};
  await assertSucceeds(profile.update({appearancePreferences: valid}));
  await assertSucceeds(profile.update({appearancePreferences: {mode: 'dark', palette: 'ocean'}}));
  await assertSucceeds(profile.update({appearancePreferences: {mode: 'light', palette: 'plum'}}));
  await assertSucceeds(profile.update({appearancePreferences: deleteField()}));
  for (const invalid of [
    null, 'dark', {mode: 'automatic', palette: 'lumio'}, {mode: 'dark'},
    {mode: 'dark', palette: 'rainbow'}, {mode: true, palette: 'lumio'},
    {mode: 'system', palette: 'lumio', administrator: true},
  ]) {
    await assertFails(profile.update({appearancePreferences: invalid}));
  }
  await assertSucceeds(profile.update({appearancePreferences: valid}));
  await assertFails(profile.update({[`appearancePreferences.mode`]: deleteField()}));
  await assertFails(bob.doc('users/alice').update({appearancePreferences: valid}));
  await assertFails(environment.unauthenticatedContext().firestore()
    .doc('users/alice').update({appearancePreferences: valid}));
  await assertFails(profile.update({admin: true, appearancePreferences: valid}));
});

test('category colors accept valid ARGB values and reject malformed values without widening access', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  const category = alice.collection('users').doc('alice').collection('categories').doc('food');
  await assertSucceeds(alice.collection('users').doc('alice').set(userProfile()));
  await assertSucceeds(category.set({
    type: 'expense', name: 'Food', icon: 'food', colorValue: 0xFF1C61D1,
    sortOrder: 1, isSystem: false, isArchived: false,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  await assertSucceeds(category.update({colorValue: 0xFF147D55}));
  await assertSucceeds(category.update({colorValue: deleteField()}));
  await assertFails(category.update({colorValue: 'blue'}));
  await assertFails(category.update({colorValue: -1}));
  await assertFails(category.update({colorValue: 4294967296}));
  const bobCategory = bob.collection('users').doc('alice').collection('categories').doc('food');
  await assertFails(bobCategory.update({colorValue: 0xFFB54708}));
});

test('clients cannot write calculated balances or monthly summaries', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  const account = alice.collection('users').doc('alice').collection('accounts').doc('cash');
  await assertSucceeds(alice.collection('users').doc('alice').set(userProfile()));
  await assertSucceeds(account.set({
    name: 'Cash', type: 'cash', currency: 'COP', openingBalanceMinor: 0,
    currentBalanceMinor: 0, includeInDashboard: true, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  await assertSucceeds(account.update({includeInDashboard: false}));
  await assertSucceeds(account.update({includeInDashboard: true}));
  await assertFails(account.update({includeInDashboard: 'false'}));
  await assertFails(bob.collection('users').doc('alice').collection('accounts').doc('cash')
    .update({includeInDashboard: false}));
  await assertFails(account.update({currentBalanceMinor: 100}));
  await assertFails(
    alice.collection('users').doc('alice').collection('monthlySummaries').doc('2026-10_COP')
      .set({monthKey: '2026-10', currency: 'COP'}),
  );
  const event = alice.collection('users').doc('alice').collection('balanceAdjustments').doc('request-12345678');
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc('users/alice/balanceAdjustments/request-12345678').set({
      adjustedAt: Timestamp.now(), adjustments: [], digest: 'private',
    });
  });
  await assertSucceeds(event.get());
  await assertFails(event.set({adjustments: []}));
  await assertFails(event.update({adjustments: []}));
  await assertFails(event.delete());
  await assertFails(bob.collection('users').doc('alice').collection('balanceAdjustments').doc('request-12345678').get());
});

test('invalid operation amounts and cross-account transfers are rejected', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  await assertSucceeds(alice.collection('users').doc('alice').set(userProfile()));
  const accounts = alice.collection('users').doc('alice').collection('accounts');
  const accountData = (name) => ({
    name, type: 'cash', currency: 'COP', openingBalanceMinor: 0,
    currentBalanceMinor: 0, includeInDashboard: true, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  await assertSucceeds(accounts.doc('source').set(accountData('Source')));
  await assertFails(alice.collection('users').doc('alice').collection('operations').doc('invalid-op').set({
    type: 'expense', amountMinor: 1.5, currency: 'COP', categoryId: 'food',
    accountId: 'source', monthKey: '2026-10', occurredAt: Timestamp.now(),
    description: 'Invalid', status: 'confirmed', idempotencyKey: 'invalid-op',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  const bob = environment.authenticatedContext('bob').firestore();
  await assertFails(bob.collection('users').doc('bob').collection('operations').doc('cross-user').set({
    type: 'transfer', amountMinor: 100, currency: 'COP', sourceAccountId: 'source',
    destinationAccountId: 'source', monthKey: '2026-10', occurredAt: Timestamp.now(),
    description: 'Invalid', status: 'confirmed', idempotencyKey: 'cross-user',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
});

test('amount cap is enforced for account opening balances while operation writes are callable-only', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const user = alice.collection('users').doc('alice');
  await assertSucceeds(user.set(userProfile()));
  const accounts = user.collection('accounts');
  const accountData = (name, amount) => ({
    name, type: 'cash', currency: 'COP', openingBalanceMinor: amount,
    currentBalanceMinor: amount, includeInDashboard: true, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  await assertSucceeds(accounts.doc('max-cash').set(accountData('Max cash', 1000000000)));
  await assertFails(accounts.doc('too-much-cash').set(accountData('Too much', 1000000001)));
  await assertSucceeds(user.collection('categories').doc('food').set({
    type: 'expense', name: 'Food', icon: 'food', sortOrder: 1,
    isSystem: false, isArchived: false, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  const operation = (id, amount) => user.collection('operations').doc(id).set({
    type: 'expense', amountMinor: amount, currency: 'COP', categoryId: 'food',
    accountId: 'max-cash', monthKey: '2026-10', occurredAt: Timestamp.now(),
    description: 'Expense', status: 'confirmed', idempotencyKey: id,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  await assertFails(operation('valid-amount', 1000000000));
  await assertFails(operation('large-amount', 1000000001));

  await assertFails(user.collection('budgets').doc('max-budget').set({
    categoryId: 'food', flowType: 'expense', monthKey: '2026-10', currency: 'COP',
    plannedAmountMinor: 1000000000, itemCount: 1, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
});

test('budgets and items are owner-readable but all direct writes are denied', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const budget = context.firestore().doc('users/alice/budgets/budget');
    await budget.set({categoryId: 'food', flowType: 'expense', monthKey: '2026-10', currency: 'COP',
      plannedAmountMinor: 1000, itemCount: 1, status: 'active'});
    await budget.collection('items').doc('item').set({description: 'Item', amountMinor: 1000, dayOfMonth: 1, actualAmountMinor: 0});
  });
  const budget = alice.doc('users/alice/budgets/budget');
  const item = budget.collection('items').doc('item');
  await assertSucceeds(budget.get());
  await assertSucceeds(alice.collection('users/alice/budgets').where('monthKey', '==', '2026-10').get());
  await assertSucceeds(budget.collection('items').orderBy('dayOfMonth').get());
  await assertFails(bob.doc('users/alice/budgets/budget').get());
  await assertFails(bob.doc('users/alice/budgets/budget/items/item').get());
  await assertFails(environment.unauthenticatedContext().firestore().collection('users/alice/budgets').get());
  await assertFails(budget.update({plannedAmountMinor: 1001}));
  await assertFails(budget.update({status: 'archived'}));
  await assertFails(budget.delete());
  await assertFails(item.update({amountMinor: 1001}));
  await assertFails(item.update({description: 'x'.repeat(1000000)}));
  await assertFails(item.update({actualAmountMinor: 100}));
  await assertFails(item.delete());
  await assertFails(budget.collection('items').doc('new').set({description: 'Valid', amountMinor: 1, dayOfMonth: 1}));
  const batch = alice.batch();
  batch.update(budget, {plannedAmountMinor: 2000, itemCount: 2});
  batch.set(budget.collection('items').doc('batch-item'), {description: 'Valid', amountMinor: 1000, dayOfMonth: 1});
  await assertFails(batch.commit());
});

test('operations are readable by their owner but all client writes are rejected, including budget links', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const user = alice.collection('users').doc('alice');
  const category = user.collection('categories').doc('food');
  const budget = user.collection('budgets').doc('2026-10_expense_food_COP');
  const item = budget.collection('items').doc('item-1');
  const account = user.collection('accounts').doc('cash');
  await assertSucceeds(user.set(userProfile()));
  await assertSucceeds(category.set({
    type: 'expense', name: 'Comida', icon: 'food', sortOrder: 1,
    isSystem: false, isArchived: false, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  await assertSucceeds(account.set({
    name: 'Cash', type: 'cash', currency: 'COP', openingBalanceMinor: 0,
    currentBalanceMinor: 0, includeInDashboard: true, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  await environment.withSecurityRulesDisabled(async (context) => {
    const adminBudget = context.firestore().doc(budget.path);
    await adminBudget.set({categoryId: 'food', flowType: 'expense', monthKey: '2026-10',
      currency: 'COP', plannedAmountMinor: 10000, itemCount: 1, status: 'active'});
    await adminBudget.collection('items').doc(item.id).set({description: 'Comida',
      amountMinor: 10000, dayOfMonth: 20, actualAmountMinor: 0, status: 'active'});
  });

  const operation = (id, overrides = {}) => user.collection('operations').doc(id).set({
    type: 'expense', amountMinor: 1000, currency: 'COP', categoryId: 'food', accountId: 'cash',
    budgetId: budget.id, budgetItemId: item.id, monthKey: '2026-10', occurredAt: Timestamp.now(),
    description: 'Lunch', status: 'confirmed', idempotencyKey: id,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(), ...overrides,
  });
  await assertFails(operation('linked-valid'));
  await assertFails(operation('linked-partial', {budgetItemId: null}));
  await assertFails(operation('linked-wrong-category', {categoryId: 'other'}));
  await assertFails(operation('linked-wrong-type', {type: 'income'}));
  await assertFails(operation('linked-wrong-currency', {currency: 'MXN'}));

  const legacyItem = user.collection('budgets').doc(budget.id).collection('items').doc('legacy-item');
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(legacyItem.path).set({
      description: 'Elemento heredado', amountMinor: 5000, dayOfMonth: 15, actualAmountMinor: 0,
    });
  });
  await assertFails(operation('linked-legacy-item', {budgetItemId: legacyItem.id}));

  await environment.withSecurityRulesDisabled(async (context) => context.firestore().doc(item.path).update({status: 'archived'}));
  await assertFails(operation('linked-archived-item'));
  await environment.withSecurityRulesDisabled(async (context) => context.firestore().doc(budget.path).update({status: 'archived'}));
  await assertFails(operation('linked-archived-budget', {budgetItemId: legacyItem.id}));
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(`${user.path}/operations/server-created`).set({
      type: 'expense', amountMinor: 1000, currency: 'COP', categoryId: 'food', accountId: 'cash',
      budgetId: budget.id, budgetItemId: legacyItem.id, monthKey: '2026-10', occurredAt: Timestamp.now(),
      description: 'Lunch', status: 'confirmed', idempotencyKey: 'server-created',
      createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    });
  });
  await assertSucceeds(user.collection('operations').doc('server-created').get());
  await assertFails(environment.authenticatedContext('bob').firestore().doc(`${user.path}/operations/server-created`).get());
});

test('command receipts cannot be read or changed by any client', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc('users/alice/budgetCommands/request-1').set({digest: 'server-only', result: {}});
  });
  for (const context of [environment.authenticatedContext('alice'), environment.authenticatedContext('bob'), environment.unauthenticatedContext()]) {
    const receipt = context.firestore().doc('users/alice/budgetCommands/request-1');
    await assertFails(receipt.get());
    await assertFails(receipt.set({digest: 'forged', result: {}}));
    await assertFails(receipt.update({digest: 'forged'}));
    await assertFails(receipt.delete());
  }
});

test('device registrations are readable only by their owner and are server-write-only', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc('users/alice/devices/phone-installation').set({
      installationId: 'phone-installation', platform: 'ios',
      createdAt: Timestamp.now(), lastSeenAt: Timestamp.now(), expiresAt: Timestamp.now(),
    });
  });
  const owner = environment.authenticatedContext('alice').firestore();
  const other = environment.authenticatedContext('bob').firestore();
  const anonymous = environment.unauthenticatedContext().firestore();
  await assertSucceeds(owner.doc('users/alice/devices/phone-installation').get());
  await assertSucceeds(owner.collection('users/alice/devices').get());
  for (const client of [owner, other, anonymous]) {
    await assertFails(client.doc('users/alice/devices/forged').set({
      installationId: 'forged', platform: 'android',
      createdAt: Timestamp.now(), lastSeenAt: Timestamp.now(), expiresAt: Timestamp.now(),
    }));
    await assertFails(client.doc('users/alice/devices/phone-installation').delete());
  }
  await assertFails(other.doc('users/alice/devices/phone-installation').get());
  await assertFails(anonymous.collection('users/alice/devices').get());
});
