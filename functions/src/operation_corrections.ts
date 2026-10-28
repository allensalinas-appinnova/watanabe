import {createHash} from "node:crypto";
import {FieldValue, Firestore, Timestamp} from "firebase-admin/firestore";
import {checkedInteger, maximumMinor, operationProjectionDigest, parseOperation, validCurrency, validId, validMonth} from "./projection_model";
import {prepareProjectionWrites} from "./projection_store";
import {prepareOperationLedgerWrites} from "./operation_ledger";

type Data = Record<string, unknown>;
type Command = {
  requestId: string;
  expectedGeneration: number;
  expectedRevision: number;
  operationId: string;
  amountMinor: number;
  currency: string;
  accountId: string;
  categoryId: string;
  monthKey: string;
  occurredAt: Date;
  description: string;
};

export class OperationCorrectionError extends Error {
  constructor(readonly issue: string, readonly status: "unauthenticated" | "invalid-argument" | "not-found" | "failed-precondition" | "already-exists" = "invalid-argument") {
    super(issue);
    this.name = "OperationCorrectionError";
  }
}

function object(value: unknown): Data {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new OperationCorrectionError("operation-edit-invalid-command");
  return value as Data;
}

function parseCommand(value: unknown): Command {
  const data = object(value);
  const allowed = ["requestId", "expectedGeneration", "expectedRevision", "operationId", "amountMinor", "currency", "accountId", "categoryId", "monthKey", "occurredAt", "description"];
  if (Object.keys(data).some((key) => !allowed.includes(key)) ||
      typeof data.requestId !== "string" || !/^[A-Za-z0-9_-]{8,128}$/.test(data.requestId) ||
      !Number.isSafeInteger(data.expectedGeneration) || Number(data.expectedGeneration) < 0 ||
      !Number.isSafeInteger(data.expectedRevision) || Number(data.expectedRevision) < 0 ||
      !validId(data.operationId) || !Number.isSafeInteger(data.amountMinor) || Number(data.amountMinor) <= 0 ||
      !validCurrency(data.currency) || !validId(data.accountId) || !validId(data.categoryId) ||
      !validMonth(data.monthKey) || typeof data.occurredAt !== "string" || !Number.isFinite(Date.parse(data.occurredAt)) ||
      typeof data.description !== "string" || data.description.trim().length > 500) {
    throw new OperationCorrectionError("operation-edit-invalid-command");
  }
  if (Number(data.amountMinor) > maximumMinor(data.currency)) throw new OperationCorrectionError("operation-edit-amount-too-large");
  return {
    requestId: data.requestId,
    expectedGeneration: Number(data.expectedGeneration),
    expectedRevision: Number(data.expectedRevision),
    operationId: data.operationId,
    amountMinor: Number(data.amountMinor),
    currency: data.currency,
    accountId: data.accountId,
    categoryId: data.categoryId,
    monthKey: data.monthKey,
    occurredAt: new Date(data.occurredAt),
    description: data.description.trim(),
  };
}

