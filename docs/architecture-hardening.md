# Architecture hardening follow-up

Updated: 2026-10-21. This records implementation and remaining release work; it
does not imply that unavailable staging/device checks have passed.

## Delivered in this slice

- Authenticated route guards load the profile through `CanonicalFinanceRepository`
  rather than querying Firestore in the router. Profile read errors navigate to a
  localized recovery screen with retry and sign-out actions. Redirect decisions
  are covered by pure unit tests, including incomplete/missing profiles and deep links.
- `processOperation` now applies the difference between the previous and current
  confirmed operation to account balances, monthly summaries, category totals,
  and linked budget-item actuals. Create, edit, rejection and deletion are
  reversible; a per-event marker makes retries idempotent and the Firestore
  trigger enables automatic retry.
- Pull requests and `main` pushes run Flutter analysis/tests, Functions build,
  and Firestore Rules tests against the `demo-clearbudget` emulator project.
- This checkout currently passes `flutter analyze`, **158 Flutter tests**, the
  Functions build plus **3 projection-delta tests**, and **8 Firestore Rules
  Emulator tests**. The full device E2E has not been run in this environment.

## Remaining architectural actions

1. **Budget aggregate authority (high).** Firestore Rules can validate the
   `plannedAmountMinor` and `itemCount` field shapes but cannot sum a dynamic
   subcollection. The client currently updates parent aggregates atomically with
   item writes. Decide whether to keep that as an explicitly trusted-client
   invariant or move aggregate maintenance behind a trusted server command.
   Before changing it, add emulator tests proving inconsistent parent/item
   totals are rejected and preserve immediate budget-list feedback.
2. **Projection reconciliation (high).** Automatic retries now recover transient
   Function failures, but there is no scheduled repair for historical missed
   events or manual corruption. Add a dry-run-first reconciliation command,
   drift metrics and an operator alert; validate against staging before enabling
   writes. No real project was touched by this change.
3. **Layering (medium).** `canonical_finance_providers.dart`, the Firestore
   datasource and the largest screens remain oversized. Extract report and
   budget orchestration into feature use cases/controllers in small vertical
   slices, retaining repository `Either` boundaries and provider overrides.
4. **Large activity exports (medium).** Report generation still gathers all
   matching rows in memory. Add incremental CSV writing, progress and
   cancellation; verify bounded memory with a synthetic large history.
5. **App Check (pre-beta).** SDK initialization and enforcement are not enabled.
   Provision staging app registrations and attestation providers, start in
   monitor mode, verify emulator/dev bypass and only then enforce per platform.
   This requires Firebase Console and platform signing setup not present here.
6. **Release qualification.** Run the full Auth/Firestore/Functions E2E on CI and
   staging, plus Android/iOS device checks for profile denial/retry, delayed
   projection recovery, and app restart. Emulator unit tests are not staging or
   physical-device evidence.

## Design constraints

- Financial amounts stay in minor units and projections must be idempotent.
- Firestore rules remain owner-scoped; no production credentials or real user
  records belong in CI.
- Do not remove a user's operation to repair projections; reconcile derived
  views from the canonical operations ledger.
