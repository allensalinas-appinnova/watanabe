import {createHash} from "node:crypto";
import {FieldPath, type DocumentReference, type Firestore, type QueryDocumentSnapshot, type Transaction} from "firebase-admin/firestore";
import {calculateProjectionDeltas, checkedInteger, maximumMinor, operationProjectionDigest, parseOperation, ProjectionError, validCurrency, validId, validMonth} from "./projection_model";

type RecordData = Record<string, unknown>;
export type AuditSnapshot = {
  userExists: boolean;
  accounts: Map<string, RecordData>;
  categories: Map<string, RecordData>;
  operations: Map<string, RecordData>;
  summaries: Map<string, RecordData>;
  budgets: Map<string, RecordData>;
  items: Map<string, RecordData>;
  balanceAdjustments: Map<string, RecordData>;
  fingerprint: string;
};
export type ProjectionDifference = {document: string; field: string; expected: number | string; actual: number | string | null};
type Issue = {document: string; code: string};
export type AuditReport = {
  version: 1;
  complete: boolean;
  counts: {accounts: number; operations: number; confirmed: number; summaries: number; items: number; differences: number; issues: number};
  differences: ProjectionDifference[];
  issues: Issue[];
};

const fields: Record<string, string[]> = {
  accounts: ["currency", "openingBalanceMinor", "currentBalanceMinor", "nature", "type", "openingPrincipalMinor", "openingChargesMinor", "principalMinor", "chargesMinor"],
  categories: ["type"],
  operations: ["type", "status", "amountMinor", "currency", "monthKey", "occurredAt", "categoryId", "accountId", "sourceAccountId", "destinationAccountId", "budgetId", "budgetItemId", "debtAccountId", "paymentId", "principalDeltaMinor", "chargesDeltaMinor", "projectionDirection", "balanceDeltaMinor", "dataGeneration", "appliedProjectionDigest"],
  monthlySummaries: ["monthKey", "currency", "incomeMinor", "expenseMinor", "transferInMinor", "transferOutMinor", "byCategory"],
  budgets: ["categoryId", "flowType", "currency"],
  items: ["actualAmountMinor"],
  balanceAdjustments: ["adjustments", "adjustedAt"],
};

/** All pages in each pass use one read-only transaction snapshot. */
export async function readAuditSnapshot(db: Firestore, userId: string): Promise<AuditSnapshot> {
  if (!validId(userId)) throw new ProjectionError("invalid_user");
  return db.runTransaction((transaction) => readAuditSnapshotInTransaction(transaction, db.doc(`users/${userId}`)), {readOnly: true});
}

/** Shares the same snapshot and read locks with an explicitly authorized repair. */
export async function readAuditSnapshotInTransaction(transaction: Transaction, root: DocumentReference): Promise<AuditSnapshot> {
  const versions: string[] = [];
  const profile = await transaction.get(root);
  versions.push(`user:${profile.updateTime?.valueOf() ?? "missing"}`);
  const read = async (parent: DocumentReference, collection: string): Promise<Map<string, RecordData>> => {
    const records = new Map<string, RecordData>();
    let cursor: QueryDocumentSnapshot | undefined;
    for (;;) {
      let query = parent.collection(collection).orderBy(FieldPath.documentId()).limit(500).select(...fields[collection]);
      if (cursor) query = query.startAfter(cursor);
      const page = await transaction.get(query);
      for (const doc of page.docs) {
        records.set(doc.id, doc.data());
        versions.push(`${doc.ref.path}:${doc.updateTime.valueOf()}`);
      }
      if (page.size < 500) return records;
      cursor = page.docs.at(-1);
    }
  };
  const accounts = await read(root, "accounts");
  const categories = await read(root, "categories");
  const operations = await read(root, "operations");
  const summaries = await read(root, "monthlySummaries");
  const balanceAdjustments = await read(root, "balanceAdjustments");
  const budgets = await read(root, "budgets");
  const items = new Map<string, RecordData>();
  // Include missing parent documents that still own item subcollections.
  const budgetIds = new Set(budgets.keys());
  for (const operation of operations.values()) if (validId(operation.budgetId)) budgetIds.add(operation.budgetId);
  for (const id of [...budgetIds].sort()) {
    const children = await read(root.collection("budgets").doc(id), "items");
    for (const [itemId, data] of children) items.set(`${id}/${itemId}`, data);
  }
  return {
    userExists: profile.exists, accounts, categories, operations, summaries, budgets, items, balanceAdjustments,
    fingerprint: createHash("sha256").update(versions.sort().join("\n")).digest("hex"),
  };
}

