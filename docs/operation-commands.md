---
title: Operation commands and balance integrity
summary: Server-owned financial mutations, offline retries and guarded legacy projection migration.
---

# Operation commands and balance integrity

Updated: 2026-10-28. The operation command backend and Firestore Rules cutoff
are deployed to `lumiomoney`; compatible client distribution and adoption
verification are still pending.

## Source of truth and writes

Confirmed `operations` remain the canonical activity. New income, expense and
transfer writes go through the authenticated `mutateOperation` callable; the
client never writes an operation or its ledger rows directly. The server derives
the owner from Firebase Auth and validates currency, amount, account status,
category, budget reference, profile time zone and data generation.

Each create uses its stable local outbox `idempotencyKey` as `requestId`. In one
Firestore transaction, the server writes the operation, its root and nested
ledger entries, account balance(s), monthly summary, linked budget actual and a
command receipt. A transfer changes both accounts in that same transaction.
Repeating the request returns the original receipt; reusing the ID with a
different payload is rejected.

Corrections and cancellation also run transactionally. A correction keeps the
original income/expense type, reverses the previous projection and applies the
replacement, updates ledger rows and advances the revision. It is rejected if
the prior source document is not known to have been projected. Cancellation
reverses the confirmed effects and removes active ledger entries while retaining
the operation record and receipt for audit. Account archival is server-owned and
allowed only for a money account whose projected balance is exactly zero.

The local Drift outbox is retained. Offline drafts keep their request ID and the
data generation captured when queued; synchronization sends them to the callable
when connectivity returns. A draft from an older generation is rejected rather
than retagged after a user data reset. Financial projections become visible
when the server accepts the queued command, not while it is only local.

## Legacy trigger and migration gate

`processOperation` remains for older records and delayed Firestore events. The
operation ID comes from the event document path. Before applying an event, the
trigger compares its financial digest with the current live source document and
checks the generation and server-owned receipts. An old or duplicate event
cannot overwrite a newer projection; a command already applied in its
transaction is not applied again.

On the first command for a profile without `operationProjectionVersion: 1`,
the server locks supported writes and runs the read-only projection audit. If
the audit is complete and has no differences, it stamps legacy operation
digests and enables the command version. If the scan is incomplete or detects a
difference, it records a sanitized issue and stops without changing balances,
summaries or budgets. Operators should use the diagnostic flow in
[projection-audit.md](projection-audit.md); this migration is not a repair.

An owner-authorized technical repair is a separate operator workflow, documented
in [projection-audit.md](projection-audit.md#explicitly-authorized-technical-repair).
It archives a misclassified cache repair outside financial adjustments, preserves
account balances and source operations, and corrects only reviewed summary
differences. Never add another monetary adjustment or set the migration version
to bypass this gate.

Adjustments also use a transaction against the same account documents, so a
concurrent operation conflicts and retries against the updated balance. An
adjustment is blocked until the account's legacy projection state passes the
same audit. New operations cannot target archived accounts. Historical
operations that reference accounts archived by older clients can still be
reversed or corrected onto an active account.

## Verification and release gate

The verification includes the new command/ledger/migration tests, the real
Functions trigger against Emulator, Firestore Rules tests, Functions build,
Flutter tests and static analysis. Emulator fixtures are synthetic; they do
not establish that a real user's projections are consistent. On 2026-10-28,
`mutateOperation`, `processOperation`, `mutateDebt`, `mutateEmailImport`,
`mutateBudget`, `adjustAccountBalances` and `resetUserData` were deployed to
`lumiomoney` in `us-central1` and confirmed present with Firebase CLI. This initial
Functions publication did not include the Rules cutoff or a client-store release.

Later on 2026-10-28, at the founder's explicit request, the Firestore Rules
cutoff was published using `firebase deploy --only firestore:rules --project
lumiomoney --non-interactive`. All 24 Firestore Rules tests passed in
`demo-clearbudget` before publication. Compilation succeeded with warnings about
unused helper functions and their references. A post-deployment readback from
`lumiomoney` matched the local `firestore.rules` source. The previous rules were
saved in an ignored `.dart_tool/firestore-rules-before-cutoff-*.rules` backup.
Only Firestore Rules were published; Functions and indexes were not redeployed.

This publication did not verify client distribution/adoption, audit a real user,
or send a financial command to the live project. Older clients can no longer
write operations or ledger entries directly and must be updated to synchronize.

Remaining production follow-up:

1. Distribute/install the compatible client and monitor adoption and rejected
   synchronization attempts from earlier versions.
2. Preserve existing offline drafts. Synchronize or migrate them through the
   updated client's callable path with their original IDs and data generation;
   legacy direct-write outboxes cannot drain through the published Rules.
3. Observe migration outcomes and run read-only diagnostics for any profile
   blocked by a discrepancy. Do not repair or adjust balances automatically.
4. Verify authenticated callable access and a synthetic/test-account workflow
   separately from a real financial operation.

Do not restore direct client writes as a rollback. If rollout must pause, keep
the server path and Rules coherent; diagnose the incompatible client or deploy
a reviewed compatible client/server revision.
