---
title: ClearBudget implementation and business backlog
summary: Prioritized, dependency-aware work with acceptance criteria and effort ranges for a LATAM launch.
---

project_status:
  updated_at: "2026-10-06T07:48:00-05:00"
  iteration: "ITERATION-2"
  last_commit: "f1057a4"
  status: "Iteration 2 in progress: cursor API and offline queue exist, while Activity accumulation, startup sync and durable restart verification remain to be implemented."
  verified:
    - "flutter analyze passes"
    - "Flutter unit/widget tests pass (30 tests)"
    - "Functions compile"
    - "Firestore Emulator security tests pass (4 tests)"
    - "Firebase Emulator Suite starts with Java 21 and category seeding"
    - "Iteration 1 commit f1057a4 is the implementation base"
    - "Existing Flutter, Functions and Firestore Emulator checks remain green"
  blocked:
    - "No Android device/emulator is visible to ADB"
    - "No iOS Simulator runtime is available to simctl"
    - "Staging Firebase credentials, signing and OAuth release inputs are not configured"
  next_iteration: "Complete Activity pagination, startup synchronization and restart/retry verification; then prepare Iteration 3 staging security."

## Iteration status snapshot

| ID | Status | Evidence / remaining gap |
| --- | --- | --- |
| CB-02 | in_progress | Source, docs and emulator checks updated; CI and release ownership remain. |
| CB-03 | proposed | Staging, signing, OAuth and cloud release qualification remain. |
| CB-05 | in_progress | Canonical income/expense CRUD and integer money are implemented; device E2E and full reconciliation remain. |
| CB-06 | in_progress | Same-currency transfer ledger path and rule coverage exist; device/concurrency qualification remains. |
| CB-07 | in_progress | Itemized budgets and tracker are implemented; full boundary/copy/archive matrix remains. |
| CB-08 | in_progress | Localized onboarding/category bootstrap exists; device flow and complete category management remain. |
| CB-09 | in_progress | Dashboard/tracker use canonical derived data and honest empty states; monthly aggregate consumption and Activity paging remain. |
| CB-10 | in_progress | Drift queue, retry UI, four sync states and reconnection listener exist; startup sync, lock and close/reopen proof remain. |
| CB-11 | in_progress | es/pt/en delegates and core P0 strings exist; full hardcoded-text and accessibility audit remains. |
| CB-12 | in_progress | Minor-unit parser and base currency are present; full regional/time-zone matrix remains. |
| CB-16 | in_progress | Emulator rules and bounded query checks pass; pagination index/recovery and production review remain. |
| CB-19 | in_progress | 30 Flutter tests plus rules coverage exist; pager/offline tests and Android/iOS UI E2E remain. |

# ClearBudget implementation and business backlog

Baseline: 2026-10-04 local mobile project. All items are **Proposed / not started**
in this planning delivery, including repairs. This document does not mean the
features have been implemented. Read the [release audit](store-readiness-audit.md)
for evidence and the [business analysis](market-and-business-analysis.md) for
commercial assumptions and source links.

Priority: **P0** blocks a reliable regional beta/release candidate; **P1** supports
the first paid proposition; **P2** requires evidence from users before commitment.
Store submission additionally requires CB-17/20 and all applicable publisher gates.
An unpaid beta can precede billing; a paid launch cannot precede CB-25.

Estimates are person-days of focused work by an experienced contributor, including
implementation, relevant automated tests and review. They are planning ranges,
not quotes or calendar promises. Vendor approvals, store review, recruitment and
waiting for retention/renewal cohorts are excluded. Owners are roles to assign,
not claims that the team currently has those people.

## P0 — correct product and release foundation

## Current implementation notes

The canonical mobile vertical slice is now wired into Flutter presentation:
integer money, localized category bootstrap, canonical accounts, income,
expense, transfers with ledger entries, itemized budgets, budget tracking and
high-value routes are available. The retired web schema is not read or migrated.
This is not a completion claim for all P0 release gates: emulator execution is
still environment-dependent on a supported Java runtime, and pagination,
production rule review, staging qualification and full offline UI synchronization
remain release work.