/** Rebuilds expectations from the ledger, never from existing projection values. */
export function compareProjections(snapshot: AuditSnapshot): AuditReport {
  const differences: ProjectionDifference[] = [];
  const issues: Issue[] = [];
  const expectedAccounts = new Map<string, number>();
  const expectedSummaries = new Map<string, RecordData>();
  const expectedItems = new Map<string, number>([...snapshot.items.keys()].map((key) => [key, 0]));
  const issue = (document: string, code: string) => issues.push({document, code});
  if (!snapshot.userExists) issue("user", "missing_user");
  const compare = (document: string, field: string, expected: number | string, actual: unknown) => {
    if (actual === expected) return;
    if (typeof expected === "number" && actual !== undefined &&
        (typeof actual !== "number" || !Number.isSafeInteger(actual))) {
      issue(document, "invalid_projection_value");
    }
    // Never copy arbitrary strings/maps from stored data into diagnostic output.
    const safeActual = actual === undefined ? null :
      typeof actual === "number" && Number.isSafeInteger(actual) ? actual :
        typeof expected === "string" && (validMonth(actual) || validCurrency(actual)) ? actual : "<invalid>";
    differences.push({document, field, expected, actual: safeActual});
  };
  for (const [id, account] of snapshot.accounts) {
    try {
      if (!validCurrency(account.currency)) throw new ProjectionError("invalid_account_currency");
      const opening = checkedInteger(account.openingBalanceMinor);
      if ((opening < 0 && account.nature !== "debt") || Math.abs(opening) > maximumMinor(account.currency)) throw new ProjectionError("invalid_opening_balance");
      expectedAccounts.set(id, opening);
    } catch (error) {
      issue(`accounts/${id}`, error instanceof ProjectionError ? error.code : "invalid_account");
    }
  }
  let confirmed = 0;
  for (const [id, raw] of snapshot.operations) {
    try {
      const operation = parseOperation(raw);
      if (raw.appliedProjectionDigest !== undefined && raw.appliedProjectionDigest !== operationProjectionDigest(raw)) {
        throw new ProjectionError("operation_projection_marker_mismatch");
      }
      if (operation.status !== "confirmed") continue;
      confirmed++;
      const delta = calculateProjectionDeltas(undefined, operation);
      for (const accountId of delta.accounts.keys()) {
        const account = snapshot.accounts.get(accountId);
        if (!account) throw new ProjectionError("missing_account");
        if (!expectedAccounts.has(accountId)) throw new ProjectionError("invalid_account_reference");
        if (account.currency !== operation.currency) throw new ProjectionError("account_currency_mismatch");
      }
      if (operation.categoryId && !["transfer", "unallocatedDebtPayment"].includes(operation.type)) {
        const category = snapshot.categories.get(operation.categoryId);
        if (!category) throw new ProjectionError("missing_category");
        if (category.type !== (operation.type === "expenseRefund" ? "expense" : operation.type)) throw new ProjectionError("category_type_mismatch");
      }
      if (operation.budgetId) {
        const budget = snapshot.budgets.get(operation.budgetId);
        if (!budget || !snapshot.items.has(`${operation.budgetId}/${operation.budgetItemId}`)) {
          throw new ProjectionError("missing_budget_reference");
        }
        if (budget.categoryId !== operation.categoryId || budget.flowType !== (operation.type === "expenseRefund" ? "expense" : operation.type) ||
            budget.currency !== operation.currency) throw new ProjectionError("budget_reference_mismatch");
      }
      // Check the entire contribution before updating any accumulator.
      const accountValues = [...delta.accounts].map(([key, amount]) => {
        const balance = checkedInteger(expectedAccounts.get(key)! + amount);
        const account = snapshot.accounts.get(key)!;
        if (Math.abs(balance) > maximumMinor(account.currency as string)) throw new ProjectionError("account_balance_out_of_range");
        return [key, balance] as const;
      });
      const itemValues = [...delta.budgetItems].map(([key, amount]) => [key, checkedInteger((expectedItems.get(key) ?? 0) + amount)] as const);
      const summaryValues = [...delta.summaries].map(([key, summary]) => {
        const previous = expectedSummaries.get(key) ?? {};
        const byCategory = {...(previous.byCategory ?? {})} as Record<string, number>;
        for (const [categoryId, amount] of summary.categories) byCategory[categoryId] = checkedInteger((byCategory[categoryId] ?? 0) + amount);
        return [key, {
          monthKey: summary.monthKey, currency: summary.currency,
          incomeMinor: checkedInteger(Number(previous.incomeMinor ?? 0) + summary.income),
          expenseMinor: checkedInteger(Number(previous.expenseMinor ?? 0) + summary.expense),
          transferInMinor: checkedInteger(Number(previous.transferInMinor ?? 0) + summary.transferIn),
          transferOutMinor: checkedInteger(Number(previous.transferOutMinor ?? 0) + summary.transferOut),
          byCategory,
        }] as const;
      });
      for (const [key, value] of accountValues) expectedAccounts.set(key, value);
      for (const [key, value] of itemValues) expectedItems.set(key, value);
      for (const [key, value] of summaryValues) expectedSummaries.set(key, value);
    } catch (error) {
      issue(`operations/${id}`, error instanceof ProjectionError ? error.code : "invalid_operation");
    }
  }
  for (const [eventId, event] of snapshot.balanceAdjustments) {
    if (!(event.adjustedAt instanceof Date) && typeof event.adjustedAt !== "object") {
      issue(`balanceAdjustments/${eventId}`, "invalid_adjustment_timestamp");
    }
    if (!Array.isArray(event.adjustments)) {
      issue(`balanceAdjustments/${eventId}`, "invalid_adjustments");
      continue;
    }
    const seen = new Set<string>();
    for (const row of event.adjustments) {
      if (!row || typeof row !== "object") {
        issue(`balanceAdjustments/${eventId}`, "invalid_adjustment");
        continue;
      }
      const adjustment = row as RecordData;
      const accountId = adjustment.accountId;
      const account = typeof accountId === "string" ? snapshot.accounts.get(accountId) : undefined;
      try {
        if (!validId(accountId) || seen.has(accountId)) throw new ProjectionError("invalid_adjustment_account");
        seen.add(accountId);
        if (!account) throw new ProjectionError("missing_account");
        if (!validCurrency(adjustment.currency) || account.currency !== adjustment.currency) throw new ProjectionError("account_currency_mismatch");
        const previous = checkedInteger(adjustment.previousBalanceMinor);
        const target = checkedInteger(adjustment.targetBalanceMinor);
        const delta = checkedInteger(adjustment.deltaMinor);
        if (Math.abs(previous) > maximumMinor(adjustment.currency) || Math.abs(target) > maximumMinor(adjustment.currency) || target - previous !== delta) {
          throw new ProjectionError("invalid_adjustment_amount");
        }
        if (!expectedAccounts.has(accountId)) throw new ProjectionError("invalid_account_reference");
        expectedAccounts.set(accountId, checkedInteger(expectedAccounts.get(accountId)! + delta));
      } catch (error) {
        issue(`balanceAdjustments/${eventId}`, error instanceof ProjectionError ? error.code : "invalid_adjustment");
      }
    }
  }
  for (const [id, expected] of expectedAccounts) compare(`accounts/${id}`, "currentBalanceMinor", expected, snapshot.accounts.get(id)?.currentBalanceMinor);
  for (const [id, account] of snapshot.accounts) {
    if (account.nature !== "debt" || account.type === "creditCard") continue;
    try {
      let principal = checkedInteger(account.openingPrincipalMinor), charges = checkedInteger(account.openingChargesMinor);
      if (principal < 0 || charges < 0 || -(principal + charges) !== account.openingBalanceMinor) throw new ProjectionError("invalid_opening_components");
      for (const operation of snapshot.operations.values()) {
        if (operation.status !== "confirmed" || operation.debtAccountId !== id) continue;
        const direction = operation.projectionDirection === -1 ? -1 : 1;
        principal = checkedInteger(principal + direction * checkedInteger(operation.principalDeltaMinor));
        charges = checkedInteger(charges + direction * checkedInteger(operation.chargesDeltaMinor));
      }
      if (principal < 0 || charges < 0 || expectedAccounts.get(id) !== -(principal + charges)) throw new ProjectionError("inconsistent_debt_components");
      compare(`accounts/${id}`, "principalMinor", principal, account.principalMinor);
      compare(`accounts/${id}`, "chargesMinor", charges, account.chargesMinor);
    } catch (error) { issue(`accounts/${id}`, error instanceof ProjectionError ? error.code : "invalid_debt_components"); }
  }
  for (const [id, expected] of expectedItems) {
    compare(`budgets/${id.split("/")[0]}/items/${id.split("/")[1]}`, "actualAmountMinor", expected, snapshot.items.get(id)?.actualAmountMinor ?? 0);
  }
  for (const key of new Set([...expectedSummaries.keys(), ...snapshot.summaries.keys()])) {
    const stored = snapshot.summaries.get(key);
    const expected = expectedSummaries.get(key);
    const document = `monthlySummaries/${key}`;
    if (!stored) compare(document, "document", "present", undefined);
    const match = /^(\d{4}-(?:0[1-9]|1[0-2]))_([A-Z]{3})$/.exec(key);
    if (!match) { issue(document, "invalid_summary_key"); continue; }
    compare(document, "monthKey", match[1], stored?.monthKey);
    compare(document, "currency", match[2], stored?.currency);
    for (const field of ["incomeMinor", "expenseMinor", "transferInMinor", "transferOutMinor"]) compare(document, field, Number(expected?.[field] ?? 0), stored?.[field]);
    const expectedCategories = (expected?.byCategory ?? {}) as Record<string, number>;
    const rawCategories = stored?.byCategory;
    if (rawCategories !== undefined && (rawCategories === null || typeof rawCategories !== "object" || Array.isArray(rawCategories))) {
      issue(document, "invalid_category_totals");
    }
    const storedCategories = rawCategories && typeof rawCategories === "object" && !Array.isArray(rawCategories) ? rawCategories as Record<string, unknown> : {};
    for (const category of new Set([...Object.keys(expectedCategories), ...Object.keys(storedCategories)])) {
      compare(document, `byCategory.${category}`, expectedCategories[category] ?? 0, storedCategories[category] ?? 0);
    }
  }
  return {
    version: 1, complete: issues.length === 0,
    counts: {accounts: snapshot.accounts.size, operations: snapshot.operations.size, confirmed, summaries: snapshot.summaries.size, items: snapshot.items.size, differences: differences.length, issues: issues.length},
    differences, issues,
  };
}

export async function auditProjections(db: Firestore, userId: string,
  read: typeof readAuditSnapshot = readAuditSnapshot): Promise<AuditReport> {
  const first = await read(db, userId);
  const second = await read(db, userId);
  const report = compareProjections(second);
  if (first.fingerprint !== second.fingerprint) {
    report.complete = false;
    report.issues.push({document: "user", code: "concurrent_change_detected"});
    report.counts.issues = report.issues.length;
  }
  return report;
}

export function auditExitCode(report: AuditReport): 0 | 1 | 2 {
  return !report.complete ? 1 : report.differences.length ? 2 : 0;
}
