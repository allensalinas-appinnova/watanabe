import {createHash} from "node:crypto";
import {FieldValue, Firestore, Timestamp} from "firebase-admin/firestore";
import {executeOperationCorrection, OperationCorrectionError} from "./operation_corrections";
import {ensureOperationProjectionVersion} from "./operation_projection_migration";
import {checkedInteger, maximumMinor, operationProjectionDigest, parseOperation, ProjectionError, validCurrency, validId, validMonth} from "./projection_model";
import {prepareProjectionWrites} from "./projection_store";
import {prepareOperationLedgerWrites} from "./operation_ledger";

type Data = Record<string, unknown>;
type OperationCommandStatus = "unauthenticated" | "invalid-argument" | "not-found" | "failed-precondition" | "already-exists" | "unavailable";

export class OperationCommandError extends Error {
  constructor(readonly issue: string, readonly status: OperationCommandStatus = "invalid-argument") {
    super(issue);
    this.name = "OperationCommandError";
  }
}

function object(value: unknown): Data {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new OperationCommandError("operation-invalid-command");
  return value as Data;
}

function digest(value: unknown): string {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function parseCreate(value: unknown) {
  const data = object(value);
  const allowed = ["action", "requestId", "expectedGeneration", "type", "amountMinor", "currency", "accountId", "categoryId",
    "sourceAccountId", "destinationAccountId", "occurredAt", "monthKey", "description", "idempotencyKey", "budgetId", "budgetItemId"];
  if (Object.keys(data).some((key) => !allowed.includes(key)) || data.action !== "create" ||
      typeof data.requestId !== "string" || !/^[A-Za-z0-9_-]{8,128}$/.test(data.requestId) ||
      data.idempotencyKey !== data.requestId || !Number.isSafeInteger(data.expectedGeneration) || Number(data.expectedGeneration) < 0 ||
      !["income", "expense", "transfer"].includes(String(data.type)) ||
      !Number.isSafeInteger(data.amountMinor) || Number(data.amountMinor) <= 0 ||
      !validCurrency(data.currency) || !validMonth(data.monthKey) ||
      typeof data.occurredAt !== "string" || !Number.isFinite(Date.parse(data.occurredAt)) ||
      typeof data.description !== "string" || data.description.trim().length > 500 ||
      (data.type === "transfer" ? !validId(data.sourceAccountId) || !validId(data.destinationAccountId) ||
        data.sourceAccountId === data.destinationAccountId || data.accountId !== undefined || data.categoryId !== undefined ||
        data.budgetId !== undefined || data.budgetItemId !== undefined :
        !validId(data.accountId) || !validId(data.categoryId) || data.sourceAccountId !== undefined || data.destinationAccountId !== undefined)) {
    throw new OperationCommandError("operation-invalid-command");
  }
  if (Number(data.amountMinor) > maximumMinor(data.currency)) throw new OperationCommandError("operation-amount-too-large");
  if ((data.budgetId === undefined) !== (data.budgetItemId === undefined) ||
      data.budgetId !== undefined && (!validId(data.budgetId) || !validId(data.budgetItemId) || data.type === "transfer")) {
    throw new OperationCommandError("operation-invalid-budget-reference");
  }
  return {
    requestId: data.requestId as string,
    expectedGeneration: Number(data.expectedGeneration),
    type: data.type as "income" | "expense" | "transfer",
    amountMinor: Number(data.amountMinor), currency: data.currency as string,
    ...(typeof data.accountId === "string" ? {accountId: data.accountId} : {}),
    ...(typeof data.categoryId === "string" ? {categoryId: data.categoryId} : {}),
    ...(typeof data.sourceAccountId === "string" ? {sourceAccountId: data.sourceAccountId} : {}),
    ...(typeof data.destinationAccountId === "string" ? {destinationAccountId: data.destinationAccountId} : {}),
    occurredAt: new Date(data.occurredAt as string), monthKey: data.monthKey as string,
    description: (data.description as string).trim(),
    ...(typeof data.budgetId === "string" ? {budgetId: data.budgetId, budgetItemId: data.budgetItemId as string} : {}),
  };
}

function profileReady(profile: Data | undefined, expectedGeneration: number): number {
  if (!profile || profile.resetStatus === "resetting") throw new OperationCommandError("user-reset-in-progress", "failed-precondition");
  if (profile.operationProjectionMigration === "running") throw new OperationCommandError("operation-projection-migration-in-progress", "unavailable");
  const generation = Number.isSafeInteger(profile.dataGeneration) ? profile.dataGeneration as number : 0;
  if (generation !== expectedGeneration) throw new OperationCommandError("stale-data-generation", "failed-precondition");
  if (profile.operationProjectionVersion !== 1) throw new OperationCommandError("operation-projection-migration-required", "failed-precondition");
  return generation;
}

function monthInTimeZone(date: Date, timeZone: unknown): string {
  if (typeof timeZone !== "string") throw new OperationCommandError("operation-profile-time-zone-invalid", "failed-precondition");
  try {
    const parts = new Intl.DateTimeFormat("en", {timeZone, year: "numeric", month: "2-digit"}).formatToParts(date);
    const year = parts.find((part) => part.type === "year")?.value;
    const month = parts.find((part) => part.type === "month")?.value;
    if (!year || !month) throw new Error("missing-date-parts");
    return `${year}-${month}`;
  } catch {
    throw new OperationCommandError("operation-profile-time-zone-invalid", "failed-precondition");
  }
}

async function createOperation(db: Firestore, uid: string, payload: unknown) {
  const command = parseCreate(payload);
  await ensureOperationProjectionVersion(db, uid);
  const root = db.doc(`users/${uid}`);
  const operationRef = root.collection("operations").doc(command.requestId);
  const receiptRef = root.collection("operationCommands").doc(command.requestId);
  const commandDigest = digest(command);
  const operation: Data = {
    type: command.type, amountMinor: checkedInteger(command.amountMinor), currency: command.currency,
    ...(command.accountId ? {accountId: command.accountId} : {}), ...(command.categoryId ? {categoryId: command.categoryId} : {}),
    ...(command.sourceAccountId ? {sourceAccountId: command.sourceAccountId} : {}),
    ...(command.destinationAccountId ? {destinationAccountId: command.destinationAccountId} : {}),
    ...(command.budgetId ? {budgetId: command.budgetId, budgetItemId: command.budgetItemId} : {}),
    monthKey: command.monthKey, occurredAt: Timestamp.fromDate(command.occurredAt), description: command.description,
    status: "confirmed", idempotencyKey: command.requestId, dataGeneration: command.expectedGeneration,
    revision: 0, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
  };
  const projectionDigest = operationProjectionDigest(operation);
  operation.operationProjectionDigest = projectionDigest;
  operation.appliedProjectionDigest = projectionDigest;
  const parsed = parseOperation(operation);
  const entrySpecs = command.type === "transfer" ? [
    {accountId: command.sourceAccountId!, deltaMinor: -command.amountMinor},
    {accountId: command.destinationAccountId!, deltaMinor: command.amountMinor},
  ] : [{accountId: command.accountId!, deltaMinor: command.type === "income" ? command.amountMinor : -command.amountMinor}];
  const entryRefs = entrySpecs.map((_, index) => ({
    id: `${command.requestId}_entry_${index}`,
    root: root.collection("ledgerEntries").doc(`${command.requestId}_entry_${index}`),
    nested: operationRef.collection("entries").doc(`${command.requestId}_entry_${index}`),
  }));

  const result = await db.runTransaction(async (transaction) => {
    const profile = (await transaction.get(root)).data();
    const generation = profileReady(profile, command.expectedGeneration);
    if (monthInTimeZone(command.occurredAt, profile!.timeZone) !== command.monthKey) {
      throw new OperationCommandError("operation-month-mismatch");
    }
    const [receipt, existing] = await Promise.all([transaction.get(receiptRef), transaction.get(operationRef)]);
    if (receipt.exists) {
      if (receipt.data()?.digest !== commandDigest) throw new OperationCommandError("operation-request-conflict", "already-exists");
      return receipt.data()!.result as {operationId: string; revision: number};
    }
    if (existing.exists) {
      const current = existing.data()!;
      const sameCommand = operationProjectionDigest(current) === projectionDigest && current.description === command.description &&
        current.idempotencyKey === command.requestId;
      if (!sameCommand || current.appliedProjectionDigest !== projectionDigest) {
        throw new OperationCommandError("operation-idempotency-conflict", "already-exists");
      }
      const priorResult = {operationId: operationRef.id, revision: Number(current.revision ?? 0)};
      transaction.create(receiptRef, {digest: commandDigest, result: priorResult, projectionsApplied: true, createdAt: FieldValue.serverTimestamp()});
      return priorResult;
    }

    const categoryRef = command.categoryId ? root.collection("categories").doc(command.categoryId) : undefined;
    const budgetRef = command.budgetId ? root.collection("budgets").doc(command.budgetId) : undefined;
    const itemRef = command.budgetId && command.budgetItemId ? budgetRef!.collection("items").doc(command.budgetItemId) : undefined;
    const extraRefs = [categoryRef, budgetRef, itemRef].filter((ref) => ref !== undefined);
    const extraSnapshots = await Promise.all(extraRefs.map((ref) => transaction.get(ref!)));
    const extras = new Map(extraRefs.map((ref, index) => [ref!.path, extraSnapshots[index].data()]));
    if (command.categoryId) {
      const category = extras.get(categoryRef!.path);
      if (!category || category.type !== command.type || category.isArchived === true) throw new OperationCommandError("operation-category-unavailable", "failed-precondition");
    }
    if (command.budgetId) {
      const budget = extras.get(budgetRef!.path);
      const item = extras.get(itemRef!.path);
      if (!budget || !item || budget.status !== "active" || item.status === "archived" || budget.categoryId !== command.categoryId ||
          budget.flowType !== command.type || budget.currency !== command.currency) {
        throw new OperationCommandError("operation-budget-reference-invalid", "failed-precondition");
      }
    }
    const writeProjections = await prepareProjectionWrites(transaction, root, [{current: parsed}]);
    const now = FieldValue.serverTimestamp();
    writeProjections();
    transaction.create(operationRef, operation);
    for (let index = 0; index < entrySpecs.length; index++) {
      const spec = entrySpecs[index];
      const entry = {operationId: operationRef.id, accountId: spec.accountId, deltaMinor: spec.deltaMinor,
        currency: command.currency, occurredAt: Timestamp.fromDate(command.occurredAt), dataGeneration: generation};
      transaction.create(entryRefs[index].root, entry);
      transaction.create(entryRefs[index].nested, entry);
    }
    const commandResult = {operationId: operationRef.id, revision: 0};
    transaction.create(receiptRef, {digest: commandDigest, result: commandResult, operationId: operationRef.id,
      revision: 0, projectionDigest, projectionsApplied: true, createdAt: now});
    return commandResult;
  });
  return result;
}

async function cancelOperation(db: Firestore, uid: string, payload: unknown) {
  const data = object(payload);
  if (Object.keys(data).some((key) => !["action", "operationId", "expectedGeneration"].includes(key)) ||
      data.action !== "cancel" || !validId(data.operationId) || !Number.isSafeInteger(data.expectedGeneration) || Number(data.expectedGeneration) < 0) {
    throw new OperationCommandError("operation-cancel-invalid-command");
  }
  await ensureOperationProjectionVersion(db, uid);
  const operationId = data.operationId as string;
  const expectedGeneration = Number(data.expectedGeneration);
  const requestId = `cancel_${digest({operationId}).slice(0, 48)}`;
  const root = db.doc(`users/${uid}`);
  const operationRef = root.collection("operations").doc(operationId);
  const receiptRef = root.collection("operationCommands").doc(requestId);
  const commandDigest = digest({action: "cancel", operationId});
  return db.runTransaction(async (transaction) => {
    const generation = profileReady((await transaction.get(root)).data(), expectedGeneration);
    const [receipt, snapshot] = await Promise.all([transaction.get(receiptRef), transaction.get(operationRef)]);
    if (receipt.exists) {
      if (receipt.data()?.digest !== commandDigest) throw new OperationCommandError("operation-request-conflict", "already-exists");
      return receipt.data()!.result;
    }
    if (!snapshot.exists) throw new OperationCommandError("operation-not-found", "not-found");
    const previousRecord = snapshot.data()!;
    const previous = parseOperation(previousRecord);
    if (previousRecord.debtCommandId !== undefined || previousRecord.appliedProjectionDigest !== operationProjectionDigest(previousRecord)) {
      throw new OperationCommandError("operation-projection-not-reconciled", "failed-precondition");
    }
    if (previous.status === "rejected") {
      const result = {operationId, revision: Number(previousRecord.revision ?? 0)};
      transaction.create(receiptRef, {digest: commandDigest, result, projectionsApplied: true, createdAt: FieldValue.serverTimestamp()});
      return result;
    }
    if (previous.status !== "confirmed") throw new OperationCommandError("operation-cannot-be-cancelled", "failed-precondition");
    const updated: Data = {...previousRecord, status: "rejected", revision: Number(previousRecord.revision ?? 0) + 1,
      operationEditCommandId: requestId, dataGeneration: generation, updatedAt: FieldValue.serverTimestamp()};
    const projectionDigest = operationProjectionDigest(updated);
    updated.operationProjectionDigest = projectionDigest;
    updated.appliedProjectionDigest = projectionDigest;
    const current = parseOperation(updated);
    const writeProjections = await prepareProjectionWrites(transaction, root, [{previous, current}]);
    const writeLedger = await prepareOperationLedgerWrites(transaction, root, operationId, current);
    writeProjections();
    writeLedger();
    transaction.update(operationRef, updated);
    const result = {operationId, revision: updated.revision};
    transaction.create(receiptRef, {digest: commandDigest, operationId, revision: updated.revision, projectionDigest,
      projectionsApplied: true, result, createdAt: FieldValue.serverTimestamp()});
    return result;
  });
}

async function archiveAccount(db: Firestore, uid: string, payload: unknown) {
  const data = object(payload);
  if (Object.keys(data).some((key) => !["action", "accountId", "expectedGeneration"].includes(key)) ||
      data.action !== "archiveAccount" || !validId(data.accountId) || !Number.isSafeInteger(data.expectedGeneration) || Number(data.expectedGeneration) < 0) {
    throw new OperationCommandError("account-archive-invalid-command");
  }
  await ensureOperationProjectionVersion(db, uid);
  const accountId = data.accountId as string;
  const expectedGeneration = Number(data.expectedGeneration);
  const requestId = `archive_${digest({accountId}).slice(0, 48)}`;
  const root = db.doc(`users/${uid}`);
  const accountRef = root.collection("accounts").doc(accountId);
  const receiptRef = root.collection("operationCommands").doc(requestId);
  const commandDigest = digest({action: "archiveAccount", accountId});
  return db.runTransaction(async (transaction) => {
    profileReady((await transaction.get(root)).data(), expectedGeneration);
    const [receipt, snapshot] = await Promise.all([transaction.get(receiptRef), transaction.get(accountRef)]);
    if (receipt.exists) {
      if (receipt.data()?.digest !== commandDigest) throw new OperationCommandError("operation-request-conflict", "already-exists");
      return receipt.data()!.result;
    }
    if (!snapshot.exists) throw new OperationCommandError("account-not-found", "not-found");
    const account = snapshot.data()!;
    if ((account.nature ?? "money") !== "money") throw new OperationCommandError("debt-account-command-required", "failed-precondition");
    if (account.status === "archived") {
      const result = {accountId, status: "archived"};
      transaction.create(receiptRef, {digest: commandDigest, result, createdAt: FieldValue.serverTimestamp()});
      return result;
    }
    if (account.status !== "active") throw new OperationCommandError("account-status-invalid", "failed-precondition");
    if (!Number.isSafeInteger(account.currentBalanceMinor) || account.currentBalanceMinor !== 0) {
      throw new OperationCommandError("account-balance-must-be-zero-before-archive", "failed-precondition");
    }
    const now = FieldValue.serverTimestamp();
    transaction.update(accountRef, {status: "archived", archivedAt: now, updatedAt: now});
    const result = {accountId, status: "archived"};
    transaction.create(receiptRef, {digest: commandDigest, result, createdAt: now});
    return result;
  });
}

/** Authenticated single entry point for normal operations and money-account archival. */
export async function executeOperationCommand(db: Firestore, uid: string | undefined, payload: unknown) {
  if (!uid || !validId(uid)) throw new OperationCommandError("authentication-required", "unauthenticated");
  const data = object(payload);
  try {
    if (data.action === "create") return await createOperation(db, uid, payload);
    if (data.action === "cancel") return await cancelOperation(db, uid, payload);
    if (data.action === "archiveAccount") return await archiveAccount(db, uid, payload);
    if (data.action === "correct" || data.action === undefined) {
      await ensureOperationProjectionVersion(db, uid);
      const correction = {...data};
      delete correction.action;
      return await executeOperationCorrection(db, uid, correction);
    }
    throw new OperationCommandError("operation-action-unsupported");
  } catch (error) {
    if (error instanceof OperationCorrectionError) {
      throw new OperationCommandError(error.issue, error.status);
    }
    if (!(error instanceof ProjectionError)) throw error;
    const status: OperationCommandStatus = error.code === "projection_migration_in_progress" ? "unavailable" : "failed-precondition";
    throw new OperationCommandError(error.code, status);
  }
}
