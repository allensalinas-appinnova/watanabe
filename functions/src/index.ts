import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore, type DocumentReference} from "firebase-admin/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";

initializeApp();

export type Operation = {
  type: "income" | "expense" | "transfer";
  amountMinor: number;
  currency: string;
  monthKey: string;
  categoryId?: string;
  accountId?: string;
  sourceAccountId?: string;
  destinationAccountId?: string;
  budgetId?: string;
  budgetItemId?: string;
  status: "pending" | "confirmed" | "rejected";
};

type SummaryDelta = {income: number; expense: number; transferIn: number; transferOut: number; categories: Map<string, number>};

export function calculateProjectionDeltas(previous: Operation | undefined, current: Operation | undefined) {
  const accounts = new Map<string, number>();
  const summaries = new Map<string, SummaryDelta>();
  const budgetItems = new Map<string, number>();
  addOperationDelta(previous, -1, accounts, summaries, budgetItems);
  addOperationDelta(current, 1, accounts, summaries, budgetItems);
  return {accounts, summaries, budgetItems};
}

function addOperationDelta(operation: Operation | undefined, direction: 1 | -1,
  accounts: Map<string, number>, summaries: Map<string, SummaryDelta>, budgetItems: Map<string, number>) {
  if (!operation || operation.status !== "confirmed") return;
  const amount = operation.amountMinor * direction;
  const accountDelta = (id: string | undefined, delta: number) => {
    if (id) accounts.set(id, (accounts.get(id) ?? 0) + delta);
  };
  const summaryKey = `${operation.monthKey}_${operation.currency}`;
  const summary = summaries.get(summaryKey) ?? {
    income: 0, expense: 0, transferIn: 0, transferOut: 0, categories: new Map<string, number>(),
  };
  if (operation.type === "income") {
    summary.income += amount;
    if (operation.categoryId) summary.categories.set(operation.categoryId, (summary.categories.get(operation.categoryId) ?? 0) + amount);
    accountDelta(operation.accountId, amount);
  } else if (operation.type === "expense") {
    summary.expense += amount;
    if (operation.categoryId) summary.categories.set(operation.categoryId, (summary.categories.get(operation.categoryId) ?? 0) - amount);
    accountDelta(operation.accountId, -amount);
  } else {
    summary.transferIn += amount;
    summary.transferOut += amount;
    accountDelta(operation.sourceAccountId, -amount);
    accountDelta(operation.destinationAccountId, amount);
  }
  summaries.set(summaryKey, summary);
  if (operation.budgetId && operation.budgetItemId && operation.type !== "transfer") {
    const key = `${operation.budgetId}/${operation.budgetItemId}`;
    budgetItems.set(key, (budgetItems.get(key) ?? 0) + amount);
  }
}

