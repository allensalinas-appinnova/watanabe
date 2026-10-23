# Debt accounts and manual financing

Status: implementation in the working tree based on `e23b6ba`, alongside
pre-existing Coach and email-import work. Real-project activation remains gated
on updated-client qualification. No existing account is converted or migrated.

## Financial contract

`accounts.nature` is `money` or `debt`; absent means legacy money, even when its
balance is negative. Debt products are `creditCard`, `bankLoan`, `personalLoan`.
Account balances retain ledger signs: borrowing is negative, a card credit balance
is positive. Loans additionally track nonnegative principal and accrued unpaid
charges, whose sum must equal the negative ledger balance.

Debt creation records a reference timestamp and signed opening balance. Existing
debt does not move cash. Creating a newly received loan opens at zero and records
a disbursement in the same transaction. Product, nature, currency and reference
date cannot be changed through metadata updates. No full card number, CVV or
bank credential is accepted; optional `lastFour` is exactly four digits.

| Command | Ledger effect | Income/expense effect |
| --- | --- | --- |
| Card purchase | Reduce card balance | Expense on purchase date |
| Loan disbursement | Reduce loan; increase money | Neither |
| Card payment | Reduce money; increase card balance | Neither |
| Loan principal / previously accrued charge paid | Reduce money and the corresponding liability component | Neither |
| New charge paid in installment | Reduce money, no new liability | Expense once |
| Accrued unpaid charge | Reduce liability balance; increase unpaid charges | Expense once |
| Refund | Increase card balance, including credit balances | Reduce expense in refund month |
| Reconciliation | Audited liability/component delta | Neither |

Loan installments require all three explicit components, including zeroes. Their
sum must equal the bank outflow. The server does not infer capital from an unknown
allocation. Card payments do not require purchase-level allocation. Limits are
warnings, not hard restrictions on recording real purchases. Only zero-balance
obligations can be archived; archived records and their operations remain readable.

Refunds reference a purchase, cannot precede it, and cannot cumulatively exceed
its amount. Only same-month refunds reverse the original budget-item actual,
including archived references. A later-month refund reduces that later month's
expense without rewriting the original month's budget. Corrections to a refunded
purchase require reversing its refunds first.

## Command and transaction model

`functions/src/debt_commands.ts:executeDebtCommand` implements authenticated
`mutateDebt` in `us-central1`. The UID comes exclusively from Firebase Auth.
Commands require a stable request ID and a digest of their canonical contents.
An identical replay returns the original result; changed contents conflict after
the first successful commit. Failed transactions leave no receipt or partial work.

The server atomically writes source operations, both entry collections, balances,
principal/charge components, monthly summaries, budget-item actuals, refund/reversal
markers and the command receipt. `prepareProjectionWrites` shares the projection
calculation with the legacy asynchronous trigger. `processOperation` skips a debt
operation only after verifying membership in its server-owned applied receipt.
Legacy money operations retain the asynchronous processing path.

Corrections preserve original operations. A new command adds inverse operations
and replacements atomically. Receipt `activeOperationIds` tracks only replacement
rows, allowing repeated corrections without reactivating older reversals. Undoing
a command cannot leave negative principal or unpaid charges. Adjustments store
previous and target signed balances and component snapshots.

Source operations use `income`, `expense`, `transfer`, `expenseRefund` and
`debtAdjustment`. Server-only metadata includes `debtCommandId`, `debtAccountId`,
`debtKind`, component deltas, `projectionDirection` and reversal/refund references.
The read-only projection audit reconstructs debt balances and loan components
from opening values and source operations; it does not trust cached components.

## States, access and recovery

The persisted obligation lifecycle is active to archived; financial commands do
not queue offline. Form drafts live in the current route, not the financial outbox.

| State | Event and guard | Next state | Side effects / recovery |
| --- | --- | --- | --- |
| Draft | Review valid fields | Reviewing | No financial writes |
| Reviewing | Cancel | Draft | Preserve selection and command ID |
| Reviewing | Confirm with Auth and enabled feature | Saving | One server transaction |
| Saving | Failure or lost response | Draft with error | Preserve fields and request ID; retry |
| Saving | Successful receipt | Saved | Refresh account/report reads; return to origin |
| Active | Financial command passes component/date/reference checks | Active | Atomic ledger and projections |
| Active | Archive with exactly zero balance and components | Archived | Retain history; prohibit further commands |

Owners can read debt accounts and operations. Clients cannot create or update
debt accounts, receipts, refund counters or reversal markers. Generic operation,
transfer, adjustment and Gmail approval paths reject liability accounts. Confirmed
debt operations cannot be rejected/deleted through the generic operation editor.
Firestore rules are a reviewed-and-tested prototype, not a broad-release security
certification. No App Check change is included.

## Flutter and design

