import {createHash} from "node:crypto";
import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {checkedInteger, maximumMinor, validCurrency, validId, validMonth} from "./projection_model";
import {executeOperationBudgetAssociation} from "./operation_budget_associations";

type ItemDraft = {description: string; amountMinor: number; dayOfMonth: number};
type BudgetIdentity = {categoryId: string; flowType: "income" | "expense"; monthKey: string; currency: string};
type Command = {requestId: string; expectedGeneration: number} & (
  {action: "create"; identity: BudgetIdentity; items: ItemDraft[]} |
  {action: "addItem"; budgetId: string; item: ItemDraft} |
  {action: "updateItem"; budgetId: string; itemId: string; item: ItemDraft} |
  {action: "archiveItem"; budgetId: string; itemId: string} |
  {action: "reconcile"; budgetId: string} |
  {action: "archiveBudget"; budgetId: string}
);
type Data = Record<string, unknown>;
export type BudgetCommandResult = {budget?: Data; item?: Data; operation?: Data};

export class BudgetCommandError extends Error {
  constructor(readonly issue: string, readonly status: "invalid-argument" | "unauthenticated" | "not-found" | "already-exists" | "failed-precondition" = "invalid-argument") {
    super(issue);
    this.name = "BudgetCommandError";
  }
}

function object(value: unknown): Data {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new BudgetCommandError("budget-invalid-input");
  return value as Data;
}

function keys(data: Data, allowed: string[]): void {
  if (Object.keys(data).some((key) => !allowed.includes(key))) throw new BudgetCommandError("budget-invalid-input");
}

function id(value: unknown): string {
  if (!validId(value) || value.length > 256) throw new BudgetCommandError("budget-invalid-reference");
  return value;
}

function identity(data: Data): BudgetIdentity {
  if ((data.flowType !== "income" && data.flowType !== "expense") || !validMonth(data.monthKey) ||
      Number(data.monthKey.slice(0, 4)) < 1 || !validCurrency(data.currency)) {
    throw new BudgetCommandError("budget-invalid-input");
  }
  return {categoryId: id(data.categoryId), flowType: data.flowType, monthKey: data.monthKey, currency: data.currency as string};
}

function draft(value: unknown): ItemDraft {
  const data = object(value);
  keys(data, ["description", "amountMinor", "dayOfMonth"]);
  if (typeof data.description !== "string" || !data.description.trim() || data.description.trim().length > 200 ||
      !Number.isSafeInteger(data.amountMinor) || Number(data.amountMinor) <= 0 || !Number.isSafeInteger(data.dayOfMonth)) {
    throw new BudgetCommandError("budget-invalid-item");
  }
  return {description: data.description.trim(), amountMinor: data.amountMinor as number, dayOfMonth: data.dayOfMonth as number};
}

function validateItem(item: ItemDraft, budget: BudgetIdentity): void {
  if (item.amountMinor > maximumMinor(budget.currency)) throw new BudgetCommandError("budget-amount-too-large");
  const [year, month] = budget.monthKey.split("-").map(Number);
  const days = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (item.dayOfMonth < 1 || item.dayOfMonth > days) throw new BudgetCommandError("budget-invalid-day");
}

