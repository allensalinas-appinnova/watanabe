import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {BudgetCommandError, executeBudgetCommand} from "./budget_commands";
import {BalanceAdjustmentError, executeBalanceAdjustment} from "./balance_adjustments";
import {applyOperationEvent} from "./projection_store";

initializeApp();

export const mutateBudget = onCall({region: "us-central1", timeoutSeconds: 60}, async (request) => {
  try {
    return await executeBudgetCommand(getFirestore(), request.auth?.uid, request.data);
  } catch (error) {
    if (error instanceof BudgetCommandError) throw new HttpsError(error.status, error.issue, {issue: error.issue});
    throw new HttpsError("internal", "budget-command-failed", {issue: "budget-command-failed"});
  }
});

export const adjustAccountBalances = onCall({region: "us-central1", timeoutSeconds: 60}, async (request) => {
  try {
    return await executeBalanceAdjustment(getFirestore(), request.auth?.uid, request.data);
  } catch (error) {
    if (error instanceof BalanceAdjustmentError) {
      throw new HttpsError(error.status, error.issue, {issue: error.issue});
    }
    throw new HttpsError("internal", "balance-adjustment-failed", {issue: "balance-adjustment-failed"});
  }
});

export const processOperation = onDocumentWritten(
  {document: "users/{userId}/operations/{operationId}", retry: true},
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    await applyOperationEvent(getFirestore(), {
      userId: event.params.userId,
      eventId: event.id,
      previous: before?.exists ? before.data() : undefined,
      current: after?.exists ? after.data() : undefined,
    });
  },
);
