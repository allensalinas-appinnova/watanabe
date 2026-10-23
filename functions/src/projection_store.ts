import {FieldValue, type DocumentReference, type Firestore, type Transaction} from "firebase-admin/firestore";
import {calculateProjectionDeltas, checkedInteger, parseOperation, ProjectionError, validId, type Operation, type SummaryDelta} from "./projection_model";

export type OperationEvent = {
  userId: string;
  eventId: string;
  previous?: Record<string, unknown>;
  current?: Record<string, unknown>;
};

/** Reads every projection first, then returns a write-only commit step.
 * Both the legacy trigger and synchronous debt commands use this calculation.
 */
export async function prepareProjectionWrites(transaction: Transaction, root: DocumentReference,
  changes: Array<{previous?: Operation; current?: Operation}>, allowDebt = false,
  newAccounts = new Map<string, Record<string, unknown>>()): Promise<() => void> {
  const accounts = new Map<string, number>();
  const summaries = new Map<string, SummaryDelta>();
  const budgetItems = new Map<string, number>();
  for (const change of changes) {
    const delta = calculateProjectionDeltas(change.previous, change.current);
    for (const [key, value] of delta.accounts) accounts.set(key, checkedInteger((accounts.get(key) ?? 0) + value));
    for (const [key, value] of delta.budgetItems) budgetItems.set(key, checkedInteger((budgetItems.get(key) ?? 0) + value));
    for (const [key, value] of delta.summaries) {
      const existing = summaries.get(key);
      if (!existing) { summaries.set(key, value); continue; }
      for (const field of ["income", "expense", "transferIn", "transferOut"] as const) existing[field] = checkedInteger(existing[field] + value[field]);
      for (const [id, amount] of value.categories) existing.categories.set(id, checkedInteger((existing.categories.get(id) ?? 0) + amount));
    }
  }
  const refs = new Map<string, DocumentReference>();
  for (const key of accounts.keys()) refs.set(`accounts/${key}`, root.collection("accounts").doc(key));
  for (const key of summaries.keys()) refs.set(`monthlySummaries/${key}`, root.collection("monthlySummaries").doc(key));
  for (const key of budgetItems.keys()) {
    const [budget, item] = key.split("/");
    refs.set(`budgets/${budget}`, root.collection("budgets").doc(budget));
    refs.set(`items/${key}`, root.collection("budgets").doc(budget).collection("items").doc(item));
  }
  const snapshots = await Promise.all([...refs].map(async ([key, ref]) => [key, (await transaction.get(ref)).data()] as const));
  const records = new Map(snapshots);
  for (const [id, account] of newAccounts) {
    if (records.get(`accounts/${id}`)) throw new ProjectionError("account_already_exists");
    records.set(`accounts/${id}`, account);
  }
  for (const {previous, current} of changes) for (const operation of [previous, current]) {
    if (!operation || operation.status !== "confirmed") continue;
    if (!allowDebt && (operation.projectionDirection !== undefined || ["expenseRefund", "debtAdjustment"].includes(operation.type))) throw new ProjectionError("debt_command_required");
    const ids = operation.type === "transfer" ? [operation.sourceAccountId!, operation.destinationAccountId!] : [operation.accountId!];
    for (const id of ids) {
      const account = records.get(`accounts/${id}`);
      if (!account) throw new ProjectionError("missing_account");
      if (!allowDebt && account.nature === "debt") throw new ProjectionError("debt_command_required");
      if (account.currency !== operation.currency) throw new ProjectionError("account_currency_mismatch");
    }
    if (operation.budgetId) {
      const budget = records.get(`budgets/${operation.budgetId}`);
      const item = records.get(`items/${operation.budgetId}/${operation.budgetItemId}`);
      const flow = operation.type === "expenseRefund" ? "expense" : operation.type;
      if (!budget || !item) throw new ProjectionError("missing_budget_reference");
      if (budget.categoryId !== operation.categoryId || budget.flowType !== flow || budget.currency !== operation.currency) throw new ProjectionError("budget_reference_mismatch");
    }
  }
  // Validate all outputs before any write (including when called by a command).
  const balances = [...accounts].map(([id, delta]) => [id, checkedInteger(checkedInteger(records.get(`accounts/${id}`)?.currentBalanceMinor) + delta)] as const);
  const actuals = [...budgetItems].map(([key, delta]) => {
    const value = checkedInteger(checkedInteger(records.get(`items/${key}`)?.actualAmountMinor ?? 0) + delta);
    if (value < 0) throw new ProjectionError("negative_item_actual");
    return [key, value] as const;
  });
  const totals = [...summaries].map(([id, delta]) => {
    const existing = records.get(`monthlySummaries/${id}`) ?? {};
    const byCategory = {...(existing.byCategory ?? {})} as Record<string, number>;
    for (const [categoryId, amount] of delta.categories) byCategory[categoryId] = checkedInteger(checkedInteger(byCategory[categoryId] ?? 0) + amount);
    return [id, {
      monthKey: delta.monthKey, currency: delta.currency,
      incomeMinor: checkedInteger(checkedInteger(existing.incomeMinor ?? 0) + delta.income),
      expenseMinor: checkedInteger(checkedInteger(existing.expenseMinor ?? 0) + delta.expense),
      transferInMinor: checkedInteger(checkedInteger(existing.transferInMinor ?? 0) + delta.transferIn),
      transferOutMinor: checkedInteger(checkedInteger(existing.transferOutMinor ?? 0) + delta.transferOut),
      byCategory, calculationVersion: 1, updatedAt: FieldValue.serverTimestamp(),
    }] as const;
  });
  return () => {
    for (const [id, currentBalanceMinor] of balances) {
      // The caller creates a new account with its final balance in this same transaction.
      if (!newAccounts.has(id)) transaction.update(refs.get(`accounts/${id}`)!, {currentBalanceMinor, updatedAt: FieldValue.serverTimestamp()});
    }
    for (const [id, data] of totals) transaction.set(refs.get(`monthlySummaries/${id}`)!, data, {merge: true});
    for (const [key, actualAmountMinor] of actuals) transaction.update(refs.get(`items/${key}`)!, {actualAmountMinor, updatedAt: FieldValue.serverTimestamp()});
  };
}

