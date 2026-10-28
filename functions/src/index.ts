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
import {UserDataResetError, executeUserDataReset} from "./user_data_reset";
import {DebtCommitmentError, executeDebtCommitmentCommand} from "./debt_commitments";
import {DeviceRegistryError, executeDeviceRegistryCommand} from "./device_registry";
import {executeOperationCommand, OperationCommandError} from "./operation_commands";
import {ensureOperationProjectionVersion, OperationProjectionMigrationError} from "./operation_projection_migration";
export {adminListAudit, adminListUsers, adminLookupUser, adminOverview, bootstrapAdmin, refreshAdminDailyMetrics} from "./admin_portal";

initializeApp();

export const manageDevice = onCall({region: "us-central1", timeoutSeconds: 30}, async (request) => {
  if (request.auth?.token.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("permission-denied", "registered-account-required", {issue: "registered-account-required"});
  }
  try {
    return await executeDeviceRegistryCommand(getFirestore(), request.auth?.uid, request.data);
  } catch (error) {
    if (error instanceof DeviceRegistryError) {
      throw new HttpsError(error.status, error.issue, {issue: error.issue});
    }
    throw new HttpsError("internal", "device-registry-failed", {issue: "device-registry-failed"});
  }
});

export const mutateOperation = onCall({region: "us-central1", timeoutSeconds: 60}, async (request) => {
  try {
    return await executeOperationCommand(getFirestore(), request.auth?.uid, request.data);
  } catch (error) {
    if (error instanceof OperationCommandError || error instanceof OperationProjectionMigrationError) {
      throw new HttpsError(error.status, error.issue, {issue: error.issue});
    }
    throw new HttpsError("internal", "operation-command-failed", {issue: "operation-command-failed"});
  }
});

export const mutateDebt = onCall({region: "us-central1", timeoutSeconds: 60, memory: "512MiB"}, async (request) => {
  try {
    await ensureOperationProjectionVersion(getFirestore(), request.auth?.uid);
    return await executeDebtCommand(getFirestore(), request.auth?.uid, request.data, {enabled: true});
  } catch (error) {
    if (error instanceof DebtCommandError) throw new HttpsError(error.status, error.issue, {issue: error.issue});
    if (error instanceof OperationProjectionMigrationError) throw new HttpsError(error.status, error.issue, {issue: error.issue});
    // Never include financial values, names, references, or raw errors in telemetry.
    throw new HttpsError("internal", "debt-command-failed", {issue: "debt-command-failed"});
  }
});

export const mutateDebtCommitment = onCall({region: "us-central1", timeoutSeconds: 60}, async (request) => {
  try {
    return await executeDebtCommitmentCommand(getFirestore(), request.auth?.uid, request.data);
  } catch (error) {
    if (error instanceof DebtCommitmentError) throw new HttpsError(error.status, error.issue, {issue: error.issue});
    throw new HttpsError("internal", "commitment-command-failed", {issue: "commitment-command-failed"});
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
    await ensureOperationProjectionVersion(getFirestore(), request.auth?.uid);
    return await executeEmailImportCommand(getFirestore(), request.auth?.uid, request.data, emailImportPolicy());
  } catch (error) {
    if (error instanceof OperationProjectionMigrationError) throw new HttpsError(error.status, error.issue, {issue: error.issue});
    return importFailure(error);
  }
});

export const listEmailImports = onCall({region: "us-central1", timeoutSeconds: 30, maxInstances: 2}, async (request) => {
  try {
    return await listEmailImportCandidates(getFirestore(), request.auth?.uid, request.data, emailImportPolicy());
  } catch (error) { return importFailure(error); }
});

export const mutateBudget = onCall({region: "us-central1", timeoutSeconds: 60}, async (request) => {
  try {
    await ensureOperationProjectionVersion(getFirestore(), request.auth?.uid);
    return await executeBudgetCommand(getFirestore(), request.auth?.uid, request.data);
  } catch (error) {
    if (error instanceof BudgetCommandError) throw new HttpsError(error.status, error.issue, {issue: error.issue});
    if (error instanceof OperationProjectionMigrationError) throw new HttpsError(error.status, error.issue, {issue: error.issue});
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
      operationId: event.params.operationId,
      eventId: event.id,
      previous: before?.exists ? before.data() : undefined,
      current: after?.exists ? after.data() : undefined,
    });
  },
);

export const resetUserData = onCall({region: "us-central1", timeoutSeconds: 540, memory: "1GiB"}, async (request) => {
  try {
    return await executeUserDataReset(getFirestore(), request.auth?.uid, request.data);
  } catch (error) {
    if (error instanceof UserDataResetError) {
      throw new HttpsError(error.status, error.issue, {issue: error.issue});
    }
    // Do not log document names, contents, or raw errors during deletion.
    throw new HttpsError("internal", "reset-failed", {issue: "reset-failed"});
  }
});
