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

The existing file `Personal Finance Mobile — ClearBudget` uses
`07 P0 Screens` (`325:3059`) as the canonical design-to-code page for P0
screens and states. `00 Current Baseline` remains a comparison page for
existing screen patterns, not a competing implementation target. `06 UX
Contract` (`321:2`) records reusable UX rules and components; it does not
replace the canonical P0 screen frames. It contains:

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

Before implementing a P0 screen, compare its `00 Current Baseline` counterpart
with the canonical frame in `07 P0 Screens`. Reconcile meaningful patterns
(such as tab icons, header actions, content hierarchy, and navigation) in the
canonical frame and its prototype before changing Flutter. Record the Figma
file, page, and frame name/ID in the implementation task. Do not create a new
copy of a screen on the baseline page unless a task explicitly calls for a
baseline snapshot.

### Canonical bottom navigation

The persistent app shell has four destinations, in this order: **Inicio**
(`Icons.home_outlined`), **Actividad** (`Icons.list_alt_outlined`),
**Presupuesto** (`Icons.pie_chart_outline`), and **Cuentas**
(`Icons.account_balance_wallet_outlined`). Figma represents these with the
shared `Bottom Navigation` component on `02 Components` (`436:114`) and its
`Selected=Home|Activity|Budget|Accounts` variants. The same four icons and
labels must appear on the corresponding frames in `07 P0 Screens`; the
selected destination uses the same indicator and emphasized icon/label.
The old circle-placeholder component is retained as
`Bottom Navigation / Legacy — do not use` and is not a source of implementation
truth.

Use the bar only on routes rendered inside the persistent shell: Inicio,
Actividad, Cuentas, Presupuesto mensual/empty/success, and Seguimiento.
Full-screen root routes (for example, onboarding, operation/account forms,
budget creation and budget detail) do not show it. Category management is a
secondary route outside the shell and therefore has no bottom bar. Every
visible tab prototype hotspot must navigate to its matching canonical P0
frame; do not make a selected tab navigate to itself. Do not add header
actions unless both the action exists in Flutter and its outcome is represented
in the canonical prototype. In particular, the Flutter Home screen currently
has sign-out but `07 P0 Screens` has no login destination. Keep that action out
of the canonical Figma Home frame until a P0 login/auth destination is added;
do not route sign-out to onboarding as a substitute.

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
