import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {BudgetCommandError, executeBudgetCommand} from "./budget_commands";
import {BalanceAdjustmentError, executeBalanceAdjustment} from "./balance_adjustments";
import {applyOperationEvent} from "./projection_store";
import {defineString} from "firebase-functions/params";
import {EmailImportError, executeEmailImportCommand, listEmailImportCandidates} from "./email_imports";
import {DebtCommandError, executeDebtCommand} from "./debt_commands";

initializeApp();

const debtsEnabled = defineString("DEBTS_ENABLED", {default: "false"});
export const mutateDebt = onCall({region: "us-central1", timeoutSeconds: 60, memory: "512MiB"}, async (request) => {
  try {
    const syntheticEmulator = process.env.FUNCTIONS_EMULATOR === "true" && process.env.GCLOUD_PROJECT === "demo-clearbudget";
    return await executeDebtCommand(getFirestore(), request.auth?.uid, request.data, {enabled: syntheticEmulator || debtsEnabled.value() === "true"});
  } catch (error) {
    if (error instanceof DebtCommandError) throw new HttpsError(error.status, error.issue, {issue: error.issue});
    // Never include financial values, names, references, or raw errors in telemetry.
    throw new HttpsError("internal", "debt-command-failed", {issue: "debt-command-failed"});
  }
});

// No email import access until an operator explicitly enrolls pilot UIDs.
const emailImportPilotUids = defineString("GMAIL_IMPORT_PILOT_UIDS_JSON", {default: "[]"});
function emailImportPolicy() {
  try {
    const uids: unknown = JSON.parse(emailImportPilotUids.value());
    return {allowedUids: Array.isArray(uids) && uids.every((uid) =>
      typeof uid === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(uid)) ? uids as string[] : []};
  } catch { return {allowedUids: []}; }
}
function importFailure(error: unknown): never {
  if (error instanceof EmailImportError) {
    throw new HttpsError(error.status, error.issue, {issue: error.issue});
  }
  // Do not log payloads, raw exceptions, email content or financial values.
  throw new HttpsError("internal", "import-command-failed", {issue: "import-command-failed"});
}

export const mutateEmailImport = onCall({region: "us-central1", timeoutSeconds: 60, maxInstances: 2}, async (request) => {
  try {
    return await executeEmailImportCommand(getFirestore(), request.auth?.uid, request.data, emailImportPolicy());
  } catch (error) { return importFailure(error); }
});

export const listEmailImports = onCall({region: "us-central1", timeoutSeconds: 30, maxInstances: 2}, async (request) => {
  try {
    return await listEmailImportCandidates(getFirestore(), request.auth?.uid, request.data, emailImportPolicy());
  } catch (error) { return importFailure(error); }
});

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
