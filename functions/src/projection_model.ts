export type Operation = {
  type: "income" | "expense" | "transfer" | "expenseRefund" | "debtAdjustment";
  amountMinor: number;
  currency: string;
  monthKey: string;
  categoryId?: string;
  accountId?: string;
  sourceAccountId?: string;
  destinationAccountId?: string;
  budgetId?: string;
  budgetItemId?: string;
  // These fields are server-only; security rules forbid them on client writes.
  projectionDirection?: 1 | -1;
  balanceDeltaMinor?: number;
  dataGeneration?: number;
  status: "pending" | "confirmed" | "rejected";
};

export type SummaryDelta = {
  monthKey: string;
  currency: string;
  income: number;
  expense: number;
  transferIn: number;
  transferOut: number;
  categories: Map<string, number>;
};

export class ProjectionError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "ProjectionError";
  }
}

export function checkedInteger(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value)) {
    throw new ProjectionError("invalid_integer");
  }
  return value;
}

export function validId(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 &&
    !value.includes("/") && value !== "." && value !== "..";
}

export function validCurrency(value: unknown): value is string {
  return typeof value === "string" && /^[A-Z]{3}$/.test(value);
}

export function validMonth(value: unknown): value is string {
  return typeof value === "string" && /^\d{4}-(0[1-9]|1[0-2])$/.test(value);
}

export function maximumMinor(currency: string): number {
  return ["CLP", "COP", "JPY", "KRW", "PYG"].includes(currency) ? 1_000_000_000 : 100_000_000_000;
}

export function parseOperation(data: Record<string, unknown>): Operation {
  if (!["income", "expense", "transfer", "expenseRefund", "debtAdjustment"].includes(String(data.type)) ||
      !["pending", "confirmed", "rejected"].includes(String(data.status)) ||
      !validCurrency(data.currency) || !validMonth(data.monthKey)) {
    throw new ProjectionError("invalid_operation");
  }
  const amount = checkedInteger(data.amountMinor);
  if (amount < 0 || (amount === 0 && data.type !== "debtAdjustment") || amount > maximumMinor(data.currency) * (data.type === "debtAdjustment" ? 2 : 1)) throw new ProjectionError("invalid_amount");
  if (data.type === "transfer") {
    if (!validId(data.sourceAccountId) || !validId(data.destinationAccountId) ||
        data.sourceAccountId === data.destinationAccountId) throw new ProjectionError("invalid_transfer");
  } else if (!validId(data.accountId) || (data.type !== "debtAdjustment" && !validId(data.categoryId))) {
    throw new ProjectionError("invalid_operation_reference");
  }
  if (data.projectionDirection !== undefined && data.projectionDirection !== 1 && data.projectionDirection !== -1) throw new ProjectionError("invalid_direction");
  if (data.dataGeneration !== undefined && (!Number.isSafeInteger(data.dataGeneration) || Number(data.dataGeneration) < 0)) throw new ProjectionError("invalid_generation");
  if (data.type === "debtAdjustment" && Math.abs(checkedInteger(data.balanceDeltaMinor)) !== amount) throw new ProjectionError("invalid_adjustment_delta");
  if (data.budgetId !== undefined || data.budgetItemId !== undefined) {
    if (!validId(data.budgetId) || !validId(data.budgetItemId) || data.type === "transfer" || data.type === "debtAdjustment") {
      throw new ProjectionError("invalid_budget_reference");
    }
  }
  return data as Operation;
}

export function calculateProjectionDeltas(previous: Operation | undefined, current: Operation | undefined) {
  const accounts = new Map<string, number>();
  const summaries = new Map<string, SummaryDelta>();
  const budgetItems = new Map<string, number>();
  const add = (operation: Operation | undefined, direction: 1 | -1) => {
    if (!operation || operation.status !== "confirmed") return;
    const amount = operation.amountMinor * direction * (operation.projectionDirection ?? 1);
    const account = (id: string, delta: number) =>
      accounts.set(id, checkedInteger((accounts.get(id) ?? 0) + delta));
    if (operation.type === "debtAdjustment") {
      account(operation.accountId!, operation.balanceDeltaMinor! * direction * (operation.projectionDirection ?? 1));
      return;
    }
    const key = `${operation.monthKey}_${operation.currency}`;
    const summary = summaries.get(key) ?? {
      monthKey: operation.monthKey, currency: operation.currency,
      income: 0, expense: 0, transferIn: 0, transferOut: 0, categories: new Map<string, number>(),
    };
    if (operation.type === "transfer") {
      summary.transferIn = checkedInteger(summary.transferIn + amount);
      summary.transferOut = checkedInteger(summary.transferOut + amount);
      account(operation.sourceAccountId!, -amount);
      account(operation.destinationAccountId!, amount);
    } else {
      const flow = operation.type === "income" ? "income" : "expense";
      const financialAmount = operation.type === "expenseRefund" ? -amount : amount;
      summary[flow] = checkedInteger(summary[flow] + financialAmount);
      const signed = flow === "income" ? financialAmount : -financialAmount;
      summary.categories.set(operation.categoryId!, checkedInteger((summary.categories.get(operation.categoryId!) ?? 0) + signed));
      account(operation.accountId!, signed);
      if (operation.budgetId && operation.budgetItemId) {
        const item = `${operation.budgetId}/${operation.budgetItemId}`;
        budgetItems.set(item, checkedInteger((budgetItems.get(item) ?? 0) + financialAmount));
      }
    }
    summaries.set(key, summary);
  };
  add(previous, -1);
  add(current, 1);
  return {accounts, summaries, budgetItems};
}
