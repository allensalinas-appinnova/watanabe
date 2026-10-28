---
title: Operation commands and balance integrity
summary: Server-owned financial mutations, offline retries and guarded legacy projection migration.
---

# Operation commands and balance integrity

Updated: 2026-10-28. The operation command backend is deployed to `lumiomoney`;
the Firestore Rules cutoff and compatible client release are still pending.

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
`lumiomoney` in `us-central1` and confirmed present with Firebase CLI. No
real-user audit or financial write, Firestore Rules deployment, or client-store
release was performed for this change.

Remaining production rollout:

1. Distribute the compatible client and monitor adoption. The updated Functions
   are already live, while current Firestore Rules continue to permit legacy
   clients to drain their direct-write outboxes.
2. Coordinate a compatibility window and ensure queued operations can drain or
   be safely migrated. The Rules cutoff blocks direct writes from older clients.
3. Deploy the Firestore Rules cutoff only after that compatibility gate is met.
4. Observe migration outcomes and run read-only diagnostics for any profile
   blocked by a discrepancy. Do not repair or adjust balances automatically.
5. Verify authenticated callable access and a synthetic/test-account workflow
   separately from a real financial operation.

Do not restore direct client writes as a rollback. If rollout must pause, keep
the server path and Rules coherent; diagnose the incompatible client or deploy
a reviewed compatible client/server revision.
