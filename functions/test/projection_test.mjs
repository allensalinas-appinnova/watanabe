import assert from 'node:assert/strict';
import test from 'node:test';
import {calculateProjectionDeltas} from '../lib/index.js';

const operation = (overrides = {}) => ({
  type: 'expense', amountMinor: 1200, currency: 'COP', monthKey: '2026-10',
  accountId: 'cash', categoryId: 'food', status: 'confirmed', ...overrides,
});

test('confirmed creation, edit, and deletion produce reversible balance and summary deltas', () => {
  const created = calculateProjectionDeltas(undefined, operation());
  assert.equal(created.accounts.get('cash'), -1200);
  assert.equal(created.summaries.get('2026-10_COP').expense, 1200);
  const edited = calculateProjectionDeltas(operation(), operation({amountMinor: 1800}));
  assert.equal(edited.accounts.get('cash'), -600);
  assert.equal(edited.summaries.get('2026-10_COP').expense, 600);
  const deleted = calculateProjectionDeltas(operation(), undefined);
  assert.equal(deleted.accounts.get('cash'), 1200);
  assert.equal(deleted.summaries.get('2026-10_COP').expense, -1200);
});

test('changing an operation moves its contribution between account, month and category', () => {
  const changed = calculateProjectionDeltas(
    operation(),
    operation({type: 'income', amountMinor: 500, accountId: 'bank', monthKey: '2026-11', categoryId: 'salary'}),
  );
  assert.equal(changed.accounts.get('cash'), 1200);
  assert.equal(changed.accounts.get('bank'), 500);
  assert.equal(changed.summaries.get('2026-10_COP').expense, -1200);
  assert.equal(changed.summaries.get('2026-11_COP').income, 500);
});

test('transfers affect only their two accounts and transfer summary; pending rows have no projection', () => {
  const transfer = calculateProjectionDeltas(undefined, operation({
    type: 'transfer', sourceAccountId: 'cash', destinationAccountId: 'bank',
  }));
  assert.equal(transfer.accounts.get('cash'), -1200);
  assert.equal(transfer.accounts.get('bank'), 1200);
  assert.equal(transfer.summaries.get('2026-10_COP').transferIn, 1200);
  const pending = calculateProjectionDeltas(undefined, operation({status: 'pending'}));
  assert.equal(pending.accounts.size, 0);
  assert.equal(pending.summaries.size, 0);
});