export const processOperation = onDocumentWritten(
  {document: "users/{userId}/operations/{operationId}", retry: true},
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before?.exists && !after?.exists) return;
    const previous = before?.exists ? before.data() as Operation : undefined;
    const current = after?.exists ? after.data() as Operation : undefined;
    const {accounts: accountDeltas, summaries: summaryDeltas, budgetItems: budgetDeltas} =
      calculateProjectionDeltas(previous, current);
    if (!accountDeltas.size && !summaryDeltas.size && !budgetDeltas.size) return;

    const userId = event.params.userId;
    const db = getFirestore();
    const markerRef = db.doc(`users/${userId}/processedOperations/${event.id}`);
    const accountRefs = new Map([...accountDeltas.keys()].map((id) => [id, db.doc(`users/${userId}/accounts/${id}`)]));
    const summaryRefs = new Map([...summaryDeltas.keys()].map((id) => [id, db.doc(`users/${userId}/monthlySummaries/${id}`)]));
    const budgetRefs = new Map<string, DocumentReference>();
    const budgetParentRefs = new Map<string, DocumentReference>();
    for (const key of budgetDeltas.keys()) {
      const [budgetId, itemId] = key.split("/");
      budgetRefs.set(key, db.doc(`users/${userId}/budgets/${budgetId}/items/${itemId}`));
      budgetParentRefs.set(budgetId, db.doc(`users/${userId}/budgets/${budgetId}`));
    }

    await db.runTransaction(async (transaction) => {
      if ((await transaction.get(markerRef)).exists) return;
      const [accountDocs, summaryDocs, budgetDocs, budgetParentDocs] = await Promise.all([
        Promise.all([...accountRefs.values()].map((ref) => transaction.get(ref))),
        Promise.all([...summaryRefs.values()].map((ref) => transaction.get(ref))),
        Promise.all([...budgetRefs.values()].map((ref) => transaction.get(ref))),
        Promise.all([...budgetParentRefs.values()].map((ref) => transaction.get(ref))),
      ]);
      const accountByPath = new Map([...accountRefs].map(([id, ref], i) => [id, accountDocs[i]]));
      const summaryByPath = new Map([...summaryRefs].map(([id, ref], i) => [id, summaryDocs[i]]));
      const budgetByPath = new Map([...budgetRefs].map(([id, ref], i) => [id, budgetDocs[i]]));
      const budgetParentById = new Map([...budgetParentRefs].map(([id, ref], i) => [id, budgetParentDocs[i]]));
      for (const operation of [previous, current]) {
        if (!operation || operation.budgetId === undefined && operation.budgetItemId === undefined) continue;
        if (!operation.budgetId || !operation.budgetItemId || operation.type === "transfer" || !operation.categoryId) {
          throw new Error("Budget item operation must include a complete non-transfer reference.");
        }
        const key = `${operation.budgetId}/${operation.budgetItemId}`;
        const budget = budgetParentById.get(operation.budgetId)?.data();
        const item = budgetByPath.get(key)?.data();
        if (!budget || !item || budget.categoryId !== operation.categoryId ||
            budget.flowType !== operation.type || budget.currency !== operation.currency) {
          throw new Error("Budget item reference does not match the operation.");
        }
      }

      for (const [id, delta] of accountDeltas) {
        const snapshot = accountByPath.get(id);
        if (!snapshot?.exists) throw new Error(`Projection account missing: ${id}`);
        const value = Number(snapshot.data()?.currentBalanceMinor ?? 0) + delta;
        if (!Number.isSafeInteger(value)) throw new Error("Projected account balance is invalid.");
        transaction.update(accountRefs.get(id)!, {currentBalanceMinor: value, updatedAt: FieldValue.serverTimestamp()});
      }
      for (const [key, delta] of summaryDeltas) {
        const ref = summaryRefs.get(key)!;
        const snapshot = summaryByPath.get(key);
        const data = snapshot?.data() ?? {};
        const oldCategories = (data.byCategory as Record<string, number> | undefined) ?? {};
        const byCategory = {...oldCategories};
        for (const [categoryId, categoryDelta] of delta.categories) {
          const value = (byCategory[categoryId] ?? 0) + categoryDelta;
          if (!Number.isSafeInteger(value)) throw new Error("Projected category total is invalid.");
          byCategory[categoryId] = value;
        }
        for (const field of ["income", "expense", "transferIn", "transferOut"] as const) {
          const value = Number(data[`${field}Minor`] ?? 0) + delta[field];
          if (!Number.isSafeInteger(value)) throw new Error("Projected monthly total is invalid.");
        }
        transaction.set(ref, {
          incomeMinor: Number(data.incomeMinor ?? 0) + delta.income,
          expenseMinor: Number(data.expenseMinor ?? 0) + delta.expense,
          transferInMinor: Number(data.transferInMinor ?? 0) + delta.transferIn,
          transferOutMinor: Number(data.transferOutMinor ?? 0) + delta.transferOut,
          byCategory,
          calculationVersion: 1,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      for (const [key, delta] of budgetDeltas) {
        const snapshot = budgetByPath.get(key);
        if (!snapshot?.exists) throw new Error(`Projection budget item missing: ${key}`);
        const value = Number(snapshot.data()?.actualAmountMinor ?? 0) + delta;
        if (!Number.isSafeInteger(value) || value < 0) throw new Error("Budget item actual amount would become invalid.");
        transaction.update(budgetRefs.get(key)!, {actualAmountMinor: value, updatedAt: FieldValue.serverTimestamp()});
      }
      transaction.set(markerRef, {processedAt: FieldValue.serverTimestamp()});
    });
  },
);
