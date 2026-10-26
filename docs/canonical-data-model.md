# LumioMoney canonical mobile data model

This repository owns the canonical LumioMoney model. No migration from earlier
development-only data stores is planned; existing account records without a
debt nature keep their legacy money-account meaning.

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
/users/{userId}/balanceAdjustments/{requestId}
/users/{userId}/coachDailyCheckIns/{YYYY-MM-DD}
/users/{userId}/coachWeeklyReviews/{weekStart}
/users/{userId}/debtCommands/{requestId}
/users/{userId}/debtReversals/{requestId}
/users/{userId}/debtRefunds/{operationId}
/users/{userId}/emailImportCandidates/{candidateId} (server-only)
/users/{userId}/emailImportCommands/{requestId} (server-only)
/users/{userId}/emailImportSources/{sourceId} (server-only)
/users/{userId}/emailImportReferences/{referenceId} (server-only)
```

`operationId` is the validated idempotency key. `budgetId` is generated from
`monthKey`, flow type, category ID and currency, preventing duplicate budgets.

## Localization and onboarding

The global category catalog stores localized labels and country availability.
Onboarding creates a versioned per-user snapshot. On an authenticated session,
the app non-blockingly synchronizes newly introduced defaults from the catalog;
the operation is idempotent and adds only absent categories. User-renamed,
customized, and archived categories are preserved. A failed sync does not block
normal app use and can be retried. Catalog version 2 introduced `interest_fees`;
version 3 adds the `sports`, `hobbies`, and `subscriptions` expense categories.
These updates do not relabel historical operations.

## Derived data

`currentBalanceMinor`, `monthlySummaries` and budget tracking values are derived
from operations/ledger entries. Cloud Functions update caches idempotently;
reconciliation can rebuild them from the source ledger.

## Offline commands

Pending commands are stored in the local Drift database with an idempotency key,
payload, retry count and `pending/syncing/confirmed/rejected` state. A transfer
is one command and is never partially confirmed.

## Debt commands

Debt accounts use an explicit `nature=debt`; absence of nature remains legacy
money. Signed ledger balances and nonnegative loan components are maintained
transactionally by `mutateDebt`, not by client writes or the offline outbox.
Refunds reduce expenses rather than creating income. See [debts.md](debts.md)
for the command, reversal, receipt and activation contracts.

## Other derived and workflow records

Balance adjustments, coach check-ins and weekly reviews are separate from
financial operations. They do not count as income or expense. Email-import
candidates and command/deduplication markers are server-only; the current
implementation does not connect Gmail. See [coach.md](coach.md),
[projection-audit.md](projection-audit.md) and [email-imports.md](email-imports.md)
for their validation and activation boundaries.
