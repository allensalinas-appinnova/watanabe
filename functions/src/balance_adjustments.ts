import {createHash} from "node:crypto";
import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {maximumMinor, validCurrency, validId} from "./projection_model";
import {ensureOperationProjectionVersion, OperationProjectionMigrationError} from "./operation_projection_migration";

type AdjustmentInput = {accountId: string; currency: string; targetBalanceMinor: number};
type Command = {requestId: string; expectedGeneration: number; reason?: string; adjustments: AdjustmentInput[]};
type Data = Record<string, unknown>;

export class BalanceAdjustmentError extends Error {
  constructor(readonly issue: string, readonly status: "unauthenticated" | "invalid-argument" | "not-found" | "failed-precondition" | "already-exists" | "unavailable") {
    super(issue);
    this.name = "BalanceAdjustmentError";
  }
}

function parseCommand(value: unknown): Command {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new BalanceAdjustmentError("balance-adjustment-invalid-command", "invalid-argument");
  const data = value as Data;
  const requestId = data.requestId;
  if (!validId(requestId) || !/^[A-Za-z0-9_-]{8,128}$/.test(requestId)) throw new BalanceAdjustmentError("balance-adjustment-invalid-request", "invalid-argument");
  if (!Number.isSafeInteger(data.expectedGeneration) || Number(data.expectedGeneration) < 0) throw new BalanceAdjustmentError("balance-adjustment-generation-required", "failed-precondition");
  if (!Array.isArray(data.adjustments) || data.adjustments.length < 1 || data.adjustments.length > 20) throw new BalanceAdjustmentError("balance-adjustment-invalid-count", "invalid-argument");
  if (data.reason !== undefined && (typeof data.reason !== "string" || data.reason.trim().length > 240)) throw new BalanceAdjustmentError("balance-adjustment-invalid-reason", "invalid-argument");
  const seen = new Set<string>();
  const adjustments = data.adjustments.map((raw): AdjustmentInput => {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new BalanceAdjustmentError("balance-adjustment-invalid-account", "invalid-argument");
    const row = raw as Data;
    if (!validId(row.accountId) || seen.has(row.accountId)) throw new BalanceAdjustmentError("balance-adjustment-invalid-account", "invalid-argument");
    if (!validCurrency(row.currency)) throw new BalanceAdjustmentError("balance-adjustment-invalid-currency", "invalid-argument");
    if (typeof row.targetBalanceMinor !== "number" || !Number.isSafeInteger(row.targetBalanceMinor) || Math.abs(row.targetBalanceMinor) > maximumMinor(row.currency)) throw new BalanceAdjustmentError("balance-adjustment-invalid-amount", "invalid-argument");
    seen.add(row.accountId);
    return {accountId: row.accountId, currency: row.currency, targetBalanceMinor: row.targetBalanceMinor};
  }).sort((a, b) => a.accountId.localeCompare(b.accountId));
  if (Object.keys(data).some((key) => !["requestId", "expectedGeneration", "reason", "adjustments"].includes(key))) throw new BalanceAdjustmentError("balance-adjustment-invalid-command", "invalid-argument");
  return {requestId, expectedGeneration: Number(data.expectedGeneration), adjustments, ...(typeof data.reason === "string" && data.reason.trim() ? {reason: data.reason.trim()} : {})};
}

/** Atomically reconciles selected account balances and records an immutable audit event. */
export async function executeBalanceAdjustment(db: Firestore, uid: string | undefined, payload: unknown): Promise<{requestId: string; adjustments: Array<{accountId: string; currency: string; previousBalanceMinor: number; targetBalanceMinor: number; deltaMinor: number}>; adjustedAt: string}> {
  if (!uid || !validId(uid)) throw new BalanceAdjustmentError("balance-adjustment-session-expired", "unauthenticated");
  const command = parseCommand(payload);
  try {
    await ensureOperationProjectionVersion(db, uid);
  } catch (error) {
    if (error instanceof OperationProjectionMigrationError) throw new BalanceAdjustmentError(error.issue, error.status);
    throw error;
  }
  const digest = createHash("sha256").update(JSON.stringify(command)).digest("hex");
  const root = db.doc(`users/${uid}`);
  const eventRef = root.collection("balanceAdjustments").doc(command.requestId);
  const adjustments = await db.runTransaction(async (transaction) => {
    const profile = (await transaction.get(root)).data();
    if (!profile || profile.resetStatus === "resetting") throw new BalanceAdjustmentError("balance-adjustment-user-resetting", "failed-precondition");
    if (profile.operationProjectionMigration === "running") throw new BalanceAdjustmentError("operation-projection-migration-in-progress", "unavailable");
    if (profile.operationProjectionVersion !== 1) throw new BalanceAdjustmentError("operation-projection-migration-required", "failed-precondition");
    const generation = Number.isSafeInteger(profile.dataGeneration) ? profile.dataGeneration as number : 0;
    if (generation !== command.expectedGeneration) throw new BalanceAdjustmentError("balance-adjustment-stale-generation", "failed-precondition");
    const receipt = await transaction.get(eventRef);
    if (receipt.exists) {
      if (receipt.data()?.digest !== digest) throw new BalanceAdjustmentError("balance-adjustment-request-conflict", "already-exists");
      return receipt.data()!.adjustments as Array<{accountId: string; currency: string; previousBalanceMinor: number; targetBalanceMinor: number; deltaMinor: number}>;
    }
    const references = command.adjustments.map((adjustment) => ({adjustment, ref: root.collection("accounts").doc(adjustment.accountId)}));
    const snapshots = await Promise.all(references.map(({ref}) => transaction.get(ref)));
    const results = references.map(({adjustment}, index) => {
      const snapshot = snapshots[index];
      const account = snapshot.data();
      if (!snapshot.exists || !account) throw new BalanceAdjustmentError("balance-adjustment-account-not-found", "not-found");
      if (account.nature === "debt") throw new BalanceAdjustmentError("balance-adjustment-debt-command-required", "failed-precondition");
      if (account.status !== "active") throw new BalanceAdjustmentError("balance-adjustment-account-inactive", "failed-precondition");
      if (account.currency !== adjustment.currency) throw new BalanceAdjustmentError("balance-adjustment-currency-mismatch", "failed-precondition");
      const previous = account.currentBalanceMinor;
      if (typeof previous !== "number" || !Number.isSafeInteger(previous) || Math.abs(previous) > maximumMinor(adjustment.currency)) throw new BalanceAdjustmentError("balance-adjustment-invalid-current-balance", "failed-precondition");
      return {accountId: adjustment.accountId, currency: adjustment.currency, previousBalanceMinor: previous, targetBalanceMinor: adjustment.targetBalanceMinor, deltaMinor: adjustment.targetBalanceMinor - previous};
    }).filter((row) => row.deltaMinor !== 0);
    const now = FieldValue.serverTimestamp();
    for (const result of results) transaction.update(root.collection("accounts").doc(result.accountId), {currentBalanceMinor: result.targetBalanceMinor, updatedAt: now});
    transaction.create(eventRef, {
      requestId: command.requestId,
      dataGeneration: generation,
      digest,
      reason: command.reason ?? null,
      adjustments: results,
      adjustedAt: now,
    });
    // Return a stable result after commit; the persisted event retains server time.
    return results;
  });
  const saved = (await eventRef.get()).data()!;
  return {requestId: command.requestId, adjustments, adjustedAt: (saved.adjustedAt as {toDate(): Date}).toDate().toISOString()};
}