function digest(value: unknown): string {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function monthInTimeZone(date: Date, timeZone: unknown): string {
  const zone = typeof timeZone === "string" ? timeZone : "UTC";
  try {
    const parts = new Intl.DateTimeFormat("en", {timeZone: zone, year: "numeric", month: "2-digit"}).formatToParts(date);
    const year = parts.find((part) => part.type === "year")?.value;
    const month = parts.find((part) => part.type === "month")?.value;
    if (!year || !month) throw new Error("missing-date-parts");
    return `${year}-${month}`;
  } catch {
    throw new OperationCorrectionError("operation-edit-invalid-time-zone", "failed-precondition");
  }
}

/** Corrects a confirmed income/expense and its projections atomically and idempotently. */
export async function executeOperationCorrection(db: Firestore, uid: string | undefined, payload: unknown) {
  if (!uid || !validId(uid)) throw new OperationCorrectionError("authentication-required", "unauthenticated");
  const command = parseCommand(payload);
  const root = db.doc(`users/${uid}`);
  const operationRef = root.collection("operations").doc(command.operationId);
  const profileRef = root;
  const receiptRef = root.collection("operationCorrections").doc(command.requestId);
  const accountRef = root.collection("accounts").doc(command.accountId);
  const categoryRef = root.collection("categories").doc(command.categoryId);
  const commandDigest = digest(command);

  return db.runTransaction(async (transaction) => {
    const profile = (await transaction.get(profileRef)).data();
    if (!profile || profile.resetStatus === "resetting") throw new OperationCorrectionError("user-reset-in-progress", "failed-precondition");
    const generation = Number.isSafeInteger(profile.dataGeneration) ? profile.dataGeneration as number : 0;
    if (generation !== command.expectedGeneration) throw new OperationCorrectionError("stale-data-generation", "failed-precondition");

    const receipt = await transaction.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data()?.digest !== commandDigest) throw new OperationCorrectionError("operation-edit-request-conflict", "already-exists");
      return receipt.data()!.result as {operationId: string; revision: number};
    }

    const operationSnapshot = await transaction.get(operationRef);
    if (!operationSnapshot.exists) throw new OperationCorrectionError("operation-not-found", "not-found");
    const previousRecord = operationSnapshot.data()!;
    const previous = parseOperation(previousRecord);
    const revision = Number.isSafeInteger(previousRecord.revision) ? previousRecord.revision as number : 0;
    if (revision !== command.expectedRevision) throw new OperationCorrectionError("operation-changed-elsewhere", "failed-precondition");
    if (previous.status !== "confirmed" || !["income", "expense"].includes(previous.type) ||
        previousRecord.debtCommandId !== undefined || previousRecord.reversalOf !== undefined ||
        previousRecord.projectionDirection !== undefined && previousRecord.projectionDirection !== 1) {
      throw new OperationCorrectionError("operation-cannot-be-edited", "failed-precondition");
    }
    const eventGeneration = Number.isSafeInteger(previousRecord.dataGeneration) ? previousRecord.dataGeneration as number : 0;
    if (eventGeneration !== generation) throw new OperationCorrectionError("operation-stale-generation", "failed-precondition");
    if (previousRecord.appliedProjectionDigest !== operationProjectionDigest(previousRecord)) {
      throw new OperationCorrectionError("operation-projection-not-reconciled", "failed-precondition");
    }

    const [accountSnapshot, categorySnapshot] = await Promise.all([
      transaction.get(accountRef), transaction.get(categoryRef),
    ]);
    const account = accountSnapshot.data();
    const category = categorySnapshot.data();
    if (!accountSnapshot.exists || !account || account.status !== "active" || (account.nature ?? "money") !== "money") {
      throw new OperationCorrectionError("operation-edit-account-unavailable", "failed-precondition");
    }
    if (account.currency !== command.currency) throw new OperationCorrectionError("operation-edit-currency-mismatch", "failed-precondition");
    if (!categorySnapshot.exists || !category || category.type !== previous.type || category.isArchived === true) {
      throw new OperationCorrectionError("operation-edit-category-unavailable", "failed-precondition");
    }

    const date = command.occurredAt;
    if (monthInTimeZone(date, profile.timeZone) !== command.monthKey) {
      throw new OperationCorrectionError("operation-edit-month-mismatch");
    }
    const keepBudget = previousRecord.budgetId && previousRecord.budgetItemId &&
      previousRecord.categoryId === command.categoryId && previous.monthKey === command.monthKey;
    const updatedRecord: Data = {
      ...previousRecord,
      amountMinor: checkedInteger(command.amountMinor),
      currency: command.currency,
      accountId: command.accountId,
      categoryId: command.categoryId,
      monthKey: command.monthKey,
      occurredAt: Timestamp.fromDate(date),
      description: command.description,
      revision: revision + 1,
      operationEditCommandId: command.requestId,
      dataGeneration: generation,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (!keepBudget) {
      delete updatedRecord.budgetId;
      delete updatedRecord.budgetItemId;
    }
    // Validate the operation's complete projection effects and read their current values before writing.
    const nextOperation = parseOperation(updatedRecord);
    const applyProjection = await prepareProjectionWrites(transaction, root, [{previous, current: nextOperation}]);
    const applyLedger = await prepareOperationLedgerWrites(transaction, root, command.operationId, nextOperation);
    const result = {operationId: command.operationId, revision: revision + 1};
    const projectionDigest = operationProjectionDigest(updatedRecord);
    const finalRecord = {...updatedRecord, operationProjectionDigest: projectionDigest, appliedProjectionDigest: projectionDigest};
    applyProjection();
    applyLedger();
    transaction.update(operationRef, finalRecord);
    transaction.create(receiptRef, {
      digest: commandDigest,
      operationId: command.operationId,
      revision: revision + 1,
      status: updatedRecord.status,
      projectionDigest: operationProjectionDigest(updatedRecord),
      projectionsApplied: true,
      result,
      createdAt: FieldValue.serverTimestamp(),
    });
    return result;
  });
}