| ID | Deliverable and owner | Days | Depends on |
| --- | --- | --- | --- |
| CB-01 | Customer/problem validation; Founder/Product | 5–8 | None |
| CB-02 | Git baseline, CI and documentation reconciliation; Mobile | 3–5 | None |
| CB-03 | Signed environments and cloud release configuration; Mobile/Release | 5–8 | CB-02; publisher/project access |
| CB-04 | Money, ledger schema and web-data compatibility decision; Mobile/Backend | 4–7 | None |
| CB-05 | Complete income/expense lifecycle and account reconciliation; Mobile/Backend | 7–12 | CB-04 |
| CB-06 | Atomic transfers; Mobile/Backend | 4–6 | CB-05 |
| CB-07 | Monthly budget creation and correct aggregates; Mobile/Backend | 5–8 | CB-04/05 |
| CB-08 | Fresh-user onboarding and category management; Mobile/Product | 4–6 | CB-04/07 |
| CB-09 | Honest dashboard and report navigation; Mobile | 1–2 | None for removing literal; CB-05/07 for calculated comparisons |
| CB-10 | Durable offline entry and retry UX; Mobile/Backend | 6–10 | CB-04/05 |
| CB-11 | Spanish/Portuguese localization and accessibility; Mobile/Design | 5–9 | Inventory of current screens |
| CB-12 | Regional currencies, dates and time zones; Mobile | 4–7 | CB-04/11 |
| CB-13 | Apple and production Google authentication; Mobile | 3–5 | CB-03 |
| CB-14 | Session restoration and guest upgrade; Mobile | 3–5 | CB-08/13 |
| CB-15 | User deletion across identity/data/receipts; Backend/Mobile | 5–8 | CB-03/14; retention decision with CB-17 |
| CB-16 | Rules, cost bounds and recovery; Backend/Mobile | 5–8 | CB-04/05; integrate CB-07/10/15 before sign-off |
| CB-17 | Country privacy/consumer matrix and policy endpoints; Founder/Legal | 4–7 | Country/publisher decision; data inventory |
| CB-18 | Operational and product measurement; Mobile/Backend | 3–5 | CB-03; collection policy with CB-17 |
| CB-19 | Independent E2Es and device release qualification; QA/Mobile | 6–10 | CB-03–18 technical work |
| CB-20 | Store identity, listings and beta distribution; Founder/Design/Release | 3–5 | CB-03/11/17; CB-19 for final submission |
| CB-23 | User-controlled basic export; Mobile | 2–4 | CB-04/05 |

Acceptance and meaningful verification:

**CB-01.** Conduct 24 interviews in Mexico/Brazil/Colombia and 12 observed prototype
sessions; record current alternative, problem frequency, last concrete incident,
country, language and price reaction. Produce one target subgroup, ranked pains,
consenting beta recruits and a documented continue/change decision. Recruitment is
not completed by publishing a form; no outreach is authorized by this document.

**CB-02.** Establish mobile source-control ownership without importing build caches
or sibling web history accidentally. Record reproducible SDK/lockfiles and protect
credentials. CI runs analyze, unit/widget tests and emulator security/E2E jobs;
update architecture/localization/testing claims to match code. No blanket refactor
is required: correct boundaries and error mapping in affected vertical slices.

**CB-03.** Fix Android release signing and final app IDs; configure staging/prod
Firebase per platform, OAuth schemes/SHA fingerprints, symbols and release inputs.
Reject missing/invalid environment values and emulator flags in production.
Verify INTERNET in merged manifest, API target 36+, 16 KB compatibility and iOS SDK
requirements; install a signed cloud-backed release on both physical platforms.
Record a minimal staging smoke using synthetic accounts. Tests remain on demo
emulators except a specifically controlled staging qualification.

