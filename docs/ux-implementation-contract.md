---
title: ClearBudget UX implementation contract
summary: UX decisions, visual states, data mapping, and observability rules for the mobile beta.
---

# ClearBudget UX implementation contract

Status: proposed implementation contract for the next Flutter UX iteration.

This document translates the current canonical finance model into an interface
that is understandable to non-technical users. The existing visual language is
retained; this contract closes the interaction, state, accessibility, and
observability gaps before broader implementation.

## Evidence baseline

- The published baseline is commit `fc96aed5a33abe27840e14ad535458b0acedbf24`.
- The income/expense balance flow is covered by
  `integration_test/register_income_expense_balance_test.dart`.
- The current navigation and screen composition are in
  `lib/core/routing/app_router.dart` and `lib/features/finance/presentation/screens/`.
- The canonical financial entities and repository are documented and implemented
  under `lib/features/finance/domain/` and `lib/features/finance/data/`.
- The visual work is in the existing Figma file, page `06 UX Contract` (`321:2`),
  and does not replace the baseline screens.

## UX decisions

### Navigation

Use a persistent four-destination navigation shell when the P0 screens are
implemented:

1. Inicio
2. Actividad
3. Presupuesto
4. Cuentas

Keep “Agregar movimiento” as the primary action. Use full-screen routes for
onboarding, operations, transfers, and budget creation. Use bottom sheets only
for short selections such as account, category, or month.

### Screen states

Every feature screen must define the states that apply to it:

`loading`, `empty`, `data`, `offline`, `syncing`, `error`, `rejected`, and
`success`.

Each state has a human message, a primary action, and a secondary action when
recovery needs one. State meaning must not depend on color alone. Recoverable
errors preserve the entered form data.

### Canonical data mapping

| UI concept | Canonical source |
| --- | --- |
| Account balance | `FinanceAccount.currentBalanceMinor` |
| Income | `FinancialOperation.type == income` |
| Expense | `FinancialOperation.type == expense` |
| Transfer | `FinancialOperation.type == transfer` plus two `LedgerEntry` records |
| Monthly totals | `MonthlySummary` |
| Planned budget | Sum of `BudgetItem.amountMinor` |
| Actual budget usage | Confirmed operations filtered by month, category, type, and currency |
| Category label | User category snapshot, localized at bootstrap |
| Pending status | Durable offline queue state |

The UI must not introduce `double`, `spent`, `limit`, or a client-calculated
balance as a source of truth.

### Money, currencies, and dates

All financial values are displayed from integer minor units and formatted with
the active locale. Zero-decimal currencies include COP, CLP, JPY, KRW, and PYG;
two-decimal currencies include USD, MXN, BRL, ARS, and PEN. Show the currency
code when `$` could be ambiguous, for example `COP 100` or `BRL 100,00`.

The user time zone selected during onboarding determines `monthKey`. Dates and
month names use the active locale.

### Language and copy

Spanish is the initial experience, with equivalent Brazilian Portuguese and
English support. Use everyday verbs: “Agregar ingreso”, “Agregar gasto”, “Mover
dinero”, “Planeado”, “Gastado”, and “Disponible”. Do not expose technical terms
such as ledger, idempotency, derived summary, or backend rejection.

### Forms

Income and expense share one form in this order: type, amount, account,
category, date, optional note, review, and save. Labels remain visible, amount
uses a numeric keyboard, and defaults are safe and editable. Transfers show
source, destination, and amount before confirmation and never allow the same
account on both sides.

### Budgets

Budgets are always itemized. Creation includes month, flow type, category, one
or more items, description, amount, and expected day. Tracking uses explicit
labels: “Planeado”, “Gastado”, “Restante”, and “Excedido por”. Transfers are not
included in actual income, expense, or budget usage.

## Figma delivery contract

The existing file `Personal Finance Mobile — ClearBudget` now contains a
dedicated page `06 UX Contract` (`321:2`). It contains:

- product rules and implementation tokens;
- named component variants for `MoneyInput`, `AccountSelector`,
  `CategorySelector`, `OperationTypeSelector`, `BudgetItemRow`,
  `BudgetProgress`, `SyncStatus`, `OperationStatus`, `EmptyState`, and
  `MonthSelector`;
- corrected `Add Expense` and new `Add Income` references with a 32 px title
  inset and 24 px content inset;
- onboarding, budget creation, budget tracking, and transfer references;
- a state matrix covering loading, empty, offline, rejected, success, and
  syncing.

Figma components must retain Flutter-compatible names, document variants,
spacing, 48 px minimum touch targets, error/offline behavior, accessibility
annotations, and examples in Spanish, Portuguese, and English.

## Observability gap solution

Use one `ProductTelemetry` boundary for product events. The allowlist is:

`onboarding_completed`, `account_created`, `income_created`,
`expense_created`, `budget_created`, `transfer_created`, and `sync_rejected`.

Product events must never include amount, currency, category, description,
account name, email, UID, free text, Firestore payloads, or tokens. Technical
errors are separate from product events and are redacted before Crashlytics.
Use `debug` only for development/emulator, `warning` for recoverable failures,
and `error` for unrecoverable technical failures. If an anonymous installation
identifier is enabled, it must be reviewed against the privacy requirements
before release.

Add tests that reject disallowed financial fields in telemetry payloads. Do not
log raw exceptions or serialized domain objects.

## Implementation sequence

1. Freeze tokens and component names from `06 UX Contract`.
2. Replace independent top-level navigation with a guarded persistent shell.
3. Centralize loading, empty, offline, syncing, error, rejected, and success UI.
4. Complete localization and regional money/date formatting.
5. Apply the contract to login, onboarding, dashboard, and accounts.
6. Apply it to income, expense, transfer, category, activity, budget, and
   budget tracking flows.
7. Add widget tests for each applicable state and accessibility variant.
8. Repeat Android Emulator E2E, then validate iOS and staging separately.

## Acceptance gates

- A new user can complete onboarding without technical vocabulary.
- Income, expense, and transfer are visually distinct and semantically correct.
- A transfer is understood as money moved between own accounts and does not
  change income or expense totals.
- Budget tracking clearly separates planned, actual, remaining, and exceeded.
- Spanish, Brazilian Portuguese, and English support long text without clipping.
- Offline and rejected operations preserve user input and expose recovery.
- Product telemetry contains no financial data.
- Each new screen has widget coverage and at least one Emulator-backed E2E
  scenario before release consideration.

## Open decisions

- Confirm the exact Flutter route migration to `StatefulShellRoute` after the
  current device E2E is rerun.
- Confirm whether anonymous installation identifiers are permitted by the
  final privacy review.
- Confirm the staging Firebase project and release signing inputs before any
  real-backend validation.
