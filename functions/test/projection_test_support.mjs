import assert from 'node:assert/strict';
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';

assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):59180$/,
  'These tests require the local Firestore emulator on port 59180');
assert.equal(process.env.GCLOUD_PROJECT ?? 'demo-clearbudget', 'demo-clearbudget');
export const app = initializeApp({projectId: 'demo-clearbudget'});
export const db = getFirestore(app);
export const operation = (overrides = {}) => ({
  type: 'expense', amountMinor: 1200, currency: 'COP', monthKey: '2026-10',
  accountId: 'cash', categoryId: 'food', status: 'confirmed', ...overrides,
});

export async function seedUser(id) {
  const root = db.doc(`users/${id}`);
  const batch = db.batch();
  batch.set(root, {onboardingStatus: 'complete'});
  for (const [id, currency, opening] of [['cash', 'COP', 5000], ['bank', 'COP', 10000], ['mxn', 'MXN', 2000], ['brl', 'BRL', 3000]]) {
    batch.set(root.collection('accounts').doc(id), {
      name: 'PRIVATE ACCOUNT NAME', currency, openingBalanceMinor: opening,
      currentBalanceMinor: opening, status: 'active',
    });
  }
  for (const [id, type] of [['food', 'expense'], ['travel', 'expense'], ['salary', 'income']]) {
    batch.set(root.collection('categories').doc(id), {type});
  }
  batch.set(root.collection('budgets').doc('budget'), {categoryId: 'food', flowType: 'expense', currency: 'COP', status: 'archived'});
  batch.set(root.collection('budgets').doc('budget').collection('items').doc('item'), {
    actualAmountMinor: 0, status: 'archived', description: 'PRIVATE DESCRIPTION',
  });
  await batch.commit();
  return root;
}

export async function userDump(root) {
  const records = {};
  const visit = async (ref) => {
    const doc = await ref.get();
    if (doc.exists) records[ref.path] = {data: doc.data(), version: doc.updateTime.valueOf()};
    for (const collection of await ref.listCollections()) {
      for (const child of await collection.listDocuments()) await visit(child);
    }
  };
  await visit(root);
  return records;
}