**CB-04.** Approve a versioned schema with exact monetary representation, currency,
rounding, transaction kinds, stable category IDs and period/time-zone semantics.
Choose web isolation or migration; test `in/out` compatibility if reusing data.
Golden cases include decimal currencies, large values, negative balances, same-time
entries, opening balances and invalid amounts. Domain layer remains pure Dart.

**CB-05.** User can create/read/edit/delete income and expenses with a valid account
and category; totals reconcile after backdated edits, reclassification and deletes.
Prevent duplicate effects with stable command IDs. Choose account archival or a
recoverable deletion process; test interruption across more than 499 movements,
receipt cleanup and corrected budget spending. Record no unacknowledged loss on retry.

**CB-06.** One transfer changes both account balances exactly once; rollback cannot
leave one side missing; totals exclude transfers from income/spending. Test retry,
concurrent requests, invalid/same accounts and insufficient permissions. First
version permits same-currency transfers only, with explicit validation.

**CB-07.** A fresh user can create/edit/archive a budget by stable category and month;
spending derives from the right period. Test midnight/month/year boundaries,
backdated expenses, category change, movement/account deletion and copying a plan
to a new month. Rebuild totals from the ledger and compare with stored aggregates.

**CB-08.** On an empty backend, user selects language/country/base currency, creates
an account and categories, then records income/expense and first budget without a
developer seed. Category rename preserves references; deletion has an explicit
reassignment/archive rule. Persist onboarding progress across app termination.

**CB-09.** Remove the literal 8.4% comparison immediately; implement a tested
like-for-like comparison only when data supports it. Label balance versus period
flow correctly. A report action leads to an actual report or is renamed. Zero-history,
zero-denominator and empty-budget states remain honest and usable.

**CB-10.** Specify queued → syncing → confirmed/rejected states. Persist an expense
and optional receipt draft through airplane mode and process termination; reconcile
exactly once after reconnect and surface rejected writes. Distinguish optimistic
from confirmed balances. First evaluate a Firestore command queue plus trusted
processing; introduce a local DB only through an ADR if required for durable drafts.
Test two-device conflict, retry and account switch; cache-only reading is insufficient.

**CB-11.** Wire delegates/locales and replace hardcoded strings; deliver Spanish,
Brazilian Portuguese and retained English, including financial terms, errors,
permission text and semantics. Native-speaker review plus widget tests at large
text sizes, narrow screens, screen-reader navigation and contrast. No raw keys or
English fallback on the normal Spanish/Portuguese happy path.

**CB-12.** Country and language are independently editable; base currency persists.
Test MXN/BRL/COP/CLP/PEN/ARS/USD and expand with the enabled-country matrix. Parse
localized numbers without changing magnitude; display currency codes where `$`
is ambiguous; test time-zone travel and month boundaries. Mixed currencies require
separate totals until an explicit FX feature is delivered.

**CB-13.** Physical iPhone/Android can complete enabled production-style providers
against staging, including cancel, private email, revoked access and existing-email
collisions. Add Sign in with Apple while retaining Google. Store reviewer can enter
the app without relying on unavailable OAuth test accounts.

**CB-14.** Central route guard handles cold launch, deep link, sign-out and revoked
session; never trusts a cached profile as authorization. Link anonymous data to a
permanent account without loss, including credential collision recovery. Test
logout/login as another user and stale cached-state visibility. Define account
recovery/email-verification behavior and test expired/invalid reset flows.

**CB-15.** In-app and external-web request paths reauthenticate appropriately and
delete Auth plus Firestore descendants and Storage objects through a resumable,
idempotent process. Test interruption/retry and more than one batch; stop background
writes during deletion. State retention exceptions and backup expiry. Subscription
cancellation is a separate action: explain and link to management when applicable.

**CB-16.** Emulator tests deny cross-user/unauthenticated/invalid-schema writes and
protect aggregate/entitlement authority. Enforce reference/amount/type constraints;
assess App Check with staging rollout. Add bounded indexed queries/pagination,
receipt size/format checks, orphan cleanup, cost alerts and a documented restore
drill. Compare restore/deletion with the retention policy. Benchmark a 10,000-entry
synthetic history; record actual reads/memory and prevent full-history screen fetches.

