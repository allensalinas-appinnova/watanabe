---
title: Mobile store readiness audit
summary: Evidence-based release gaps for ClearBudget on iOS and Android, reviewed on 2026-10-04.
---

# Mobile store readiness audit

Reviewed: 2026-10-04. Audience: founder, mobile engineering, QA and release owner.
Target market: Latin America from the initial launch, as requested by the founder.
Verdict: functional prototype; not yet a release candidate or a validated business.

This is a release/product audit, not a penetration test, legal opinion or exhaustive
dependency audit. The baseline is the current local `finance_flutter` directory:
neither it nor the workspace root is a Git repository, so no mobile commit or
clean/dirty baseline is available. Existing files were preserved. The web scope in
[functional-scope.md](functional-scope.md) is a reference, not proof of mobile parity.
Generated code, build caches, third-party sources and binary assets were excluded
from source review. The first-party file inventory covered lib, test,
integration_test, platform configuration, rules, scripts and docs.

Evidence labels: **Code** = inspected implementation; **Executed** = commands
run in this review; **Prior execution** = earlier result in this conversation;
**External unknown** = requires console/device/operator evidence; **Proposed** =
recommended work. All implementation findings below remain **Open**.

## What exists today

| Capability | Evidence | Actual boundary |
| --- | --- | --- |
| Email registration/login/reset; guest; Google adapter | `FirebaseAuthRemoteDataSource` in `lib/features/auth/data/datasources/auth_remote_data_source.dart` | Google cloud configuration is unverified; Apple login and user-account deletion are absent |
| Account create/rename/delete | `FinanceRepository`, `FirestoreFinanceRemoteDataSource` | Financial-account deletion is different from deleting the user's identity and all data |
| Expense entry and receipt upload | `FirestoreFinanceRemoteDataSource.addExpense` | Updates balance and one matching budget in a transaction; no income-entry, transfer, edit/delete-movement commands |
| Dashboard and activity | `HomeScreen._buildDashboard`, `ActivityScreen` | Live reads; account/type/current-month filters; incomplete localization and one fabricated comparison |
| Budget listing and limit editing | `BudgetsScreen`, `UpdateBudgetLimits` | No create-budget flow for a fresh user; no monthly period on budget spending |
| Ownership boundaries | `firestore.rules`, `storage.rules` | User-scoped data; Storage image/type/size checks; Firestore has no financial schema validation |
| Automated foundation | `test/`, `integration_test/auth_flow_test.dart` | 18 unit/widget tests passed now; one large integration scenario, not three independent E2E scenarios |

## Findings and release consequences

Severity: High = integrity/privacy or release-blocking defect; Medium = significant
product/operational gap; Observation = preparation/verification work. Priority and
estimates live in [implementation-backlog.md](implementation-backlog.md).