function parseCommand(payload: unknown): Command {
  const data = object(payload);
  if (typeof data.requestId !== "string" || !/^[A-Za-z0-9_-]{8,128}$/.test(data.requestId)) throw new BudgetCommandError("budget-invalid-request-id");
  const requestId = data.requestId;
  if (!Number.isSafeInteger(data.expectedGeneration) || Number(data.expectedGeneration) < 0) throw new BudgetCommandError("budget-generation-required", "failed-precondition");
  const expectedGeneration = Number(data.expectedGeneration);
  switch (data.action) {
  case "create": {
    keys(data, ["requestId", "expectedGeneration", "action", "categoryId", "flowType", "monthKey", "currency", "items"]);
    if (!Array.isArray(data.items) || !data.items.length || data.items.length > 1000) throw new BudgetCommandError("budget-invalid-items");
    return {requestId, expectedGeneration, action: "create", identity: identity(data), items: data.items.map(draft)};
  }
  case "addItem":
    keys(data, ["requestId", "expectedGeneration", "action", "budgetId", "item"]);
    return {requestId, expectedGeneration, action: "addItem", budgetId: id(data.budgetId), item: draft(data.item)};
  case "updateItem":
    keys(data, ["requestId", "expectedGeneration", "action", "budgetId", "itemId", "item"]);
    return {requestId, expectedGeneration, action: "updateItem", budgetId: id(data.budgetId), itemId: id(data.itemId), item: draft(data.item)};
  case "archiveItem":
    keys(data, ["requestId", "expectedGeneration", "action", "budgetId", "itemId"]);
    return {requestId, expectedGeneration, action: "archiveItem", budgetId: id(data.budgetId), itemId: id(data.itemId)};
  case "reconcile":
    keys(data, ["requestId", "expectedGeneration", "action", "budgetId"]);
    return {requestId, expectedGeneration, action: "reconcile", budgetId: id(data.budgetId)};
  case "archiveBudget":
    keys(data, ["requestId", "expectedGeneration", "action", "budgetId"]);
    return {requestId, expectedGeneration, action: "archiveBudget", budgetId: id(data.budgetId)};
  default: throw new BudgetCommandError("budget-invalid-action");
  }
}