**CB-17.** Map enabled countries, processing purposes, retention, providers/transfers,
user rights, consumer subscriptions and support contacts. Legal owner reviews
public privacy/terms and deletion URLs; disclosures match SDK behavior and archive
privacy report. Confirm publisher identity, contracts, tax/payment arrangements
and financial declaration. No “LATAM compliant” assertion from a single template.

**CB-18.** Capture a staging nonfatal/fatal error with symbols and verify delivery;
wire Flutter/async error handlers. Implement consent-aware activation/retention/
purchase events without financial payloads. Dashboard shows country/platform/cohort
denominators; alerts route to an assigned operator. Verify backups and cost monitoring
have owners, not merely SDK dependencies.

**CB-19.** Split the long scenario into isolated fixtures and add an unseeded onboarding
flow; cover money/month invariants, unauthorized reads/writes, offline/retry, deletion,
receipt failure and session switching. Native camera/gallery and OAuth need physical
staging checks. Verify fresh install, upgrade, low-memory Android, iPhone, large text,
weak network and signed release. Record passed/failed/skipped per platform; don't
count setup/teardown as independent business scenarios.

**CB-20.** Validate working name/domain/trademark and asset rights; create final icons,
real localized screenshots, support page, reviewer instructions/demo access, age rating,
privacy labels/Data safety and country availability. TestFlight and Play tracks have
actual testers and feedback. Meet the 12-testers/14-days condition if the publisher
account is subject to it. Store approval remains an external gate.

**CB-23.** Export all or filtered history with currency, category, date/time zone and
stable IDs; neutralize spreadsheet formula injection in free-text fields. Reconcile
CSV totals with the ledger, test Unicode/locales and sharing cancellation. Basic
data portability remains available after premium expiration.

## P1 — paid value and sustainable acquisition

| ID | Deliverable and owner | Days | Depends on | Acceptance / verification |
| --- | --- | --- | --- | --- |
| CB-21 | Recurring commitments and reminders; Mobile/Backend | 5–8 | CB-05/07/10/12 | Monthly/weekly/semimonthly plans, end-of-month behavior, paid/skipped states and opt-in reminders; planned entries never silently count as paid; timezone/retry tests prevent duplicate posting |
| CB-22 | Available-to-spend and goal reservations; Product/Mobile | 5–8 | CB-01/06/07/21 | Shows eligible liquid funds minus unpaid commitments, protected goals and buffer until next income; excludes credit limits/transfers and uncertain future income; explains each input and stale data; no double-counting paid bills; tested negative/no-income cases |
| CB-24 | CSV import with review; Mobile | 5–8 | CB-04/05/08/23 | Column/date/decimal mapping, preview, duplicate detection, resumable import and rollback; golden files from consenting/redacted target-country samples; never auto-commits guessed rows |
| CB-25 | Subscription purchase and entitlement lifecycle; Backend/Mobile | 8–13 | CB-03/14/15/16/17; CB-22 paid value | Monthly/annual localized prices, restore, pending, grace, expiration, refund/revocation and cross-device restore; server validation and idempotent notifications; client cannot grant premium; sandbox integration tests and release smoke |
| CB-26 | Regional price/channel experiments; Founder/Growth | 5–8 | CB-01/18/22/25 | Country-tagged offers and fixed learning budget; record views, activated users, payments/refunds and CAC with denominators; predeclare stop rules; actual local store price points |
| CB-27 | Weekly review and retention iteration; Product/Growth | 4–6 | CB-18/21/22 | Consent-aware useful summary, controllable notifications and cancel feedback; compare matured country cohorts over 4–6 weeks; no daily spam or invented savings claims |

CB-21/22 are the proposed differentiating paid loop. If CB-01 rejects this problem,
revise their scope before implementation. CB-24 helps migration but can follow a
small paid pilot whose users do not need historical import.

## P2 — evidence-triggered expansion