| ID | Severity | Finding, evidence and required outcome | Backlog |
| --- | --- | --- | --- |
| REL-001 | High | `android/app/build.gradle.kts`, `buildTypes.release`, uses the debug signing config. Create an upload-key workflow, Play App Signing and signed AAB validation. iOS project has bundle IDs but no `DEVELOPMENT_TEAM` setting; external signing state is unknown. | CB-03 |
| REL-002 | High | `AppFirebaseOptions._configured` accepts empty values; `AppEnvironment.fromDartDefine` falls back to dev for invalid values; `main` permits emulator mode independently of environment. Add fail-fast release/environment validation and prove staging/prod cloud configuration. Missing local native config is not proof cloud projects do not exist. | CB-03 |
| REL-003 | Medium | `android/app/src/main/AndroidManifest.xml` has no explicit INTERNET permission; debug/profile manifests do. Inspect the merged release manifest and test cloud networking on the actual release build before calling this a runtime failure. | CB-03 |
| DATA-001 | High | `addExpense` matches budget by category only, adds to `spent` regardless of date; `BudgetsScreen._buildBudgets` labels totals with the current month. Prior-month entries can affect a current-month display. Add period-specific budgeting, recomputation and month-boundary tests. | CB-07 |
| DATA-002 | High | `deleteAccount` deletes movements without reversing budget spending; deletes beyond 499 records span batches; receipt failures are swallowed with a comment about future cleanup. Implement recoverable deletion/archive, aggregate reconciliation and a real cleanup mechanism. | CB-05, CB-16 |
| DATA-003 | Medium | `ExpenseDraft`, `FinanceAccount`, `FinanceTransaction` use `double`; formatter fixes COP to zero decimals; entities have no currency. Define exact money representation, currency/scale, rounding and migration before regional use. | CB-04, CB-12 |
| DATA-004 | High if sharing web data | Mobile writes `type: expense` and recognizes only `income`; the web reference uses `in/out`. Sharing `users/{uid}/cashflow` without migration misclassifies web incomes. Budget shapes also differ. Decide isolated mobile data or a versioned compatibility migration. | CB-04 |
| UX-001 | High | `HomeScreen._BalanceSummary` displays literal `↑ 8.4% vs last month` for every user. Remove or calculate it from comparable periods; unavailable history must show an honest empty state. | CB-09 |
| UX-002 | High | `FinanceRepository` exposes no create budget, income, transfer or edit/delete transaction. `_showEditBudgetLimitsDialog` tells new users to add a budget but offers no creation path. Deliver a complete fresh-user loop. | CB-05–08 |
| UX-003 | High for regional launch | `PersonalFinanceApp.build` wires no localization delegates/supported locales; feature text is English; `CurrencyFormatter.cop` fixes `es_CO`; ARBs do exist. Spanish/English policy is not implemented end to end; Portuguese is absent. | CB-11, CB-12 |
| UX-004 | Medium | `addExpense` calls `runTransaction` and optionally uploads a receipt first. Native cache does not make this an offline expense workflow: transactions fail offline ([Firebase transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)). Implement durable pending/retry/rejected states. | CB-10 |
| AUTH-001 | High | Google button/adapter exist but no equivalent Apple/private-email login, user-account deletion, or anonymous-to-permanent credential linking appears in Auth contracts. Address store requirements and guest data continuity. | CB-13–15 |
| AUTH-002 | Medium | `appRouter` defines six named routes with no central redirect/session refresh; unauthenticated finance screens show loading. Cached profile is yielded before live Auth session in `AuthRepositoryImpl.observeSession`. Verify restored/revoked sessions, deep links and account switching. This is not evidence that Firestore authorization is bypassed. | CB-14 |
| SEC-001 | High | Owner rule permits arbitrary shapes and values throughout the user tree. No validation of amount/type/reference consistency or protected future entitlements. Harden financial writes and keep subscription authority server-owned. | CB-16, CB-25 |
| OPS-001 | Medium | `watchTransactions` subscribes to all cashflow documents and sorts in memory. History growth increases reads, transfer and UI work. Add indexed date queries, pagination, measured aggregates and quotas. | CB-16 |
| OPS-002 | Medium | `FirebaseBootstrap.initialize` obtains Analytics/Crashlytics instances; `main` has no Flutter/async error hooks, product events or validated reporting path. No CI workflow found in the mobile directory. Initialize observability and reproduce a staging report. | CB-02, CB-18 |
| QA-001 | High for release confidence | Single `testWidgets` seeds financial data directly and overrides the image picker. UI sign-up is tested, but financial work then uses the seeded account. Prior iOS run passed; it does not establish fresh-user setup, native camera, OAuth, offline, release or Android-device readiness. | CB-19 |
| DOC-001 | Medium | README formerly described auth only; localization and offline prose imply more than the implementation. AGENTS specifies domain boundaries, shared error mapping and localization; finance providers contain orchestration classes and raw errors. Reconcile documentation and move financial logic into tested domain/use cases as affected slices change. | CB-02, CB-05, CB-11 |

## Store submission checklist

The following are requirements or submission checks, not claims that store-console
configuration was inspected. Accounts, agreements, taxes, certificates, production
Firebase, billing, domains, trademark availability and store records are **External unknown**.

