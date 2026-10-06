# ClearBudget canonical mobile data model

The mobile application owns this model. The retired web schema is not a
compatibility constraint and no migration is planned for development data.

## Principles

- Financial amounts are integer `amountMinor` values plus an ISO currency code.
- `operations` are the source of truth; balances and monthly summaries are derived.
- A transfer is one operation with two ledger entries, never an income plus an expense.
- Budgets are monthly, category-specific, currency-specific and always itemized.
- Category IDs are stable and independent of localized labels.
- Every user-owned read and write is scoped below `users/{userId}`.

## Collections

```text
/categoryCatalog/{categoryId}
/users/{userId}
/users/{userId}/accounts/{accountId}
/users/{userId}/categories/{categoryId}
/users/{userId}/operations/{operationId}
/users/{userId}/operations/{operationId}/entries/{entryId}
/users/{userId}/ledgerEntries/{entryId}
/users/{userId}/budgets/{budgetId}
/users/{userId}/budgets/{budgetId}/items/{itemId}
/users/{userId}/monthlySummaries/{summaryId}
```

`operationId` is the validated idempotency key. `budgetId` is generated from
`monthKey`, flow type, category ID and currency, preventing duplicate budgets.

## Localization and onboarding

The global category catalog stores localized labels and country availability.
Onboarding creates a versioned per-user snapshot. Users can archive or rename
their snapshot without changing the global catalog. A later catalog version is
applied through an explicit onboarding/settings action, never silently.

## Derived data

`currentBalanceMinor`, `monthlySummaries` and budget tracking values are derived
from operations/ledger entries. Cloud Functions update caches idempotently;
reconciliation can rebuild them from the source ledger.

## Offline commands

Pending commands are stored in the local Drift database with an idempotency key,
payload, retry count and `pending/syncing/confirmed/rejected` state. A transfer
is one command and is never partially confirmed.
