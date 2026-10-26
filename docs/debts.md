# Debt accounts and manual financing

Status: debt accounts, monthly payment commitments and unallocated loan
payments are implemented. The credit-card billing-day metadata change in this
iteration was deployed to `lumiomoney` through `functions:mutateDebt`; the
callable rejects unauthenticated calls. This statement does not certify the
deployment state of other debt/commitment services. No existing account is
converted or migrated.

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

Source operations use `income`, `expense`, `transfer`, `expenseRefund`,
`debtAdjustment` and `unallocatedDebtPayment`. Server-only metadata includes `debtCommandId`, `debtAccountId`,
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

Activity identifies debt-payment rows as **Card payment** or **Loan payment** from
the linked debt account, and offers a **Debt payments** classification filter. The
filter scans the complete paginated query and includes payment components, including
new charges paid with an installment, but excludes purchases, disbursements,
reconciliations and separately accrued charges. CSV retains each component's
accounting operation type and adds its payment classification; it does not add a
summable payment-total row.

The default expense category `interest_fees` (localized as “Intereses y comisiones”,
“Juros e tarifas” and “Interest and fees”) is suggested for a separately accrued
financial charge and for new charges paid in a loan installment. Capital and
previously accrued charges remain outside expenses and budget tracking. The
category is not assigned retroactively. Authenticated category-catalog sync adds
only missing defaults, preserves renamed/customized/archived categories, and
advances the catalog version without blocking app use on failure.

Home separates money, debt and card credits per currency inside the existing
customizable/private balance surface. Recorded net position is explicitly not
described as complete wealth. No currency conversion occurs.

## Monthly debt commitments and unallocated payments

`lib/features/commitments/` adds monthly plans linked to one active debt
account. A plan specifies an expected amount, first due month, due day, optional
end month and usual bank account. Due days are clamped to the final calendar
day for short months. A commitment is an intention only: it never initiates a
bank transfer or creates a payment automatically. The Plan section opens the
debt-payment list, where the user can inspect a month, create a plan, record a
payment, pause future occurrences or skip a selected month.

The two payment dimensions are independent:

| Dimension | States | Meaning |
| --- | --- | --- |
| Installment fulfillment | upcoming, due, partially paid, paid, missed, skipped or paused | How much of the expected amount has a linked payment |
| Loan allocation | allocated or unallocated | Whether the bank outflow has been distributed across principal and charges |

An unallocated payment is financially confirmed, not an outbox sync state. The
server writes an `unallocatedDebtPayment` operation and a `debtPayments` record
with status `unallocated`. It reduces the source money balance by the full
outflow, but does not change debt principal, accrued charges, budgets, or income
and expense summaries. The recorded debt balance therefore remains stale until
allocation; the interface must communicate that the financial position is
incomplete.

Later allocation preserves payment identity and original payment date. In one
transaction, the server reverses the provisional ledger effect and writes the
final principal/previous-charge/new-charge components. The net additional bank
effect is zero; new charges are recognized as expense once, while principal and
already-accrued charges are not. `mutateDebt` handles `payUnallocated` and
`allocatePayment`; `mutateDebtCommitment` handles plan creation, versioned
edits, pausing, skipping and payment linkage. Both derive the owner from Firebase
Auth, validate `dataGeneration`, and use stable `requestId` receipts.
`functions/src/debt_commands.ts` blocks debt adjustment and archive while an
unallocated payment remains.

| Current state | Event | Guard | Next state | Effects |
| --- | --- | --- | --- | --- |
| Plan absent | Create plan | Authenticated owner; active same-currency debt and optional active money account | Active plan, version 1 | Creates plan and initial version; no ledger entries |
| Active plan | Edit | Valid effective month and compatible references | Active plan, new version | Preserves the earlier version |
| Active plan | Pause/resume | Valid month boundary | Active with a pause range | Suppresses future occurrences only |
| Open installment | Skip | No linked payment exists | Skipped | Records deterministic occurrence |
| Open installment | Link payment | Same debt/currency; payment not linked; month in plan range | Linked installment | Adds a stable link; creates no financial operation |
| Loan payment draft | Submit without split | Valid debt, source account, currency and amount | Confirmed, allocation unallocated | Debits money only; does not update debt or expense projections |
| Unallocated payment | Allocate | Components sum to original outflow; generation is current | Confirmed, allocation allocated | Reverses provisional effect and posts components atomically |

Backend callable behavior is covered by
`functions/test/debt_commitments_callable_test.mjs` and the unallocated payment
acceptance scenario in `functions/test/debt_commands_test.mjs`. Month-end and
occurrence status behavior is covered in
`test/features/commitments/domain/debt_commitment_test.dart`. This working tree
currently includes the Plan debt-payment screen, Home summary, loan allocation
choice and Coach pending-allocation entry. Not yet qualified: complete Android
and iOS user-flow E2E, edit-from-UI/version selection for historical months,
UI linking of an existing payment, complete historical Coach review query,
cross-month report/CSV reconciliation, and automated/device tests of the shared
debt/Coach reminder schedule.

The commitment form permits opting into local reminders. The current scheduler
includes debt due-date notices in the same replacement schedule as Coach,
using the profile time zone at 09:00 on the day before and due date. Fully paid
occurrences are omitted; tapping a reminder opens that month in Plan. Notices
remain subject to local permission, device pause, app refresh and OS limits.
The debt-specific schedule is not yet independently covered by automated or
device-delivery tests.

## Verification and activation

### Current qualification (2026-10-26)