| Gate | Needed evidence before submission | Owner |
| --- | --- | --- |
| Publisher identity | Select legal publisher; verify Apple/Google accounts, organization verification/D-U-N-S where applicable; confirm banking, tax and paid-app agreements | Founder |
| Membership costs | Apple lists USD 99/year; Google lists USD 25 once; local taxes/pricing may differ. [Apple enrollment](https://developer.apple.com/programs/enroll/), [Play setup](https://support.google.com/googleplay/android-developer/answer/6112435?hl=en) | Founder |
| Binary/toolchain | Apple requires iOS 26 SDK or newer since April 28, 2026; Google new apps/updates require API 36 since August 31, 2026. Local Flutter defaults resolve to compile/target 36, but the final AAB remains unverified. [Apple SDK requirement](https://developer.apple.com/news/?id=ueeok6yw), [Play API policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en) | Mobile |
| Android native compatibility | Validate Flutter/plugin ELF and package alignment and run on a 16 KB environment. Current guidance says updates without support are blocked starting February 1, 2027; recheck at upload. [Android guidance](https://developer.android.com/guide/practices/page-sizes) | Mobile/QA |
| Social authentication | If Google remains, provide an equivalent login meeting Apple's privacy criteria; recommend Sign in with Apple. Email/password alone does not provide private-email relay. Review exceptions against actual app. [Guideline 4.8](https://developer.apple.com/app-store/review/guidelines/#login-services) | Mobile |
| User deletion | In-app deletion initiation, reauthentication and Auth/Firestore/Storage cleanup; Google also requires an outside-app deletion-request route. Document retained records and retention. [Apple deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/), [Google deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en) | Backend/mobile |
| Privacy and disclosures | Public policy + in-app link; inventory identifiers, financial entries, receipts, diagnostics, analytics and SDK collection. Complete Apple privacy labels and Google Data safety from verified behavior. [Apple labels](https://developer.apple.com/app-store/app-privacy-details/), [Google Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en) | Founder/legal/mobile |
| SDK/privacy archive | Inspect the combined privacy report, required-reason APIs and applicable SDK signatures/manifests in the archive. A missing first-party manifest alone does not prove bundled SDK manifests are missing. Localize photo/camera purpose strings. [Apple SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) | Mobile |
| Financial declaration | Complete the Google financial-features declaration, selecting functions actually offered. A budget tracker is not automatically a lender or bank. [Declaration guidance](https://support.google.com/googleplay/android-developer/answer/13849271?hl=en-GB) | Founder |
| Monetization | For native digital premium access, plan StoreKit/Play Billing, server-validated entitlement, restore/refund/revocation and clear renewal terms. Country/program exceptions require separate evaluation. [Apple purchase policy](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase), [Google payments](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en) | Backend/mobile |
| Listing and review | Final name/brand/icon, licensed assets/fonts, authentic screenshots, localized descriptions, support URL/contact, age/content rating, country list, export-compliance answers and working reviewer access without dependence on local emulators | Founder/design/QA |
| Distribution testing | TestFlight + Play internal/closed track, fresh install/upgrade, physical iPhone and representative Android, permission denial, weak network and accessibility. Personal Play accounts created after Nov 13, 2023 require at least 12 continuously opted-in testers for 14 days before applying for production access; approval is not automatic. [Google testing](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en) | QA/release |

There is no verified support website, deletion endpoint, billing integration or
release pipeline in the reviewed mobile tree. Absence locally does not rule out
external work; capture URLs/console evidence when the owner supplies them.

## Regional and operational checks

LATAM launch means a country allowlist, Spanish and Brazilian Portuguese, local
currency selection and reviewed terms/support for each enabled country. Initial
validation cohorts should include Mexico, Brazil and Colombia; extend legal and
operational coverage before enabling additional countries. This is a proposed
validation order within a regional launch, not a change to a Colombia-only strategy.

Assign local counsel to map privacy notices, lawful processing, user rights,
international transfers and consumer subscriptions by territory. Starting references:
[Colombia SIC](https://www.sic.gov.co/que-es-la-delegatura-datos-personales),
[Mexico current legislation](https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf),
[Brazil ANPD](https://www.gov.br/anpd/pt-br/assuntos/titular-de-dados).
This review does not certify regional legal compliance. Adding lending, investment
advice or money movement would require a separate product/regulatory assessment.

Cloud receipt storage needs budgeted operations: Firebase states that Cloud Storage
requires Blaze from February 3, 2026 ([billing change](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024)).
Confirm billing, region, rules/index deployment, quotas, restore drill, deletion jobs,
alerts and on-call owner in staging/prod. Budget alerts are not hard spending caps.

## Verification and limits

- Executed `/Users/allensalinas/dev/tools/flutter/bin/dart analyze`: no issues.
- Executed `/Users/allensalinas/dev/tools/flutter/bin/flutter test`: 18 passed.
- Prior execution: iPhone 17e + Firebase emulators succeeded. Not rerun for this documentation audit. `+3` in that output included setup/teardown; source contains one E2E scenario.
- No release build, physical-device test, store upload, live Firebase write, purchase or external-console mutation performed.
- `git status --short`, `git -C finance_flutter status --short` and `git diff --check` could not run successfully because the mobile workspace is not a Git repository. No repository documentation validator was found.
- New Markdown is checked for local links, front matter, one H1, whitespace, conflict markers and sensitive-content patterns; full rendered mobile-table review is not performed.

Recommended first delivery: CB-04/05/07/09, a correct financial ledger and monthly
budget with honest dashboard values, while the founder executes CB-01 and account
setup. Then prove the complete flow on an empty account in staging.
