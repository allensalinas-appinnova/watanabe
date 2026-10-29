import {createHash} from "node:crypto";
import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {operationProjectionDigest, parseOperation, validId} from "./projection_model";
import {BudgetCommandError, type BudgetCommandResult} from "./budget_commands";

type Data = Record<string, unknown>;
type Command = {
  requestId: string;
  expectedGeneration: number;
  expectedRevision: number;
  operationId: string;
  budgetId: string | null;
  itemId: string | null;
};

function parse(value: unknown): Command {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new BudgetCommandError("budget-invalid-input");
  const data = value as Data;
  const allowed = ["action", "requestId", "expectedGeneration", "expectedRevision", "operationId", "budgetId", "itemId"];
  if (Object.keys(data).some((key) => !allowed.includes(key)) || data.action !== "setOperationBudgetItem" ||
      typeof data.requestId !== "string" || !/^[A-Za-z0-9_-]{8,128}$/.test(data.requestId) ||
      !Number.isSafeInteger(data.expectedGeneration) || Number(data.expectedGeneration) < 0 ||
      !Number.isSafeInteger(data.expectedRevision) || Number(data.expectedRevision) < 0 ||
      !validId(data.operationId) ||
      !(data.budgetId === null || validId(data.budgetId)) || !(data.itemId === null || validId(data.itemId)) ||
      ((data.budgetId === null) !== (data.itemId === null))) {
    throw new BudgetCommandError("budget-invalid-association");
  }
  return {
    requestId: data.requestId,
    expectedGeneration: Number(data.expectedGeneration),
    expectedRevision: Number(data.expectedRevision),
    operationId: data.operationId,
    budgetId: data.budgetId as string | null,
    itemId: data.itemId as string | null,
  };
}

