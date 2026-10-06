# ClearBudget budget data model

> This document is retained as the budget-specific reference. The canonical
> mobile schema is defined in [canonical-data-model.md](canonical-data-model.md);
> the retired web model and legacy fields are not supported.

## Canonical Firestore shape

Budgets are scoped to the authenticated user and to a calendar month:

```text
/users/{userId}/budgets/{budgetId}
/users/{userId}/budgets/{budgetId}/items/{itemId}
```

The parent document contains:

| Field | Type | Rule |
| --- | --- | --- |
| `categoryId` | string | Stable category document ID, independent of localized labels. |
| `monthKey` | string | `yyyy-MM`, interpreted in the user's configured time zone. |
| `flowType` | string | `expense` or `income`. |
| `currency` | string | ISO 4217 code, for example `COP`, `MXN` or `BRL`. |
| `plannedAmountMinor` | int | Sum of item amounts in the currency's minor unit. Never negative. |
| `createdAt` / `updatedAt` | timestamp | Server timestamps. |

An item contains `description`, positive `amountMinor`, `dayOfMonth` from 1 to 31,
and server timestamps. Item writes update the parent `amount` atomically using
the previous item value, so editing or deleting an item cannot leave the plan
total unchanged.

## Tracking rules

`plannedAmountMinor` is the planned value. Actual spending or income is derived
from operations for the same `categoryId`, `flowType`, `monthKey` and currency.
Transfers are excluded from income and expense totals. `spent`, `limit`,
`category` and floating-point money are not part of the mobile schema.

## Implementation status

The Flutter domain, repository contract and Firestore data source expose the
canonical itemized budget contract. Remaining work is to connect the canonical
repository to the final presentation flow and calculate tracker values from
operations and monthly summaries.