/** UID comes from verified callable authentication, never from the command. */
export async function executeBudgetCommand(db: Firestore, uid: string | undefined, payload: unknown): Promise<BudgetCommandResult> {
  if (!uid || !validId(uid)) throw new BudgetCommandError("budget-session-expired", "unauthenticated");
  if (payload && typeof payload === "object" && !Array.isArray(payload) &&
      (payload as Data).action === "setOperationBudgetItem") {
    return executeOperationBudgetAssociation(db, uid, payload);
  }
  const command = parseCommand(payload);
  const digest = createHash("sha256").update(JSON.stringify(command)).digest("hex");
  const root = db.doc(`users/${uid}`);
  const receiptRef = root.collection("budgetCommands").doc(command.requestId);
  const budgetId = command.action === "create" ?
    `${command.identity.monthKey}_${command.identity.flowType}_${command.identity.categoryId}_${command.identity.currency}` : command.budgetId;
  const budgetRef = root.collection("budgets").doc(budgetId);
  return db.runTransaction(async (transaction) => {
    const profile = (await transaction.get(root)).data();
    if (!profile || profile.resetStatus === "resetting") throw new BudgetCommandError("budget-user-resetting", "failed-precondition");
    const generation = Number.isSafeInteger(profile.dataGeneration) ? profile.dataGeneration as number : 0;
    if (generation !== command.expectedGeneration) throw new BudgetCommandError("budget-stale-generation", "failed-precondition");
    const receipt = await transaction.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data()?.digest !== digest) throw new BudgetCommandError("budget-request-conflict", "already-exists");
      return receipt.data()!.result as BudgetCommandResult;
    }
    const budgetSnapshot = await transaction.get(budgetRef);
    const previous = budgetSnapshot.data();
    if (command.action !== "create" && !previous) throw new BudgetCommandError("budget-not-found", "not-found");
    const budget = command.action === "create" ? command.identity : identity(previous!);
    const category = await transaction.get(root.collection("categories").doc(budget.categoryId));
    if (command.action !== "reconcile" && (!category.exists || category.data()?.type !== budget.flowType ||
        (command.action === "create" && category.data()?.isArchived === true))) {
      throw new BudgetCommandError("budget-category-unavailable", "failed-precondition");
    }
    const itemSnapshots = await transaction.get(budgetRef.collection("items"));
    const items = new Map(itemSnapshots.docs.map((doc) => [doc.id, doc.data() as Data]));
    const writes = new Map<string, Data>();
    let changedItemId: string | undefined;
    if (command.action === "create") {
      if (previous && previous.status !== "archived") throw new BudgetCommandError("budget-already-exists", "already-exists");
      if (previous && ["categoryId", "flowType", "monthKey", "currency"].some((key) => previous[key] !== budget[key as keyof BudgetIdentity])) {
        throw new BudgetCommandError("budget-identity-conflict", "failed-precondition");
      }
      for (const [itemId, item] of items) {
        if (item.status !== "archived") {
          const archived = {...item, status: "archived", archivedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()};
          items.set(itemId, archived);
          writes.set(itemId, archived);
        }
      }
      command.items.forEach((item, index) => {
        validateItem(item, budget);
        const itemId = `${command.requestId}_${index}`;
        if (items.has(itemId)) throw new BudgetCommandError("budget-item-conflict", "already-exists");
        const data = {...item, status: "active", actualAmountMinor: 0, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()};
        items.set(itemId, data);
        writes.set(itemId, data);
      });
    } else if (command.action === "reconcile") {
      // A reconciliation only repairs the denormalized parent aggregate. The
      // item documents remain the source of truth and are never rewritten.
    } else {
      if (previous!.status !== "active") throw new BudgetCommandError("budget-archived", "failed-precondition");
      if (command.action === "addItem") {
        validateItem(command.item, budget);
        changedItemId = `${command.requestId}_0`;
        if (items.has(changedItemId)) throw new BudgetCommandError("budget-item-conflict", "already-exists");
        const data = {...command.item, status: "active", actualAmountMinor: 0, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()};
        items.set(changedItemId, data);
        writes.set(changedItemId, data);
      } else if (command.action === "updateItem" || command.action === "archiveItem") {
        const existing = items.get(command.itemId);
        if (!existing) throw new BudgetCommandError("budget-item-not-found", "not-found");
        if (existing.status === "archived") throw new BudgetCommandError("budget-item-archived", "failed-precondition");
        if (command.action === "archiveItem" && [...items.values()].filter((item) => item.status !== "archived").length <= 1) {
          throw new BudgetCommandError("budget-last-item", "failed-precondition");
        }
        if (command.action === "updateItem") validateItem(command.item, budget);
        const data = command.action === "updateItem" ? {...existing, ...command.item, updatedAt: FieldValue.serverTimestamp()} :
          {...existing, status: "archived", archivedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()};
        changedItemId = command.itemId;
        items.set(command.itemId, data);
        writes.set(command.itemId, data);
      }
    }
    let total = 0;
    let count = 0;
    for (const item of items.values()) {
      if (item.status === "archived") continue;
      const value = draft({description: item.description, amountMinor: item.amountMinor, dayOfMonth: item.dayOfMonth});
      validateItem(value, budget);
      total = checkedInteger(total + value.amountMinor);
      if (total > maximumMinor(budget.currency)) throw new BudgetCommandError("budget-amount-too-large");
      count++;
    }
    if (!count) throw new BudgetCommandError("budget-last-item", "failed-precondition");
    const status = command.action === "archiveBudget" ? "archived" :
      command.action === "reconcile" ? previous!.status : "active";
    const canonicalBudget = {id: budgetId, ...budget, plannedAmountMinor: total, itemCount: count, status};
    const changed = changedItemId ? items.get(changedItemId)! : undefined;
    const result: BudgetCommandResult = {budget: canonicalBudget};
    if (changed) result.item = {
      id: changedItemId!, description: changed.description, amountMinor: changed.amountMinor,
      dayOfMonth: changed.dayOfMonth, actualAmountMinor: changed.actualAmountMinor ?? 0, status: changed.status ?? "active",
    };
    // Every read precedes every write, including the query and category validation.
    for (const [itemId, item] of writes) transaction.set(budgetRef.collection("items").doc(itemId), item);
    const aggregateChanged = previous?.plannedAmountMinor !== total || previous?.itemCount !== count;
    const parent = {...budget, plannedAmountMinor: total, itemCount: count, status, updatedAt: FieldValue.serverTimestamp()};
    if (previous) {
      if (command.action !== "reconcile" || aggregateChanged) transaction.update(budgetRef, parent);
    } else {
      transaction.create(budgetRef, {...parent, createdAt: FieldValue.serverTimestamp()});
    }
    transaction.create(receiptRef, {digest, result, createdAt: FieldValue.serverTimestamp()});
    return result;
  });
}
