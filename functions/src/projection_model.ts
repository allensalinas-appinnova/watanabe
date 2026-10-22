export type Operation = {
  type: "income" | "expense" | "transfer";
  amountMinor: number;
  currency: string;
  monthKey: string;
  categoryId?: string;
  accountId?: string;
  sourceAccountId?: string;
  destinationAccountId?: string;
  budgetId?: string;
  budgetItemId?: string;
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
  if (!["income", "expense", "transfer"].includes(String(data.type)) ||
      !["pending", "confirmed", "rejected"].includes(String(data.status)) ||
      !validCurrency(data.currency) || !validMonth(data.monthKey)) {
    throw new ProjectionError("invalid_operation");
  }
  const amount = checkedInteger(data.amountMinor);
  if (amount <= 0 || amount > maximumMinor(data.currency)) throw new ProjectionError("invalid_amount");
  if (data.type === "transfer") {
    if (!validId(data.sourceAccountId) || !validId(data.destinationAccountId) ||
        data.sourceAccountId === data.destinationAccountId) throw new ProjectionError("invalid_transfer");
  } else if (!validId(data.accountId) || !validId(data.categoryId)) {
    throw new ProjectionError("invalid_operation_reference");
  }
  if (data.budgetId !== undefined || data.budgetItemId !== undefined) {
    if (!validId(data.budgetId) || !validId(data.budgetItemId) || data.type === "transfer") {
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
    const amount = operation.amountMinor * direction;
    const account = (id: string, delta: number) =>
      accounts.set(id, checkedInteger((accounts.get(id) ?? 0) + delta));
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
      summary[operation.type] = checkedInteger(summary[operation.type] + amount);
      const signed = operation.type === "income" ? amount : -amount;
      summary.categories.set(operation.categoryId!, checkedInteger((summary.categories.get(operation.categoryId!) ?? 0) + signed));
      account(operation.accountId!, signed);
      if (operation.budgetId && operation.budgetItemId) {
        const item = `${operation.budgetId}/${operation.budgetItemId}`;
        budgetItems.set(item, checkedInteger((budgetItems.get(item) ?? 0) + amount));
      }
    }
    summaries.set(key, summary);
  };
  add(previous, -1);
  add(current, 1);
  return {accounts, summaries, budgetItems};
}