/** The event marker and every projection commit together, including on retries. */
export async function applyOperationEvent(db: Firestore, event: OperationEvent): Promise<void> {
  if (!validId(event.userId) || !validId(event.eventId)) throw new ProjectionError("invalid_event");
  // A server-owned receipt proves the synchronous command applied projections.
  // Never skip merely because a document claims it has been processed.
  const debtRecords = [event.previous, event.current].filter((row) => row?.debtCommandId);
  if (debtRecords.length) {
    for (const row of debtRecords) {
      if (!validId(row!.debtCommandId) || !validId(row!.idempotencyKey)) throw new ProjectionError("invalid_debt_receipt");
      const receipt = await db.doc(`users/${event.userId}/debtCommands/${row!.debtCommandId}`).get();
      if (receipt.data()?.projectionsApplied !== true || !receipt.data()?.operationIds?.includes(row!.idempotencyKey)) throw new ProjectionError("missing_debt_receipt");
    }
    return;
  }
  const previous = event.previous ? parseOperation(event.previous) : undefined;
  const current = event.current ? parseOperation(event.current) : undefined;
  if (previous?.status !== "confirmed" && current?.status !== "confirmed") return;
  const root = db.doc(`users/${event.userId}`);
  const marker = root.collection("processedOperations").doc(event.eventId);

  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(marker)).exists) return;
    const write = await prepareProjectionWrites(transaction, root, [{previous, current}]);
    write();
    transaction.create(marker, {processedAt: FieldValue.serverTimestamp()});
  });
}
