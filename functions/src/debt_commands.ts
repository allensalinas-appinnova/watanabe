import {createHash} from "node:crypto";
import {FieldValue, Timestamp, type Firestore} from "firebase-admin/firestore";
import {calculateProjectionDeltas, checkedInteger, maximumMinor, parseOperation, validCurrency, validId, type Operation} from "./projection_model";
import {prepareProjectionWrites} from "./projection_store";

type Data = Record<string, unknown>;
function commitmentPaused(plan: Data, month: string): boolean {
  if (Array.isArray(plan.pauseRanges) && plan.pauseRanges.some((raw) => {
    if (!raw || typeof raw !== "object") return false;
    const range = raw as Data;
    return typeof range.fromMonth === "string" && month >= range.fromMonth &&
      (typeof range.untilMonth !== "string" || month < range.untilMonth);
  })) return true;
  return typeof plan.pausedFromMonth === "string" && month >= plan.pausedFromMonth;
}
type Status = "unauthenticated" | "invalid-argument" | "failed-precondition" | "already-exists" | "not-found";
export class DebtCommandError extends Error {
  constructor(readonly issue: string, readonly status: Status = "invalid-argument") { super(issue); }
}
function fail(issue: string, status: Status = "invalid-argument"): never { throw new DebtCommandError(`debt-${issue}`, status); }
function id(value: unknown): string {
  if (!validId(value) || value.length > 128) fail("invalid-reference");
  return value;
}
function text(value: unknown, maximum: number, required = false): string {
  if (typeof value !== "string" || value.trim().length > maximum || (required && !value.trim())) fail("invalid-text");
  return value.trim();
}
function amount(value: unknown, currency: string, negative = false): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || Math.abs(value) > maximumMinor(currency) || (!negative && value < 0)) fail("invalid-amount");
  return value;
}
function object(value: unknown): Data {
  if (!value || typeof value !== "object" || Array.isArray(value)) fail("invalid-command");
  return value as Data;
}
function only(data: Data, keys: string[]) {
  if (Object.keys(data).some((key) => !keys.includes(key))) fail("unknown-field");
}
function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b)).map(([key, child]) => [key, canonical(child)]));
  return value;
}
function instant(value: unknown): Timestamp {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$/.test(value)) fail("invalid-date");
  const date = new Date(value);
  const [year, month, day] = value.substring(0, 10).split("-").map(Number);
  if (month < 1 || month > 12 || day < 1 || day > new Date(Date.UTC(year, month, 0)).getUTCDate()) fail("invalid-date");
  if (!Number.isFinite(date.getTime()) || date.getUTCFullYear() < 1900 || date.getTime() > Date.now() + 300000) fail("invalid-date");
  return Timestamp.fromDate(date);
}
function month(date: Timestamp, zone: unknown): string {
  if (typeof zone !== "string") fail("profile-time-zone", "failed-precondition");
  try {
    const parts = new Intl.DateTimeFormat("en", {timeZone: zone, year: "numeric", month: "2-digit"}).formatToParts(date.toDate());
    return `${parts.find((p) => p.type === "year")!.value}-${parts.find((p) => p.type === "month")!.value}`;
  } catch { return fail("profile-time-zone", "failed-precondition"); }
}
type DebtOperation = Operation & Data & {debtAccountId: string; principalDeltaMinor: number; chargesDeltaMinor: number};
export type DebtResult = {requestId: string; accountId: string; operationIds: string[]; overLimit: boolean};

