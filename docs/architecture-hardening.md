---
title: Architecture hardening follow-up
summary: Implemented architecture improvements and remaining verification and release gates.
---

# Architecture hardening follow-up

Updated: 2026-10-22. This records implementation and remaining release work; it
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
- The current checkout passes `flutter analyze`, **165 Flutter tests**, the
  Functions build, **3 projection-delta tests**, **17 projection persistence/audit
  tests**, **1 real-trigger test**, **8 budget transaction tests**, **1 authenticated
  callable test**, and **9 Firestore Rules Emulator tests**. Device/rollout
  qualification is recorded separately in [budget commands](budget-commands.md).

The follow-up separates calculation and transactional persistence from the
trigger, completes summary metadata, and adds a read-only projection audit plus
Firestore transaction and Functions trigger emulator coverage. See
[projection integrity and diagnosis](projection-audit.md) for execution,
exit codes, privacy and concurrency limits.

## Remaining architectural actions

1. **Budget aggregate authority: implemented and deployed.** The authenticated
   `mutateBudget` callable now recalculates totals/counts from active items in
   the same transaction as item writes and an idempotent command receipt.
   Rules deny direct client mutations, including coherent-looking aggregates.
   The callable access check, physical iPhone startup and coordinated rules
   deployment passed on 2026-10-22. See [budget commands](budget-commands.md)
   for evidence, compatibility limits and rollback. Production financial
   mutations were not used as test fixtures; hosted CI and Android release
   signing remain separate qualification gaps.
2. **Projection reconciliation (high).** The read-only audit now diagnoses
   differences; historical repair, drift metrics and operator alerts remain
   pending. Validate a future repair design against staging before enabling
   writes. The projection trigger follow-up was separately deployed to
   `lumiomoney` on 2026-10-22 and verified active with retries enabled; see
   [projection deployment evidence](projection-audit.md). No historical
   repair or real-user diagnostic run was performed.
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
