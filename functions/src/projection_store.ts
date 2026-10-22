import {FieldValue, type DocumentReference, type Firestore} from "firebase-admin/firestore";
import {calculateProjectionDeltas, checkedInteger, parseOperation, ProjectionError, validId} from "./projection_model";

export type OperationEvent = {
  userId: string;
  eventId: string;
  previous?: Record<string, unknown>;
  current?: Record<string, unknown>;
};

/** The event marker and every projection commit together, including on retries. */
export async function applyOperationEvent(db: Firestore, event: OperationEvent): Promise<void> {
  if (!validId(event.userId) || !validId(event.eventId)) throw new ProjectionError("invalid_event");
  const previous = event.previous ? parseOperation(event.previous) : undefined;
  const current = event.current ? parseOperation(event.current) : undefined;
  if (previous?.status !== "confirmed" && current?.status !== "confirmed") return;
  const deltas = calculateProjectionDeltas(previous, current);
  const root = db.doc(`users/${event.userId}`);
  const marker = root.collection("processedOperations").doc(event.eventId);
  const accounts = new Map([...deltas.accounts.keys()].map((id) => [id, root.collection("accounts").doc(id)]));
  const summaries = new Map([...deltas.summaries.keys()].map((id) => [id, root.collection("monthlySummaries").doc(id)]));
  const items = new Map([...deltas.budgetItems.keys()].map((key) => [key, root.collection("budgets").doc(key.split("/")[0]).collection("items").doc(key.split("/")[1])]));
  const budgets = new Map([...deltas.budgetItems.keys()].map((key) => [key.split("/")[0], root.collection("budgets").doc(key.split("/")[0])]));
  const references = new Map<string, DocumentReference>([...accounts, ...summaries, ...items, ...budgets]
    .map(([, ref]) => [ref.path, ref]));

  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(marker)).exists) return;
    const snapshots = await Promise.all([...references.values()].map((ref) => transaction.get(ref)));
    const records = new Map(snapshots.map((snapshot) => [snapshot.ref.path, snapshot.data()]));
    const data = (ref: DocumentReference) => records.get(ref.path);
    for (const operation of [previous, current]) {
      if (!operation || operation.status !== "confirmed") continue;
      const ids = operation.type === "transfer" ? [operation.sourceAccountId!, operation.destinationAccountId!] : [operation.accountId!];
      for (const id of ids) {
        const account = data(accounts.get(id)!);
        if (!account) throw new ProjectionError("missing_account");
        if (account.currency !== operation.currency) throw new ProjectionError("account_currency_mismatch");
      }
      if (operation.budgetId) {
        const budget = data(budgets.get(operation.budgetId)!);
        const item = data(items.get(`${operation.budgetId}/${operation.budgetItemId}`)!);
        if (!budget || !item) throw new ProjectionError("missing_budget_reference");
        if (budget.categoryId !== operation.categoryId || budget.flowType !== operation.type ||
            budget.currency !== operation.currency) throw new ProjectionError("budget_reference_mismatch");
      }
    }
    for (const [id, delta] of deltas.accounts) {
      const ref = accounts.get(id)!;
      const balance = checkedInteger(checkedInteger(data(ref)?.currentBalanceMinor) + delta);
      transaction.update(ref, {currentBalanceMinor: balance, updatedAt: FieldValue.serverTimestamp()});
    }
    for (const [id, delta] of deltas.summaries) {
      const ref = summaries.get(id)!;
      const existing = data(ref) ?? {};
      const byCategory = {...(existing.byCategory ?? {})} as Record<string, number>;
      for (const [categoryId, amount] of delta.categories) {
        byCategory[categoryId] = checkedInteger(checkedInteger(byCategory[categoryId] ?? 0) + amount);
      }
      transaction.set(ref, {
        monthKey: delta.monthKey, currency: delta.currency,
        incomeMinor: checkedInteger(checkedInteger(existing.incomeMinor ?? 0) + delta.income),
        expenseMinor: checkedInteger(checkedInteger(existing.expenseMinor ?? 0) + delta.expense),
        transferInMinor: checkedInteger(checkedInteger(existing.transferInMinor ?? 0) + delta.transferIn),
        transferOutMinor: checkedInteger(checkedInteger(existing.transferOutMinor ?? 0) + delta.transferOut),
        byCategory, calculationVersion: 1, updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    for (const [key, delta] of deltas.budgetItems) {
      const ref = items.get(key)!;
      const amount = checkedInteger(checkedInteger(data(ref)?.actualAmountMinor ?? 0) + delta);
      if (amount < 0) throw new ProjectionError("negative_item_actual");
      transaction.update(ref, {actualAmountMinor: amount, updatedAt: FieldValue.serverTimestamp()});
    }
    transaction.create(marker, {processedAt: FieldValue.serverTimestamp()});
  });
}
