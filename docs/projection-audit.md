---
title: Projection integrity and read-only diagnosis
summary: Atomic financial projections, isolated verification and read-only discrepancy diagnosis.
---

# Projection integrity and read-only diagnosis

Updated: 2026-10-22.

## Current working-tree follow-up (not deployed)

The 2026-10-22 deployment below is historical evidence for that revision only.
The current working tree adds a `mutateOperation` transaction path and a
first-command legacy gate: it audits before stamping projection digests, and
stops without repair if differences exist. See
[operation command integrity](operation-commands.md) for the new behavior and
coordinated rollout requirements. No production deployment or real-user audit
has been performed for this follow-up.

Canonical confirmed operations are the ledger. Account balances, monthly
summaries and linked budget-item actuals are derived views. The event adapter
delegates to `applyOperationEvent`, which commits all changes and its event
marker in one Firestore transaction. Duplicate delivery is harmless. A failure
leaves no partial projection or processed marker, so the event can retry.

## Deployment status

On 2026-10-22, the explicitly authorized follow-up deployed only
`functions:processOperation` to `lumiomoney`, from the working tree based on
`ba0ccd9`. Firebase CLI completed successfully; gcloud read-back confirmed
`ACTIVE`, Node.js 22, revision `processoperation-00005-hih`, the existing
`users/{userId}/operations/{operationId}` Firestore written-event filter and
`RETRY_POLICY_RETRY`. The previous revision was `processoperation-00004-dij`
with retries disabled. The CLI required `--force` to acknowledge the newly
enabled failure policy; the deployment remained scoped to this function.

Before deployment, `npm --prefix functions run test:projections` passed all
3 pure tests, and `bash tool/run_projection_tests.sh` passed all 17 transaction/
audit tests plus 1 real Emulator trigger test. Functions TypeScript compilation
and `git diff --check` passed. Tests used only `demo-clearbudget`. Remote
verification inspected deployment configuration, not production mutations.
No historical repair, real-user audit, ledger replay or financial test write
was performed. Existing discrepancies are not repaired merely by deploying.
The separate `mutateBudget` service retained its ready state and disabled
transport Invoker IAM check; its Firebase Auth guard remains mandatory.

```bash
npx -y firebase-tools@latest deploy --only functions:processOperation --project lumiomoney --non-interactive --force
```

Failed events can now retry automatically. Monitor persistent projection
validation failures rather than assuming retries repair invalid references or
historical data. Operational alerting and a reviewed repair procedure remain
future work.

## Run the isolated checks

Use Node.js 22 and Java 21+. From the repository root:

```bash
npm ci --prefix functions
npm --prefix functions run test:projections
bash tool/run_projection_tests.sh
./tool/run_rules_tests.sh
```

The projection runner first starts **Firestore alone** to exercise the actual
transaction and diagnostic command with synthetic fixtures. It then starts
**Firestore + Functions** separately and writes an operation to test the real
trigger, including a rejection that reverses the projections. Each expected
trigger result has a 30-second deadline. Direct transaction tests must not run
with Functions enabled, which would also process their fixture writes.

Both invocations pin `demo-clearbudget`. CI uses Node.js 22 and runs these
checks without production credentials. Local emulator ports follow
`firebase.json`; do not run competing suites on the same ports.

Local verification on 2026-10-22 passed with Node.js **22.23.4**: Functions
TypeScript build, **3** pure projection tests, **17** Firestore transaction/audit
tests and **1** real Functions trigger test. `flutter analyze` passed and all
**158** Flutter tests passed. CI execution and physical-device E2E are separate
from these local results.

## Inspect a synthetic user

With the Firestore emulator running and a synthetic user already seeded:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:59180 \
  npm --prefix functions run audit:projections -- \
  --project demo-clearbudget --user audit-user --output diagnostic.json
```

`--project` and `--user` are mandatory; neither is inferred from Firebase CLI
aliases or ambient credentials. Demo projects require an emulator endpoint;
an emulator endpoint requires a demo project. Without an emulator, an explicit
real project uses the operator's existing ADC access. This delivery does not
run against real projects. Prefer a read-only IAM identity for later operator
use. There is no apply, repair, write or deployment option.

`--output` accepts a JSON **filename**, not a path. Reports are created under
`.local/projection-audits/`, ignored by Git, with owner-only file permissions.
Existing files are never overwritten. Symlinked report directories and path
traversal are refused. Console output contains counts and completeness only;
the detailed JSON contains document identifiers and expected/actual financial
values but omits names, descriptions, notes, tokens and exception messages.
Do not publish diagnostic reports as CI artifacts or attach real reports to Git.

## Interpret the result

| Exit | Meaning |
| --- | --- |
| `0` | Complete comparison; all checked projections match. |
| `2` | Complete comparison; differences found. No data changed. |
| `1` | Incomplete comparison, invalid arguments, read failure, or report-output failure. |

The JSON has `complete`, `counts`, `differences` and `issues`. A difference
identifies a document and field with expected/actual values; a missing summary
also has a `document` difference. Issues identify invalid ledger data or missing
and incompatible references by code. If canonical data is invalid, other
differences are provisional: do not use partial results to repair balances.
Unexpected SDK errors produce only a sanitized failure count on stderr.

Expectations use opening balances plus confirmed operations, grouped by
currency and the stored `monthKey`. Transfer amounts affect their two accounts
and transfer summary fields, never income/expense totals. Category totals keep
the existing signed convention: positive income, negative expense. Budget-item
actuals sum only explicitly linked confirmed operations. Archived accounts,
budgets and items participate; old items without actuals default to zero.
Pending/rejected operations do not contribute and are still checked for valid
shape. Zero-valued category residues and zero summaries left by reversals are
valid; nonzero residues are differences. Missing references are issues rather
than guessed associations. Invalid or unsafe integer values cannot be silently
rounded into the calculation.

## Concurrent activity and limits

Each pass uses a read-only transaction and pages every collection by document
ID, 500 records at a time, including each budget's items. The command makes two
passes and compares document versions and membership. A detected change yields
`concurrent_change_detected` and exit `1`; rerun after activity settles. Neither
pass reads or writes event markers. Root user, accounts, categories, operations,
summaries, budgets and known budget items are compared. A deleted budget still
referenced by the ledger is checked for surviving item records.

This is a point-in-time, best-effort comparison, not a lock against later writes
or a guarantee that all asynchronous triggers have finished. A queued trigger
can cause a temporary difference even if both passes are stable. Run again when
the ledger is quiet. A long scan can hit Firestore transaction/read deadlines,
in which case the command returns failure, never success from a partial scan.
Two passes approximately double the read volume. Paging bounds each request;
this first version still retains the selected records in memory. Unreferenced
item subcollections under physically deleted parent budgets are outside the
scan; application budgets are archived, not deleted.

Historical repair, scheduled reconciliation, operational alerts, deployment
and real-project acceptance remain separate work.

References: [Firestore event delivery and limitations](https://firebase.google.com/docs/functions/firestore-events#limitations),
[Functions Emulator](https://firebase.google.com/docs/emulator-suite/connect_functions).