/** Online-only authenticated command boundary for debt operations. */
export async function executeDebtCommand(db: Firestore, uid: string | undefined, payload: unknown,
  policy: {enabled: boolean} = {enabled: false}): Promise<DebtResult> {
  if (!uid || !validId(uid)) fail("session-expired", "unauthenticated");
  if (!policy.enabled) fail("feature-disabled", "failed-precondition");
  const input = object(payload);
  const requestId = id(input.requestId);
  if (!/^[A-Za-z0-9_-]{8,100}$/.test(requestId)) fail("invalid-request");
  const expectedGeneration = input.expectedGeneration;
  if (!Number.isSafeInteger(expectedGeneration) || Number(expectedGeneration) < 0) fail("generation-required", "failed-precondition");
  const digest = createHash("sha256").update(JSON.stringify(canonical(input))).digest("hex");
  const root = db.doc(`users/${uid}`);
  return db.runTransaction(async (tx) => {
    const profile = (await tx.get(root)).data();
    if (!profile) fail("profile-missing", "failed-precondition");
    if (profile.resetStatus === "resetting") fail("user-resetting", "failed-precondition");
    const generation = Number.isSafeInteger(profile.dataGeneration) ? profile.dataGeneration as number : 0;
    if (generation !== expectedGeneration) fail("stale-generation", "failed-precondition");
    const receiptRef = root.collection("debtCommands").doc(requestId);
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data()!.digest !== digest) fail("request-conflict", "already-exists");
      return receipt.data()!.result as DebtResult;
    }
    const now = FieldValue.serverTimestamp();
    const action = input.action;
    const creating = action === "create";
    const accountId = creating ? `debt_${requestId}` : id(input.accountId);
    const accountRef = root.collection("accounts").doc(accountId);
    const existing = (await tx.get(accountRef)).data();
    let account: Data;
    let createAccount = false;
    if (creating) {
      only(input, ["requestId", "expectedGeneration", "action", "name", "product", "currency", "referenceAt", "principalMinor", "chargesMinor", "debtMinor", "limitMinor", "creditor", "lastFour", "statementClosingDay", "paymentDueDay", "mode", "bankAccountId", "description"]);
      if (existing) fail("account-exists", "already-exists");
      if (!["creditCard", "bankLoan", "personalLoan"].includes(String(input.product))) fail("invalid-product");
      if (!validCurrency(input.currency)) fail("invalid-currency");
      const currency = input.currency;
      const card = input.product === "creditCard";
      const principal = card ? 0 : amount(input.principalMinor, currency);
      const charges = card ? 0 : amount(input.chargesMinor, currency);
      if (card && (input.principalMinor !== undefined || input.chargesMinor !== undefined)) fail("invalid-components");
      if (!card && input.debtMinor !== undefined) fail("invalid-components");
      const debt = card ? amount(input.debtMinor, currency, true) : amount(principal + charges, currency);
      if (input.mode !== "existing" && input.mode !== "received") fail("invalid-opening-mode");
      if (input.mode === "received" && (card || charges !== 0 || principal <= 0)) fail("invalid-disbursement");
      const opening = input.mode === "received" ? 0 : debt;
      account = {name: text(input.name, 80, true), type: input.product, nature: "debt", currency,
        referenceAt: instant(input.referenceAt), openingBalanceMinor: 0 - opening, currentBalanceMinor: 0 - opening,
        openingPrincipalMinor: input.mode === "received" ? 0 : principal,
        openingChargesMinor: input.mode === "received" ? 0 : charges,
        principalMinor: input.mode === "received" ? 0 : principal, chargesMinor: input.mode === "received" ? 0 : charges,
        includeInDashboard: true, status: "active", dataGeneration: generation, createdAt: now, updatedAt: now};
      if (input.limitMinor !== undefined) {
        if (!card) fail("invalid-limit");
        account.limitMinor = amount(input.limitMinor, currency);
      }
      if (input.creditor !== undefined) account.creditor = text(input.creditor, 120);
      if (input.lastFour !== undefined) {
        if (!card || typeof input.lastFour !== "string" || !/^\d{4}$/.test(input.lastFour)) fail("invalid-last-four");
        account.lastFour = input.lastFour;
      }
      if (input.statementClosingDay !== undefined) {
        const value = input.statementClosingDay;
        if (!card || (value !== null && (!Number.isSafeInteger(value) || Number(value) < 1 || Number(value) > 31))) fail("invalid-billing-day");
        if (value !== null) account.statementClosingDay = value;
      }
      if (input.paymentDueDay !== undefined && input.paymentDueDay !== null) {
        const value = input.paymentDueDay;
        if (!Number.isSafeInteger(value) || Number(value) < 1 || Number(value) > 31) fail("invalid-billing-day");
        account.paymentDueDay = value;
      }
      createAccount = true;
    } else {
      if (!existing || existing.nature !== "debt") fail("account-not-found", "not-found");
      if (existing.status !== "active") fail("account-inactive", "failed-precondition");
      account = {...existing};
    }
    const currency = account.currency as string;
    const card = account.type === "creditCard";
    const operations: DebtOperation[] = [];
    const extraWrites: Array<() => void> = [];
    const refundAmounts = new Map<string, number>();
    const refundAmount = async (operationId: string) => {
      if (!refundAmounts.has(operationId)) refundAmounts.set(operationId, checkedInteger((await tx.get(root.collection("debtRefunds").doc(operationId))).data()?.amountMinor ?? 0));
      return refundAmounts.get(operationId)!;
    };
    const base = (data: Data, kind: string, type: Operation["type"], value: number, occurredAt: Timestamp): DebtOperation => ({
      type, amountMinor: value, currency, monthKey: month(occurredAt, profile.timeZone), occurredAt,
      description: data.description === undefined ? "" : text(data.description, 500), status: "confirmed",
      dataGeneration: generation,
      idempotencyKey: `debt_${requestId}_${operations.length}`, debtCommandId: requestId,
      debtAccountId: accountId, debtKind: kind, principalDeltaMinor: 0, chargesDeltaMinor: 0,
      createdAt: now, updatedAt: now,
    });
    const at = (value: unknown): Timestamp => {
      const timestamp = instant(value);
      if (!(account.referenceAt instanceof Timestamp) || timestamp.toMillis() < account.referenceAt.toMillis()) fail("before-opening", "failed-precondition");
      return timestamp;
    };
    const bank = async (value: unknown, occurredAt: Timestamp) => {
      const bankId = id(value);
      const data = (await tx.get(root.collection("accounts").doc(bankId))).data();
      if (!data || data.status !== "active" || (data.nature !== undefined && data.nature !== "money") || data.currency !== currency) fail("bank-incompatible", "failed-precondition");
      if (data.referenceAt instanceof Timestamp && occurredAt.toMillis() < data.referenceAt.toMillis()) fail("before-opening", "failed-precondition");
      return bankId;
    };
    const category = async (value: unknown) => {
      const categoryId = id(value);
      const data = (await tx.get(root.collection("categories").doc(categoryId))).data();
      if (!data || data.type !== "expense" || data.isArchived === true) fail("category-incompatible", "failed-precondition");
      return categoryId;
    };
    const budget = async (data: Data, operation: DebtOperation) => {
      if (data.budgetId === undefined && data.budgetItemId === undefined) return;
      const budgetId = id(data.budgetId), itemId = id(data.budgetItemId);
      const budgetRef = root.collection("budgets").doc(budgetId);
      const [parent, child] = await Promise.all([tx.get(budgetRef), tx.get(budgetRef.collection("items").doc(itemId))]);
      const plan = parent.data(), item = child.data();
      if (!plan || !item || plan.status === "archived" || item.status === "archived" || plan.monthKey !== operation.monthKey || plan.flowType !== "expense" || plan.categoryId !== operation.categoryId || plan.currency !== currency) fail("budget-incompatible", "failed-precondition");
      operation.budgetId = budgetId; operation.budgetItemId = itemId;
    };
    const linkCommitment = async (data: Data, paymentId: string, amountMinor: number) => {
      if (data.commitmentId === undefined && data.commitmentMonth === undefined) return;
      if (data.commitmentId === undefined || data.commitmentMonth === undefined) fail("commitment-reference-required");
      const commitmentId = id(data.commitmentId);
      if (typeof data.commitmentMonth !== "string" || !/^\d{4}-(0[1-9]|1[0-2])$/.test(data.commitmentMonth)) fail("commitment-month-invalid");
      const commitmentRef = root.collection("debtCommitments").doc(commitmentId);
      const plan = (await tx.get(commitmentRef)).data();
      if (!plan || plan.status !== "active" || plan.debtAccountId !== accountId || plan.currency !== currency ||
          data.commitmentMonth < String(plan.firstDueMonth) || (plan.lastDueMonth && data.commitmentMonth > String(plan.lastDueMonth)) ||
          commitmentPaused(plan, data.commitmentMonth)) fail("commitment-incompatible", "failed-precondition");
      const occurrence = await tx.get(commitmentRef.collection("occurrences").doc(`${commitmentId}_${data.commitmentMonth}`));
      if (occurrence.data()?.skipped === true) fail("commitment-occurrence-skipped", "failed-precondition");
      const linkRef = root.collection("debtPaymentLinks").doc(paymentId);
      if ((await tx.get(linkRef)).exists) fail("payment-already-linked", "already-exists");
      extraWrites.push(() => tx.create(linkRef, {paymentId, commitmentId, monthKey: data.commitmentMonth,
        amountMinor, currency, dataGeneration: generation, createdAt: now}));
      extraWrites.push(() => tx.set(commitmentRef.collection("occurrences").doc(`${commitmentId}_${data.commitmentMonth}`),
        {monthKey: data.commitmentMonth, paymentIds: FieldValue.arrayUnion(paymentId), updatedAt: now, dataGeneration: generation}, {merge: true}));
    };
    const build = async (data: Data) => {
      only(data, ["requestId", "expectedGeneration", "accountId", "action", "occurredAt", "amountMinor", "bankAccountId", "categoryId", "description", "principalMinor", "previousChargesMinor", "newChargesMinor", "budgetId", "budgetItemId", "originalOperationId", "targetDebtMinor", "targetPrincipalMinor", "targetChargesMinor", "paymentId", "commitmentId", "commitmentMonth"]);
      const occurredAt = at(data.occurredAt);
      const kind = String(data.action);
      if (["purchase", "charge"].includes(kind)) {
        if (kind === "purchase" && !card) fail("card-required");
        const value = amount(data.amountMinor, currency);
        if (value === 0) fail("invalid-amount");
        const operation = base(data, kind, "expense", value, occurredAt);
        operation.accountId = accountId; operation.categoryId = await category(data.categoryId);
        if (!card) operation.chargesDeltaMinor = value;
        await budget(data, operation); operations.push(operation);
      } else if (kind === "disburse") {
        if (card) fail("loan-required");
        const value = amount(data.amountMinor, currency);
        if (!value) fail("invalid-amount");
        const operation = base(data, kind, "transfer", value, occurredAt);
        operation.sourceAccountId = accountId; operation.destinationAccountId = await bank(data.bankAccountId, occurredAt);
        operation.principalDeltaMinor = value; operations.push(operation);
      } else if (kind === "pay") {
        const total = amount(data.amountMinor, currency);
        if (!total) fail("invalid-amount");
        const bankId = await bank(data.bankAccountId, occurredAt);
        const firstOperationIndex = operations.length;
        if (card) {
          if ([data.principalMinor, data.previousChargesMinor, data.newChargesMinor].some((v) => v !== undefined)) fail("invalid-components");
          const operation = base(data, kind, "transfer", total, occurredAt);
          operation.sourceAccountId = bankId; operation.destinationAccountId = accountId; operations.push(operation);
        } else {
          // Every component is mandatory, including explicit zeroes. Never infer capital.
          const principal = amount(data.principalMinor, currency), charges = amount(data.previousChargesMinor, currency), fresh = amount(data.newChargesMinor, currency);
          if (principal + charges + fresh !== total) fail("payment-split-required");
          if (principal + charges) {
            const operation = base(data, kind, "transfer", principal + charges, occurredAt);
            operation.paymentId = typeof data.paymentId === "string" ? id(data.paymentId) : String(data.requestId);
            operation.sourceAccountId = bankId; operation.destinationAccountId = accountId;
            operation.principalDeltaMinor = -principal; operation.chargesDeltaMinor = -charges; operations.push(operation);
          }
          if (fresh) {
            const operation = base(data, "newChargePaid", "expense", fresh, occurredAt);
            operation.paymentId = typeof data.paymentId === "string" ? id(data.paymentId) : String(data.requestId);
            operation.accountId = bankId; operation.categoryId = await category(data.categoryId);
            // Counterparty references keep all components discoverable by the
            // existing account filter; only accountId has a ledger effect here.
            operation.sourceAccountId = bankId; operation.destinationAccountId = accountId;
            await budget(data, operation); operations.push(operation);
          }
        }
        const paymentId = typeof data.paymentId === "string" ? id(data.paymentId) : String(input.requestId);
        if (data.paymentId === undefined) extraWrites.push(() => tx.create(root.collection("debtPayments").doc(paymentId), {
          paymentId, debtAccountId: accountId, bankAccountId: bankId, amountMinor: total,
          currency, occurredAt, status: "allocated", operationIds: operations.slice(firstOperationIndex).map((operation) => operation.idempotencyKey),
          dataGeneration: generation, createdAt: now,
        }));
        await linkCommitment(data, paymentId, total);
      } else if (kind === "payUnallocated") {
        if (card) fail("loan-required");
        const total = amount(data.amountMinor, currency);
        if (!total) fail("invalid-amount");
        const bankId = await bank(data.bankAccountId, occurredAt);
        const operation = base(data, kind, "unallocatedDebtPayment", total, occurredAt);
        operation.accountId = bankId;
        operation.sourceAccountId = bankId;
        operation.destinationAccountId = accountId;
        operation.paymentId = String(data.requestId);
        operation.allocationStatus = "unallocated";
        operations.push(operation);
        extraWrites.push(() => tx.create(root.collection("debtPayments").doc(String(data.requestId)), {
          paymentId: String(data.requestId), debtAccountId: accountId, bankAccountId: bankId,
          amountMinor: total, currency, occurredAt, operationId: operation.idempotencyKey,
          status: "unallocated", dataGeneration: generation, createdAt: now,
        }));
        await linkCommitment(data, String(data.requestId), total);
      } else if (kind === "refund") {
        if (!card) fail("card-required");
        const originalId = id(data.originalOperationId);
        const original = (await tx.get(root.collection("operations").doc(originalId))).data();
        if (!original || original.debtAccountId !== accountId || original.debtKind !== "purchase" || original.projectionDirection === -1 || original.type !== "expense") fail("purchase-required", "failed-precondition");
        const reversed = await tx.get(root.collection("debtReversals").doc(id(original.debtCommandId)));
        if (reversed.exists) fail("purchase-reversed", "failed-precondition");
        if (!(original.occurredAt instanceof Timestamp) || occurredAt.toMillis() < original.occurredAt.toMillis()) fail("invalid-refund-date");
        const value = amount(data.amountMinor, currency);
        const tracker = root.collection("debtRefunds").doc(originalId);
        const refunded = await refundAmount(originalId);
        if (!value || value + refunded > checkedInteger(original.amountMinor)) fail("refund-exceeds-purchase", "failed-precondition");
        const operation = base(data, kind, "expenseRefund", value, occurredAt);
        operation.accountId = accountId; operation.categoryId = id(original.categoryId); operation.originalOperationId = originalId;
        // Keep historical references, even archived, but never rewrite a prior month's budget.
        if (original.budgetId && operation.monthKey === original.monthKey) { operation.budgetId = id(original.budgetId); operation.budgetItemId = id(original.budgetItemId); }
        extraWrites.push(() => tx.set(tracker, {amountMinor: refunded + value}));
        refundAmounts.set(originalId, refunded + value);
        operations.push(operation);
      } else if (kind === "adjust") {
        let delta: number;
        const operation = base(data, kind, "debtAdjustment", 0, occurredAt);
        operation.accountId = accountId;
        if (card) delta = -amount(data.targetDebtMinor, currency, true) - checkedInteger(account.currentBalanceMinor);
        else {
          const principal = amount(data.targetPrincipalMinor, currency), charges = amount(data.targetChargesMinor, currency);
          amount(principal + charges, currency);
          operation.principalDeltaMinor = principal - checkedInteger(account.principalMinor);
          operation.chargesDeltaMinor = charges - checkedInteger(account.chargesMinor);
          delta = -(principal + charges) - checkedInteger(account.currentBalanceMinor);
        }
        operation.balanceDeltaMinor = delta; operation.amountMinor = Math.abs(delta);
        operation.previousBalanceMinor = account.currentBalanceMinor;
        operation.targetBalanceMinor = checkedInteger(account.currentBalanceMinor) + delta;
        operation.previousPrincipalMinor = account.principalMinor;
        operation.targetPrincipalMinor = checkedInteger(account.principalMinor) + operation.principalDeltaMinor;
        operation.previousChargesMinor = account.chargesMinor;
        operation.targetChargesMinor = checkedInteger(account.chargesMinor) + operation.chargesDeltaMinor;
        if (delta || operation.principalDeltaMinor || operation.chargesDeltaMinor) operations.push(operation);
      } else fail("invalid-action");
    };
    if (creating && input.mode === "received") {
      await build({action: "disburse", occurredAt: input.referenceAt, bankAccountId: input.bankAccountId, amountMinor: input.principalMinor, description: input.description});
    } else if (!creating && action === "allocatePayment") {
      only(input, ["requestId", "expectedGeneration", "action", "accountId", "paymentId", "amountMinor", "occurredAt", "principalMinor", "previousChargesMinor", "newChargesMinor", "categoryId", "budgetId", "budgetItemId", "description"]);
      if (card) fail("loan-required");
      const paymentId = id(input.paymentId);
      const paymentRef = root.collection("debtPayments").doc(paymentId);
      const payment = (await tx.get(paymentRef)).data();
      if (!payment || payment.debtAccountId !== accountId || payment.status !== "unallocated") fail("payment-not-unallocated", "failed-precondition");
      const originalRef = root.collection("operations").doc(id(payment.operationId));
      const original = (await tx.get(originalRef)).data();
      if (!original || original.type !== "unallocatedDebtPayment" || original.projectionDirection === -1) fail("invalid-payment-reference", "failed-precondition");
      const total = checkedInteger(payment.amountMinor);
      if (input.amountMinor !== undefined && input.amountMinor !== total) fail("payment-amount-immutable", "failed-precondition");
      const principal = amount(input.principalMinor, currency), previousCharges = amount(input.previousChargesMinor, currency), newCharges = amount(input.newChargesMinor, currency);
      if (principal + previousCharges + newCharges !== total) fail("payment-split-required");
      const reversal = {...original, idempotencyKey: `debt_${requestId}_0`, debtCommandId: requestId,
        projectionDirection: -1, reversalOf: payment.operationId, createdAt: now, updatedAt: now} as unknown as DebtOperation;
      operations.push(reversal);
      await build({
        action: "pay", occurredAt: payment.occurredAt instanceof Timestamp ? payment.occurredAt.toDate().toISOString() : input.occurredAt,
        amountMinor: total, bankAccountId: payment.bankAccountId, principalMinor: principal,
        previousChargesMinor: previousCharges, newChargesMinor: newCharges, categoryId: input.categoryId,
        budgetId: input.budgetId, budgetItemId: input.budgetItemId, description: input.description, paymentId,
      });
      extraWrites.push(() => tx.update(paymentRef, {status: "allocated", allocationRequestId: requestId,
        principalMinor: principal, previousChargesMinor: previousCharges, newChargesMinor: newCharges,
        allocatedAt: now, updatedAt: now}));
      extraWrites.push(() => tx.update(originalRef, {allocationStatus: "allocated", allocatedAt: now}));
    } else if (!creating && (action === "reverse" || action === "correct")) {
      only(input, ["requestId", "expectedGeneration", "action", "accountId", "originalRequestId", "replacement", "description"]);
      const originalId = id(input.originalRequestId);
      const originalReceipt = (await tx.get(root.collection("debtCommands").doc(originalId))).data();
      const reversalRef = root.collection("debtReversals").doc(originalId);
      if ((await tx.get(reversalRef)).exists) fail("already-reversed", "already-exists");
      if (!originalReceipt || originalReceipt.result.accountId !== accountId || !["purchase", "charge", "pay", "disburse", "refund", "adjust"].includes(originalReceipt.financialAction ?? originalReceipt.action)) fail("command-not-reversible", "failed-precondition");
      for (const originalOpId of (originalReceipt.activeOperationIds ?? originalReceipt.operationIds) as string[]) {
        const original = (await tx.get(root.collection("operations").doc(originalOpId))).data();
        if (!original || original.projectionDirection === -1) fail("invalid-original", "failed-precondition");
        if (checkedInteger((await tx.get(root.collection("debtRefunds").doc(originalOpId))).data()?.amountMinor ?? 0) !== 0) fail("purchase-has-refunds", "failed-precondition");
        const reversal = {...(original as DebtOperation), idempotencyKey: `debt_${requestId}_${operations.length}`, debtCommandId: requestId,
          projectionDirection: -1, reversalOf: originalOpId, createdAt: now, updatedAt: now} as DebtOperation;
        operations.push(reversal);
        if (original.type === "expenseRefund") {
          const purchaseId = id(original.originalOperationId);
          const refunded = await refundAmount(purchaseId);
          const remaining = refunded - checkedInteger(original.amountMinor);
          if (remaining < 0) fail("inconsistent-refund", "failed-precondition");
          refundAmounts.set(purchaseId, remaining);
          extraWrites.push(() => tx.set(root.collection("debtRefunds").doc(purchaseId), {amountMinor: remaining}));
        }
      }
      extraWrites.push(() => tx.create(reversalRef, {requestId, createdAt: now}));
      if (action === "correct") {
        const replacement = object(input.replacement);
        if (!["purchase", "charge", "pay", "disburse", "refund", "adjust"].includes(String(replacement.action))) fail("invalid-replacement");
        if (replacement.accountId !== undefined && replacement.accountId !== accountId) fail("invalid-replacement");
        // A target adjustment is relative to the state after undoing the old
        // command, not to the cache before its reversal.
        const cached = account;
        let virtualBalance = checkedInteger(account.currentBalanceMinor), virtualPrincipal = checkedInteger(account.principalMinor), virtualCharges = checkedInteger(account.chargesMinor);
        for (const operation of operations) {
          virtualBalance += calculateProjectionDeltas(undefined, operation).accounts.get(accountId) ?? 0;
          virtualPrincipal -= operation.principalDeltaMinor;
          virtualCharges -= operation.chargesDeltaMinor;
        }
        account = {...account, currentBalanceMinor: virtualBalance, principalMinor: virtualPrincipal, chargesMinor: virtualCharges};
        await build(replacement);
        account = cached;
      }
    } else if (!creating && action === "update") {
      only(input, ["requestId", "expectedGeneration", "action", "accountId", "name", "creditor", "lastFour", "limitMinor", "includeInDashboard", "statementClosingDay", "paymentDueDay"]);
      if (input.name !== undefined) account.name = text(input.name, 80, true);
      if (input.creditor !== undefined) account.creditor = text(input.creditor, 120);
      if (input.lastFour !== undefined) {
        if (!card || typeof input.lastFour !== "string" || (input.lastFour !== "" && !/^\d{4}$/.test(input.lastFour))) fail("invalid-last-four");
        account.lastFour = input.lastFour || FieldValue.delete();
      }
      if (input.limitMinor !== undefined) { if (!card) fail("invalid-limit"); account.limitMinor = input.limitMinor === null ? FieldValue.delete() : amount(input.limitMinor, currency); }
      if (Object.hasOwn(input, "statementClosingDay")) {
        const value = input.statementClosingDay;
        if (!card || (value !== null && (!Number.isSafeInteger(value) || Number(value) < 1 || Number(value) > 31))) fail("invalid-billing-day");
        account.statementClosingDay = value === null ? FieldValue.delete() : value;
      }
      if (Object.hasOwn(input, "paymentDueDay")) {
        const value = input.paymentDueDay;
        if (value !== null && (!Number.isSafeInteger(value) || Number(value) < 1 || Number(value) > 31)) fail("invalid-billing-day");
        account.paymentDueDay = value === null ? FieldValue.delete() : value;
      }
      if (input.includeInDashboard !== undefined) { if (typeof input.includeInDashboard !== "boolean") fail("invalid-visibility"); account.includeInDashboard = input.includeInDashboard; }
    } else if (!creating && action === "archive") {
      only(input, ["requestId", "expectedGeneration", "action", "accountId"]);
      if (account.currentBalanceMinor !== 0 || (!card && (account.principalMinor !== 0 || account.chargesMinor !== 0))) fail("balance-not-zero", "failed-precondition");
      account.status = "archived"; account.archivedAt = now;
    } else if (!creating) await build(input);

    if (!creating && (action === "adjust" || action === "archive")) {
      const pending = await tx.get(root.collection("debtPayments").where("debtAccountId", "==", accountId).where("status", "==", "unallocated").limit(1));
      if (!pending.empty) fail("unallocated-payment-exists", "failed-precondition");
    }
    let balance = checkedInteger(account.currentBalanceMinor), principal = checkedInteger(account.principalMinor), charges = checkedInteger(account.chargesMinor);
    for (const operation of operations) {
      parseOperation(operation);
      const delta = calculateProjectionDeltas(undefined, operation);
      balance = checkedInteger(balance + (delta.accounts.get(accountId) ?? 0));
      principal = checkedInteger(principal + operation.principalDeltaMinor * (operation.projectionDirection ?? 1));
      charges = checkedInteger(charges + operation.chargesDeltaMinor * (operation.projectionDirection ?? 1));
    }
    if (Math.abs(balance) > maximumMinor(currency) || (!card && (principal < 0 || charges < 0 || balance !== -(principal + charges)))) fail("inconsistent-components", "failed-precondition");
    const writeProjections = await prepareProjectionWrites(tx, root, operations.map((current) => ({current})), true,
      createAccount ? new Map([[accountId, account]]) : new Map());
    const operationIds = operations.map((operation) => operation.idempotencyKey as string);
    const result: DebtResult = {requestId, accountId, operationIds, overLimit: card && typeof account.limitMinor === "number" && -balance > account.limitMinor};
    writeProjections();
    if (createAccount) tx.create(accountRef, {...account, currentBalanceMinor: balance, principalMinor: principal, chargesMinor: charges});
    else {
      const {currentBalanceMinor: _balance, ...metadata} = account;
      tx.update(accountRef, {...metadata, principalMinor: principal, chargesMinor: charges, updatedAt: now});
    }
    for (const operation of operations) {
      const opId = operation.idempotencyKey as string;
      const ref = root.collection("operations").doc(opId);
      tx.create(ref, operation);
      const entries = calculateProjectionDeltas(undefined, operation).accounts;
      let index = 0;
      for (const [entryAccount, deltaMinor] of entries) {
        const entryId = `${opId}_${index++}`;
        const entry = {operationId: opId, accountId: entryAccount, deltaMinor, currency, occurredAt: operation.occurredAt, dataGeneration: generation};
        tx.create(root.collection("ledgerEntries").doc(entryId), entry);
        tx.create(ref.collection("entries").doc(entryId), entry);
      }
    }
    for (const write of extraWrites) write();
    tx.create(receiptRef, {digest, action, financialAction: action === "correct" ? object(input.replacement).action : creating && input.mode === "received" ? "disburse" : action,
      activeOperationIds: operations.filter((operation) => !operation.reversalOf).map((operation) => operation.idempotencyKey),
      result, operationIds, projectionsApplied: true, createdAt: now});
    return result;
  });
}
