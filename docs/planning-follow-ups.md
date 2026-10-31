# Planning follow-up and the shared attention list

## Scope and state

Home, Coach and Agenda share `planningAttentionProvider`. It combines planned
expenses and debt installments in the current profile-local month, the next
seven days, and older snoozed entries whose reminder date has arrived. Expected
income remains visible in Agenda but does not create an attention task.
Financial progress and follow-up state are independent: finishing a COP 50,000
expense with COP 25,000 recorded preserves both amounts and the bank balance.

| State / command | Guard | Effect |
| --- | --- | --- |
| `open` / `completeExpense` | Expense with at least one confirmed, linked, unreversed expense | `completed`; remove from attention |
| Any / `dismiss` | Valid active source and effective occurrence | `dismissed`; preserve all financial values |
| Any / `snooze` | `remindOn` is tomorrow through today + 28 in the profile time zone | `snoozed`; hide until that local date |
| Any / `resume` | Valid source | `open`; derive pending status from the original financial records |
| `completed` / last qualifying record removed | Cancellation, reversal, correction or reassociation removes the last eligible expense | Atomically reopen, increment version, set `reason: record-changed` |

Changing only a linked expense amount preserves manual completion. A refund
reduces execution without automatically canceling the original expense. A debt
installment cannot use `completeExpense`; its payments determine coverage.
Fully covered entries leave attention automatically. Agenda's All filter keeps
completed, dismissed and snoozed entries available for inspection and resumption.

## Server and persistence

`mutatePlanningFollowUp` obtains the UID from Firebase Auth. Its typed payload
contains `action`, `requestId`, `expectedGeneration`, `expectedVersion`, `kind`,
`monthKey`, the source references (`budgetId`/`itemId` or `commitmentId`), and
`remindOn` only for snooze. Document IDs are SHA-256 hashes of structured source
references; visible Agenda identifiers retain their colons. Normalized commands
produce the receipt digest, so property order does not change replay identity.

The transaction validates ownership, current generation, source, effective debt
plan version, pause/skip state and expected follow-up version. An identical
retry returns its receipt; conflicting payload reuse or a stale version fails.
Follow-up writes affect only `planningFollowUps` and `planningFollowUpCommands`.
The financial projection and reassociation paths call `preparePlanningReopen`
inside their own transactions. Firestore rules allow only owner reads of states;
state writes and all receipt access are server-only. Recursive data reset removes
both collections, including nested records, without a new reset implementation.

Debt planning also supports `mutateDebtCommitment.editOccurrence`: an override
for one month, separately from `edit`, which versions that month and following
conditions. Neither path creates a payment.

## Client, errors and navigation

Typed commands and repository `Either` results keep the transport out of domain
code. The action sheet retains its command, generation, version and request ID
after recoverable errors. A stale generation/version requires reopening with
fresh state; retries never silently acquire a newer generation. Success appears
only after server acknowledgment. Follow-up commands are not queued financial
operations; offline users can retain the sheet and retry when connected.

Agenda, source details and the confirmed-expense confirmation expose follow-up
controls. Pending offline expenses must synchronize before manual completion.
Rows show Registered/Planned for expenses and Paid/Planned for installments.
The unified Home preference uses the OR of the two legacy visibility flags.
Privacy hides amounts without changing ranking or records. Source failures and
cache/pending metadata keep counts provisional and expose retry, rather than
claiming an empty complete plan. Reopening details preserves Plan's month/filter.

## Notifications

`planDebtReminders` feeds the shared Coach/debt coordinator. Dismissal suppresses
installment notices. Snooze replaces before/due notices with a single 09:00
profile-local reminder; payment, skip or pause removes it. Resumption schedules
only applicable future notices in the rolling 28-day window. Original periods
are retained in navigation. No expense notifications or implicit permission
requests are introduced. Other devices update their local schedules after sync;
remote cancellation and operating-system delivery are not immediate guarantees.

## Design and verification

Editable states are on Figma **07 P0 Screens** (`325:3059`): Home `620:982`, Coach
`617:970`, partial attention `687:3136`, actions `687:3333`, dark `690:1023` and
enlarged text `690:1043`. `00 Current Baseline` remains unchanged.

Automated evidence lives in `planning_follow_ups_test.mjs`, the Firestore rule
and reset suites, Flutter follow-up entity/provider/widget tests, and
`integration_test/planning_follow_up_flow_test.dart`. The E2E is guarded to
`demo-clearbudget` and uses Auth, Firestore and Functions Emulator. See the
[qualification report](qa/planning-follow-ups-2026-10-31.md) for actual outcomes
and separate deployment/device limitations.
