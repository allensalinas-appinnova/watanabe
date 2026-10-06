import assert from 'node:assert/strict';
import test from 'node:test';
import {initializeApp} from 'firebase-admin/app';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';

initializeApp({projectId: 'demo-clearbudget'});
const db = getFirestore();
const operations = db.collection('users').doc('pager-user').collection('operations');

test('Firestore operation pages contain 101 records without duplicates', async () => {
  const batch = db.batch();
  for (let index = 0; index < 101; index += 1) {
    const ref = operations.doc(`operation-${String(index).padStart(3, '0')}`);
    batch.set(ref, {
      type: 'expense',
      amountMinor: 100 + index,
      currency: index === 100 ? 'MXN' : 'COP',
      categoryId: 'food',
      accountId: 'cash',
      monthKey: index === 100 ? '2026-09' : '2026-10',
      occurredAt: Timestamp.fromMillis(Date.UTC(2026, 9, 6, 0, index)),
      status: 'confirmed',
      idempotencyKey: `operation-${index}`,
    });
  }
  await batch.commit();

  const first = await operations.orderBy('occurredAt', 'desc').orderBy('__name__').limit(100).get();
  assert.equal(first.size, 100);
  const second = await operations.orderBy('occurredAt', 'desc').orderBy('__name__')
    .startAfter(first.docs.at(-1)).limit(100).get();
  assert.equal(second.size, 1);
  const ids = [...first.docs, ...second.docs].map((doc) => doc.id);
  assert.equal(new Set(ids).size, 101);
  assert.equal(ids.length, 101);

  const filtered = await operations.where('monthKey', '==', '2026-10')
    .where('currency', '==', 'COP').orderBy('occurredAt', 'desc').limit(100).get();
  assert.equal(filtered.size, 100);
});