/** Changes budget attribution without touching cash, debt, or monthly totals. */
export async function executeOperationBudgetAssociation(
  db: Firestore,
  uid: string | undefined,
  payload: unknown,
): Promise<BudgetCommandResult> {
  if (!uid || !validId(uid)) throw new BudgetCommandError("budget-session-expired", "unauthenticated");
  const command = parse(payload);
  const digest = createHash("sha256").update(JSON.stringify(command)).digest("hex");
  const root = db.doc(`users/${uid}`);
  const operationRef = root.collection("operations").doc(command.operationId);
  const receiptRef = root.collection("budgetCommands").doc(command.requestId);
  return db.runTransaction(async (tx) => {
    const profile = (await tx.get(root)).data();
    if (!profile || profile.resetStatus === "resetting") throw new BudgetCommandError("budget-user-resetting", "failed-precondition");
    const generation = Number.isSafeInteger(profile.dataGeneration) ? profile.dataGeneration as number : 0;
    if (generation !== command.expectedGeneration) throw new BudgetCommandError("budget-stale-generation", "failed-precondition");

    const receipt = await tx.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data()?.digest !== digest) throw new BudgetCommandError("budget-request-conflict", "already-exists");
      return receipt.data()!.result as BudgetCommandResult;
    }

    const operationSnapshot = await tx.get(operationRef);
    if (!operationSnapshot.exists) throw new BudgetCommandError("budget-operation-not-found", "not-found");
    const previousRecord = operationSnapshot.data()!;
    const operation = parseOperation(previousRecord);
    const revision = Number.isSafeInteger(previousRecord.revision) ? previousRecord.revision as number : 0;
    if (revision !== command.expectedRevision) throw new BudgetCommandError("budget-operation-changed", "failed-precondition");
    if (operation.status !== "confirmed" || !["income", "expense", "expenseRefund"].includes(operation.type) ||
        (operation.projectionDirection ?? 1) !== 1 || previousRecord.reversalOf !== undefined ||
        previousRecord.appliedProjectionDigest !== operationProjectionDigest(previousRecord)) {
      throw new BudgetCommandError("budget-operation-incompatible", "failed-precondition");
    }
    if (previousRecord.debtCommandId !== undefined && !["purchase", "newChargePaid"].includes(String(previousRecord.debtKind))) {
      throw new BudgetCommandError("budget-operation-incompatible", "failed-precondition");
    }
    const eventGeneration = Number.isSafeInteger(previousRecord.dataGeneration) ? previousRecord.dataGeneration as number : 0;
    if (eventGeneration !== generation) throw new BudgetCommandError("budget-stale-generation", "failed-precondition");

    const previousBudgetId = typeof previousRecord.budgetId === "string" ? previousRecord.budgetId : null;
    const previousItemId = typeof previousRecord.budgetItemId === "string" ? previousRecord.budgetItemId : null;
    if ((previousBudgetId === null) !== (previousItemId === null)) throw new BudgetCommandError("budget-invalid-association", "failed-precondition");
    const associationChanged = command.budgetId !== previousBudgetId || command.itemId !== previousItemId;

    const itemRefs: Array<{
      key: string;
      budgetId: string;
      itemId: string;
      ref: FirebaseFirestore.DocumentReference;
      target: boolean;
    }> = [];
    if (previousBudgetId && previousItemId) itemRefs.push({
      key: JSON.stringify([previousBudgetId, previousItemId]),
      budgetId: previousBudgetId,
      itemId: previousItemId,
      ref: root.collection("budgets").doc(previousBudgetId).collection("items").doc(previousItemId), target: false,
    });
    if (command.budgetId && command.itemId &&
        (command.budgetId !== previousBudgetId || command.itemId !== previousItemId)) itemRefs.push({
      key: JSON.stringify([command.budgetId, command.itemId]),
      budgetId: command.budgetId,
      itemId: command.itemId,
      ref: root.collection("budgets").doc(command.budgetId).collection("items").doc(command.itemId), target: true,
    });
    const budgetRefs = new Map<string, FirebaseFirestore.DocumentReference>();
    for (const budgetId of [previousBudgetId, command.budgetId].filter((id): id is string => id !== null)) {
      budgetRefs.set(budgetId, root.collection("budgets").doc(budgetId));
    }
    const snapshots = await Promise.all([
      ...itemRefs.map(async (entry) => [entry.key, await tx.get(entry.ref)] as const),
      ...[...budgetRefs].map(async ([id, ref]) => [`budget:${id}`, await tx.get(ref)] as const),
    ]);
    const docs = new Map(snapshots);
    const recognizedMinor = operation.amountMinor * (operation.type === "expenseRefund" ? -1 : 1);
    const actualChanges = new Map<string, {ref: FirebaseFirestore.DocumentReference; current: number; delta: number; target: boolean}>();
    for (const entry of itemRefs) {
      const snapshot = docs.get(entry.key);
      if (!snapshot?.exists) throw new BudgetCommandError("budget-item-not-found", "not-found");
      const item = snapshot.data()!;
      if (entry.target && item.status === "archived") throw new BudgetCommandError("budget-item-archived", "failed-precondition");
      const budget = docs.get(`budget:${entry.budgetId}`)?.data();
      if (!budget || budget.categoryId !== operation.categoryId || budget.currency !== operation.currency ||
          budget.flowType !== (operation.type === "income" ? "income" : "expense") || budget.monthKey !== operation.monthKey) {
        throw new BudgetCommandError("budget-operation-incompatible", "failed-precondition");
      }
      if (entry.target && budget.status !== "active") throw new BudgetCommandError("budget-archived", "failed-precondition");
      const key = JSON.stringify([entry.budgetId, entry.itemId]);
      const change = actualChanges.get(key) ?? {
        ref: entry.ref,
        current: (item.actualAmountMinor as number | undefined) ?? 0,
        delta: 0,
        target: entry.target,
      };
      if (associationChanged) change.delta += entry.target ? recognizedMinor : -recognizedMinor;
      actualChanges.set(key, change);
    }
    for (const change of actualChanges.values()) {
      if (!Number.isSafeInteger(change.current + change.delta) || change.current + change.delta < 0) {
        throw new BudgetCommandError("budget-item-actual-invalid", "failed-precondition");
      }
    }

    const nextRevision = associationChanged ? revision + 1 : revision;
    const nextRecord: Data = {...previousRecord, revision: nextRevision, dataGeneration: generation,
      budgetAssociationCommandId: command.requestId, updatedAt: FieldValue.serverTimestamp()};
    if (command.budgetId === null) {
      delete nextRecord.budgetId;
      delete nextRecord.budgetItemId;
    } else {
      nextRecord.budgetId = command.budgetId;
      nextRecord.budgetItemId = command.itemId;
    }
    const projectionDigest = operationProjectionDigest(nextRecord);
    nextRecord.operationProjectionDigest = projectionDigest;
    nextRecord.appliedProjectionDigest = projectionDigest;
    const operationUpdate: Data = {...nextRecord};
    if (command.budgetId === null) {
      operationUpdate.budgetId = FieldValue.delete();
      operationUpdate.budgetItemId = FieldValue.delete();
    }
    const result = {operation: {id: command.operationId, revision: nextRevision, budgetId: command.budgetId, itemId: command.itemId}} as unknown as BudgetCommandResult;
    for (const change of actualChanges.values()) {
      const nextActual = change.current + change.delta;
      if (nextActual === change.current) continue;
      tx.update(change.ref, {actualAmountMinor: nextActual, updatedAt: FieldValue.serverTimestamp()});
    }
    if (associationChanged) tx.update(operationRef, operationUpdate);
    tx.create(receiptRef, {digest, result, operationId: command.operationId, revision: nextRevision,
      projectionsApplied: true, createdAt: FieldValue.serverTimestamp()});
    return result;
  });
}