`flutter analyze` is clean and all 340 Flutter tests pass. The Android
integration test `integration_test/debt_commitment_flow_test.dart` passed against
Auth, Firestore and Functions Emulator in `demo-clearbudget`. It created a
synthetic COP 20,000,000 loan and COP 2,400,000 monthly commitment, recorded the
payment without allocation, and then allocated COP 2,000,000 to principal and
COP 400,000 to new charges. The bank remained at COP 2,600,000 after allocation,
the principal became COP 18,000,000, and the monthly expense was COP 400,000.
This test exercises Firebase-backed repositories/callables, not the full screen
interaction flow.

`bash tool/run_debt_tests.sh` passes the debt/projection/audit, Firestore Rules
and callable suites. `flutter build ios --simulator --no-codesign` and
`flutter build web` both succeeded; Android debug was built and installed by the
integration test. No iOS user-flow E2E or real notification-delivery test was
run.

Deployment to `lumiomoney` completed on 2026-10-26 for `mutateDebt`,
`mutateDebtCommitment`, `processOperation` and Firestore Rules. The ready
Cloud Run revisions are `mutatedebt-00007-kiq`,
`mutatedebtcommitment-00003-sir` and `processoperation-00009-miv`. The new
callable's Cloud Run invoker check was disabled to match the existing Firebase
callables; its handler still requires Firebase Auth. An unauthenticated callable
request returned HTTP 401 `UNAUTHENTICATED` (`commitment-session-expired`). No
authenticated financial command was sent to the real project and no real
financial operation was created. The end-to-end financial evidence above is
from `demo-clearbudget` only.

### Historical rollout evidence (2026-10-22 to 2026-10-23)

The following paragraphs are retained as historical evidence from the earlier
debt-account rollout. They do not describe deployment state or qualification of
monthly commitments in the current checkout.

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
Auth guard. At that historical time, the deployed environment had
`DEBTS_ENABLED=false`. That state was later superseded in source: `functions/src/index.ts`
now calls `executeDebtCommand(..., {enabled: true})`; do not treat the 2026-10-22
setting as current. The deployed Rules backup from before that rollout is in
ignored `.local/firebase-deployments/`.

At that historical time, the Android release APK build was blocked because no release signing
`storeFile` is configured. The emulator debug build and E2E pass; no release
keystore was generated. Re-check current signing configuration before relying
on this as the current build status.

Relevant checks:

```sh
flutter analyze
flutter test
bash tool/run_debt_tests.sh
E2E_TEST_FILE=integration_test/debt_flow_test.dart bash tool/run_emulator_e2e.sh emulator-5554
```

All automated financial tests require `demo-clearbudget`. The development
callable currently invokes the debt command as enabled. Local Node 26 may be selected by Emulator when
Node 22 is unavailable; deployed Functions target Node 22. Do not equate this
with Node-22-local qualification.

Backend tests cover purchases, financing, component payments, partial/cross-month
refunds, archived budgets, request replay/conflict, corrections, transaction rollback,
concurrency with legacy projections, audit reconstruction and alternate-path denial.
Flutter tests cover position/totals, grouping, locales, compact creation and stable
retry. The native integration test uses synthetic Auth/Firestore/Functions data.
Passing unit/widget tests is not proof of device E2E or visual acceptance.

Current worktree qualification (2026-10-23): `flutter analyze` is clean and all
329 Flutter tests pass. `tool/run_debt_tests.sh` passes 30 debt/projection/audit
tests, 19 Firestore Rules tests, and 2 callable/trigger tests. The expanded Android
debt-flow E2E builds and reaches emulator-backed flows but currently fails in its
widget interaction sequence before completing all scenarios; it is not a passing
qualification. The live catalog seed was attempted but could not authenticate
because Google Application Default Credentials are missing/expired. No live
catalog update, Rules deployment, or Functions deployment occurred in this run.

Deploy only affected Functions (`mutateDebt`, `processOperation`,
`adjustAccountBalances`, `mutateEmailImport`) and Firestore rules after validation.
No new index is required by the implemented queries. Preserve the deployed rules
before release in ignored `.local/firebase-deployments/`. Verify actual callable
Auth responses, not just deployment status. Never create real financial records
as a smoke test without a separate explicit confirmation.

Before releasing the new commitment command, install and qualify a compatible
client. No `DEBTS_ENABLED` client compile-time gate was found in the current
source. Older clients cannot interpret new source types. When disabling server commands later, retain
the compatible trigger, rules and readers: reverting to an old reader/trigger
after debt records exist is not a safe rollback. No mass migration, repair,
automatic interest, amortization, recurring installments, FX, lending-to-others
or Gmail debt import is included.

### Credit-card billing-cycle planning

Cards may optionally store `statementClosingDay` and `paymentDueDay` as nominal
calendar days from 1 to 31. Bank and personal loans may also store
`paymentDueDay`; statement closing day remains card-only. These dates are
planning references: confirm the definitive due date with the lender or on the
statement. Short months clamp the nominal day to their final calendar day;
holidays and weekends are not shifted.

The debt detail displays configured payment days; cards also display the
statement closing day and link to the existing debt-payment commitment form.
For a new commitment, the payment day and next nominal date are suggested using
the profile time zone. Users can change the month and day independently, and an
explicit action restores the selected debt's suggestion. The amount remains
user-entered. Saving or editing these dates does not create or modify a
commitment, occurrence, payment, or reminder; each commitment keeps its own
schedule. Omitted fields are preserved and explicit `null` clears only the
specified field.
