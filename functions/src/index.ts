import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";

initializeApp();

type Operation = {
  type: "income" | "expense" | "transfer";
  amountMinor: number;
  currency: string;
  monthKey: string;
  categoryId?: string;
  accountId?: string;
  sourceAccountId?: string;
  destinationAccountId?: string;
  status: "pending" | "confirmed" | "rejected";
};

export const processOperation = onDocumentWritten(
  "users/{userId}/operations/{operationId}",
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const before = event.data?.before;
    const operation = after.data() as Operation;
    const previous = before?.exists ? before.data() as Operation : undefined;
    const sign = !previous ? 1 : previous.status === "confirmed" && operation.status === "rejected" ? -1 : previous.status === "rejected" && operation.status === "confirmed" ? 1 : 0;
    if (sign === 0 || operation.status !== "confirmed" && previous?.status !== "confirmed") return;
    const userId = event.params.userId;
    const operationId = event.params.operationId;
    const db = getFirestore();
    const markerRef = db.doc(`users/${userId}/processedOperations/${event.id}`);

    await db.runTransaction(async (transaction) => {
      const marker = await transaction.get(markerRef);
      if (marker.exists) return;

      const summaryRef = db.doc(`users/${userId}/monthlySummaries/${operation.monthKey}_${operation.currency}`);
      const summary = await transaction.get(summaryRef);
      const current = summary.exists ? summary.data() ?? {} : {};
      const byCategory = {...((current.byCategory as Record<string, number> | undefined) ?? {})};

      if (operation.type === "transfer") {
        if (!operation.sourceAccountId || !operation.destinationAccountId) {
          throw new Error("Transfer operation has no source or destination account.");
        }
        transaction.update(
          db.doc(`users/${userId}/accounts/${operation.sourceAccountId}`),
          {currentBalanceMinor: FieldValue.increment(-sign * operation.amountMinor), updatedAt: FieldValue.serverTimestamp()},
        );
        transaction.update(
          db.doc(`users/${userId}/accounts/${operation.destinationAccountId}`),
          {currentBalanceMinor: FieldValue.increment(sign * operation.amountMinor), updatedAt: FieldValue.serverTimestamp()},
        );
      } else if (operation.accountId) {
        const delta = operation.type === "income" ? operation.amountMinor : -operation.amountMinor;
        transaction.update(
          db.doc(`users/${userId}/accounts/${operation.accountId}`),
          {currentBalanceMinor: FieldValue.increment(sign * delta), updatedAt: FieldValue.serverTimestamp()},
        );
      }

      if (operation.categoryId && operation.type !== "transfer") {
        const signedAmount = operation.type === "income" ? operation.amountMinor : -operation.amountMinor;
        byCategory[operation.categoryId] = (byCategory[operation.categoryId] ?? 0) + sign * signedAmount;
      }
      transaction.set(summaryRef, {
        monthKey: operation.monthKey,
        currency: operation.currency,
        incomeMinor: (current.incomeMinor ?? 0) + sign * (operation.type === "income" ? operation.amountMinor : 0),
        expenseMinor: (current.expenseMinor ?? 0) + sign * (operation.type === "expense" ? operation.amountMinor : 0),
        transferInMinor: (current.transferInMinor ?? 0) + sign * (operation.type === "transfer" ? operation.amountMinor : 0),
        transferOutMinor: (current.transferOutMinor ?? 0) + sign * (operation.type === "transfer" ? operation.amountMinor : 0),
        byCategory,
        calculationVersion: 1,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(markerRef, {processedAt: FieldValue.serverTimestamp()});
    });
  },
);