| ID | Proposed work and owner | Days | Dependency / trigger | Acceptance boundary |
| --- | --- | --- | --- | --- |
| CB-28 | Credit-card cycles and instalments; Mobile/Domain | 6–10 | CB-05/06/21; promote if initial cohort requires it | Closing/due dates, partial payments and instalment commitments reconcile without counting repayment as a second expense; no unverified interest forecast |
| CB-29 | Household collaboration; Backend/Mobile | 10–16 | CB-14/16/25; repeated paid household demand | Explicit memberships/roles/invitations, revocation, personal/shared boundaries and cross-user permission tests; not shared passwords |
| CB-30 | Bank connectivity feasibility; Backend/Founder | 4–7 for research only | Measured manual-entry churn and requested institutions | Written coverage/cost/consent/support evaluation plus sandbox spike; implementation separately estimated after quote and production qualification |
| CB-31 | Receipt OCR assistance experiment; Mobile/Backend | 4–7 for bounded prototype | CB-05/16/18; measured capture friction | User confirms extracted amount/date/category; confidence/failure UX, image retention, cost per accepted receipt and no financial data sent without appropriate disclosure |
| CB-32 | Privacy-oriented biometric lock; Mobile | 2–4 | CB-14; user research | Device-auth lock with fallback, background masking and no claim of extra database encryption; accessibility/recovery tests |
| CB-33 | FX and multiple currencies in one workspace; Domain/Mobile | 6–10 | CB-04/06/12; demonstrated cross-currency demand | Rates/date/source/rounding tracked, same-currency invariants preserved, transfer fees explicit and no mixed-unit sums |

AI financial coaching, Gmail ingestion, investments, lending, money movement and
full accounting are outside the proposed initial paid scope. Each needs a business
case, privacy/operating-cost review and its own acceptance criteria.

## Sequence, capacity and release gates

P0 engineering estimates total **75–125 person-days** (CB-02–16, CB-18/19/23).
Founder/legal/design work CB-01/17/20 adds **12–20 person-days**, with external waiting
time and native translation review additional. P1 engineering CB-21/22/24/25 adds
**23–37 person-days**; growth/product CB-26/27 adds **9–14 person-days**. Shared QA
estimates cover release qualification; each feature range already includes its own tests.

At a planning capacity of 7 combined engineering person-days/week for two full-time
engineers after coordination, P0 is about **11–18 weeks**, plus contingencies and
external waiting. P0 plus P1 engineering is **98–162 person-days**, about **14–24 weeks**
before recruitment, review and observation delays. This is capacity arithmetic,
not a promised delivery date. With one engineer and 3.5 focused days/week it is
roughly **28–47 weeks** for that combined scope. Re-estimate after CB-04 and the first
complete slice; a narrower manual beta can be tested sooner with explicitly reduced promises.

1. **Now / first iteration:** Founder runs CB-01 and publisher setup. Engineers do CB-02, CB-04, CB-09 and the first CB-05/07 slice; begin CB-03 configuration. The first demonstrable result is a truthful balance/monthly budget from a fresh account.
2. **Regional beta gate:** Complete P0 technical gates, policies and beta listings. Native cloud tests pass; fresh-user flow works in Spanish/Portuguese; no open money-integrity/deletion issue. Recruit 60–100 users across the initial country cohorts.
3. **Paid pilot gate:** CB-21/22 delivers understandable planning value; CB-25 purchase lifecycle passes. CB-18 measures activation/retention and CB-26 runs a limited offer/channel test.
4. **Scale gate:** Mature cohort retention, actual net proceeds, renewal and CAC satisfy the business experiment rules. Approve additional country spend and P2 only with evidence. A store approval is not this gate.

Definition of done for a product item: accepted behavior implemented; domain/error/
permission cases tested; emulator integration for persistence as applicable; localized
UI and accessibility reviewed; migration/rollback addressed where needed; docs updated;
CI green; staging/device check for native changes. Feature completion cannot be
inferred from screenshots or tests that seed data outside its user flow.