The `debts` feature contains domain command/split/position models, an injectable
callable service/repository returning `Either<Failure, ...>`, Riverpod composition,
and contextual forms/detail screens. Form retry never adds debt commands to Drift.
An expense on a card routes through `mutateDebt`; money accounts keep their offline
behavior. Loan payments, charges, refunds, adjustments and metadata have separate
actions and a review step.

The user authorized Codex to define the new design. It extends the verified
canonical Accounts frame `329:82` in `07 P0 Screens` using existing cards, typography,
buttons and contextual headers; it does not modify Figma or `00 Current Baseline`.
Accounts group money, cards and loans without adding a tab. Detail remains a
financial consultation with tabs and no global FAB. Forms are full-screen tasks.
`debt_previews.dart` provides isolated creation previews, including compact text.

Activity groups linked command rows and exports only their source components,
not another summable parent total. CSV adds command, principal, charge and reversal
columns and signed refund values. Totals, budget tracking and weekly category
metrics subtract refunds/reversals and exclude financing, principal and adjustments.
Expense pagination includes refunds without exceeding Firestore's account-filter
disjunction limit. Adjacent payment components are kept together at page boundaries.

Home separates money, debt and card credits per currency inside the existing
customizable/private balance surface. Recorded net position is explicitly not
described as complete wealth. No currency conversion occurs.

## Verification and activation

Qualification run on 2026-10-22: `flutter analyze` reported no issues and all
298 Flutter tests passed. The debt backend suite passed 30 command/projection/
audit tests, 18 Firestore Rules tests and 2 callable/trigger tests. Android
Auth/Firestore/Functions Emulator E2E passed for card creation, purchase and
payment, confirming payment did not duplicate the expense. The updated debug
client launched on the connected iPhone and reported no Dart runtime errors.
No real financial operation was created.

The Firestore Rules deployment to `lumiomoney` completed. `processOperation`,
`adjustAccountBalances` and `mutateEmailImport` were updated in the same rollout.
The initial `mutatedebt-00001-zir` and `mutatedebt-00003-zox` revisions failed
their startup health checks. A controlled redeployment on 2026-10-22 created
`mutatedebt-00004-leh`, which is now both `latestCreatedRevisionName` and
`latestReadyRevisionName`; `Ready`, `ConfigurationsReady` and `RoutesReady` are
all true. An unauthenticated HTTPS POST returned callable JSON `401
UNAUTHENTICATED` with `debt-session-expired`, confirming the endpoint reaches the
Auth guard. The deployed environment remains `DEBTS_ENABLED=false`. This resolves
the Cloud Run readiness blocker, but does not qualify an authenticated financial
command or authorize enabling debt creation. Keep it disabled until the updated
client is installed and qualified. The deployed Rules backup from before this
release is in ignored `.local/firebase-deployments/`.

The Android release APK build is currently blocked because no release signing
`storeFile` is configured. The emulator debug build and E2E pass; no release
keystore was generated. Keep debt creation disabled until a signed client is
available and qualified.

Relevant checks:

```sh
flutter analyze
flutter test
bash tool/run_debt_tests.sh
E2E_TEST_FILE=integration_test/debt_flow_test.dart bash tool/run_emulator_e2e.sh emulator-5554
```

All automated financial tests require `demo-clearbudget`. Only that exact project
inside Functions Emulator enables the debt server automatically. Real projects
default to `DEBTS_ENABLED=false`. Local Node 26 may be selected by Emulator when
Node 22 is unavailable; deployed Functions target Node 22. Do not equate this
with Node-22-local qualification.

Backend tests cover purchases, financing, component payments, partial/cross-month
refunds, archived budgets, request replay/conflict, corrections, transaction rollback,
concurrency with legacy projections, audit reconstruction and alternate-path denial.
Flutter tests cover position/totals, grouping, locales, compact creation and stable
retry. The native integration test uses synthetic Auth/Firestore/Functions data.
Passing unit/widget tests is not proof of device E2E or visual acceptance.

Deploy only affected Functions (`mutateDebt`, `processOperation`,
`adjustAccountBalances`, `mutateEmailImport`) and Firestore rules after validation.
No new index is required by the implemented queries. Preserve the deployed rules
before release in ignored `.local/firebase-deployments/`. Verify actual callable
Auth responses, not just deployment status. Never create real financial records
as a smoke test without a separate explicit confirmation.

Before activation, install and qualify the updated client. Client creation is
also hidden unless built with `--dart-define=DEBTS_ENABLED=true`. Older clients
cannot interpret new source types. When disabling server commands later, retain
the compatible trigger, rules and readers: reverting to an old reader/trigger
after debt records exist is not a safe rollback. No mass migration, repair,
automatic interest, amortization, recurring installments, FX, lending-to-others
or Gmail debt import is included.
