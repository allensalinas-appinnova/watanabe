# Coach: actionable guidance, daily check-in and weekly review

## User functionality and delivery boundary

Coach is an action-oriented hub: it explains one shared next step on Home and
Coach, surfaces upcoming debt commitments and unallocated debt payments, and
offers weekly observations alongside daily and weekly reviews. Daily and
weekly review routines are user-selected independently of operating-system
notification permission. Local reminders remain optional and can be enabled
independently, scheduled at local hours/minutes; daily reminders use selected
ISO weekdays (Monday = 1, Sunday = 7). Home can show or hide the optional
next-step widget. Completing a check-in or review records that period's
completion; it does not create or modify financial movements, balances,
budgets, ledger entries or summaries.

This document defines the shared contract for the integrated app, Firestore
rules, rule tests and repository persistence tests. Platform behavior remains
subject to the verification evidence below.

## Canonical design references

Use `Personal Finance Mobile — ClearBudget`, page `07 P0 Screens` (`325:3059`).
The following editable canonical frames were created and inspected. Platform
visual acceptance is separate from these Figma references.

| View | Canonical node |
| --- | --- |
| Coach settings | `590:1058` |
| Daily check-in | `590:1059` |
| Weekly review | `590:1060` |
| Next-step card | `591:1072`, in Home `329:23` |
| Empty state | `590:1062` |
| Actionable Coach hub (proposal) | `617:970` |
| Compact Home next step (proposal) | `620:982` |
| Weekly review hierarchy (proposal) | `620:1006` |

The three new proposal frames are on `07 P0 Screens`; they do not modify
`00 Current Baseline`. They preserve the existing Inter/Material 3 system,
palette roles and financial semantics.

## Actionable overview contract

`CoachOverviewCalculator` is the shared pure-domain decision engine. Home and
Coach consume the same `coachOverviewProvider`; the UI localizes typed action
and insight identifiers rather than constructing financial decisions in
widgets. Current priority is rejected sync, due current-month commitment,
unallocated payment, commitment due within seven days, reached positive expense
budget, selected weekly review, selected daily review, routine invitation, and
neutral status. A commitment appears as “no payment recorded” rather than as a
claim that the bank considers it overdue. Only current and next-month
occurrences are candidates; older months remain in Plan and never accumulate
as Coach tasks.

Weekly observations are limited to verifiable facts: net top spending
category per currency (including refunds and reversals), a reached budget, and
incomplete information. Budget progress sums only movements linked to the
budget item; the category's unrelated transactions are not attributed to it.
Unavailable sources remain loading/error states, and cached data is marked as
possibly incomplete. The report uses the shared financial-operation mapper so
Coach and Activity retain debt metadata, reversals and operation grouping.

The optional `users/{uid}.coachRoutinePreferences` map contains exactly
`configured`, `dailyEnabled`, and `weeklyEnabled` booleans. If it is missing,
older profiles infer a chosen routine from enabled legacy reminder settings;
otherwise the Coach offers an invitation. Choosing or suspending an in-app
review routine does not request notification permission. It gates only the
matching routine reminders; debt commitment reminders remain independently
controlled. Manual daily and weekly reviews remain available at all times.

Coach amount privacy is a device-local presentation preference, separate from
Home's amount visibility. Analytics uses only allowlisted event names for
opening Coach, opening an action, choosing a routine, and completing a review;
no transaction amounts, descriptions, account names or financial identifiers
are attached.

## Local reminders and synchronization contract

Mobile reminders are local notifications. Schedule individual one-off notices
over a rolling 28-day local horizon and renew that horizon when the app opens.
Delivery beyond that horizon requires reopening the app. Notification permission,
device settings and operating-system scheduling affect delivery. Web exposes
the coach UI only; mobile notices are not web push or server-scheduled messages.

Only a completion made locally suppresses its local pending reminder before
remote synchronization succeeds. Preserve that local completion while offline
and retry its remote write; remote acknowledgment is not required to suppress
the local notice. Do not infer cross-device cancellation or guaranteed delivery
from a Firestore completion. Verify remote reconciliation separately.

## Firestore contract

`users/{uid}.coachPreferences` is optional. Missing preferences use app defaults;
rules do not supply defaults. If present, the map must contain exactly all eight
fields below, on both profile creation and update. Removing the entire optional
map is allowed; removing an individual required member is rejected.

| Field | Required type and bounds |
| --- | --- |
| `dailyEnabled`, `weeklyEnabled` | Boolean |
| `dailyHour`, `weeklyHour` | Integer, 0–23 |
| `dailyMinute`, `weeklyMinute` | Integer, 0–59 |
| `dailyWeekdays` | Nonempty list, at most seven unique integers, each 1–7 |
| `weeklyWeekday` | Integer, 1–7 |

`homePreferences.widgets.coachNextStep` is an optional boolean. Its absence is
compatible with older profiles. All six existing widget keys remain required
when Home preferences are present. The existing Home creation/update boundary
and financial permissions are preserved.

Completions live at:

- `users/{uid}/coachDailyCheckIns/{YYYY-MM-DD}` with `kind: 'daily'`.
- `users/{uid}/coachWeeklyReviews/{YYYY-MM-DD}` with `kind: 'weekly'`.

Each completion contains exactly `periodKey`, `kind`, `noMovements`, and
`reviewedAt`. `periodKey` is a string equal to the document ID. Its format uses
four-digit years, months 01–12 and days 01–31. This is a bounded date format,
not calendar validation: the app must choose real local dates and the proper
weekly period key consistently. Rules do not enforce a particular weekday for
weekly review IDs.

`noMovements` is boolean; weekly reviews require `false`. `reviewedAt` must be
a timestamp equal to `request.time`, written with `serverTimestamp()`. Client
clock timestamps are not the write contract. Replays and updates at the same
period path are allowed with a fresh server timestamp and the complete valid
resulting schema; they replace one completion rather than adding finance data.

Only the path owner may read, query, create or update completions. Deletes are
denied. An existing parent profile is required for both create and update;
create the profile before writing completions. Collection queries scoped to
the user's path can filter/order by `periodKey` or document ID. Unscoped
collection-group queries are not supported. Profile access remains owner-only.

## QA and deployment evidence

Latest actionable-Coach verification on 2026-10-28:

- `flutter analyze`: no issues. Full `flutter test`: **389 tests passed**;
  focused Coach and shell tests also cover opt-in routine setup in Spanish,
  English and Portuguese, selected daily/weekly combinations, preserving
  existing preferences, and the single global Settings entry point.
- Android persistence integration: **3 test cases passed** on `emulator-5554`
  against Auth and Firestore Emulator using synthetic `demo-clearbudget` users.
  This includes independent routine choices and their offline-to-server
  acknowledgment. It did not use real Firebase or create financial records.
- Firestore Rules Emulator: **25 tests passed**. `firestore.rules` was then
  deployed to `lumiomoney` with
  `firebase deploy --only firestore:rules --project lumiomoney --non-interactive`;
  Firebase confirmed the rules release. No Functions or indexes were deployed.
- Android debug and iOS simulator builds succeeded. A debug QA build was also
  installed and launched on the physical iPhone on 2026-10-28. With the
  existing QA profile, Coach showed its saved routines, the Settings action
  opened the shared Configuration screen, and the app reported healthy with
  no runtime errors. The QA profile and its financial data were not changed.
  The first-time invitation state was verified in widget tests rather than by
  changing the real QA profile. This does not certify notification delivery.
- `git diff --check` passed; hot reload succeeded on the connected iPhone.

- Static checks: `node --check functions/test/firestore_rules_test.mjs` and
  `git diff --check` passed on 2026-10-22. These do not compile Firestore rules.
- Rules Emulator suite: **16 tests passed** on 2026-10-22 using
  `./tool/run_rules_tests.sh` with `demo-clearbudget`.
- The suite includes existing finance regression cases plus coach access,
  create/update validation, missing/deleted members, unexpected fields, weekday
  duplication/types/ranges, bounded dates/path identity, parent existence,
  timestamps, replay, no-delete and scoped-query cases.
- Flutter repository persistence: `integration_test/coach_persistence_test.dart`
  tests the real adapter with synthetic Auth/Firestore data, preferences,
  daily/weekly completions, replay, period filtering and offline pending-write
  metadata followed by server acknowledgment. **Both persistence tests passed**
  on 2026-10-22 on iPhone 18 Pro Simulator
  `ED4C909E-0DD1-4DA1-9E51-3DAF04E1FB5F`, using `demo-clearbudget` Auth/Firestore
  on ports 59199/59180. Xcode build: 150.5 seconds; Flutter test execution:
  approximately 6 seconds. The harness reported `+4` including setup/teardown;
  there are two persistence test cases. Drive exited 0 and its emulators shut
  down. No physical device or real project data was used.
- Integrated app/UI suite: **289 tests passed** and `flutter analyze` found no
  issues on 2026-10-22. Coverage includes command-correlated late failures,
  session/period changes, reactive report updates, historical completion reads,
  retry eligibility, scheduler lifecycle, compact layout and es/en/pt at 1.5x.
  Native adapter regressions cover iOS returning `false` while permission
  requests are deferred, and rejection of a null initialization result.
- Android delivery: actual delivery on Android emulator `emulator-5554`
  **passed** on 2026-10-22. Pending and delivered requests were observed through
  the native SDK, then cleared. Owner callback dispatch uses injected callbacks;
  that portion does not establish a real notification tap. Android debug builds
  passed. A signed release remains dependent on release signing configuration.
- Web: **successful build** and **persistent browser process test** on
  2026-10-22. Web remains UI-only
  for coach notices; these results do not establish mobile notification delivery.
- iOS simulator app build: **success in 559.7 seconds** on
  2026-10-22. This full app build is separate from the passing repository
  integration run and its 150.5-second test build above.
- Physical iPhone notification delivery: **passed** on 2026-10-22 on the
  connected iPhone 16 Plus. The native SDK observed the OS-delivered notice
  (`COACH_NATIVE_RECEIVED platform=iOS id=20261022`) at 18:25:25 UTC. Permission,
  cancellation and stale-owner rejection passed. Owner callback dispatch was
  injected; this does not establish a real notification tap or cold launch.
  The runner did not initialize Firebase or write financial data.
  After the test, the normal `lib/main.dart` client was rebuilt, installed and
  launched on the same iPhone with the existing real dev Firebase configuration;
  no financial test records were created. Existing app data was preserved.
- Remaining manual acceptance: real notification taps with the app closed,
  physical multi-device synchronization and screen-reader walkthroughs.
  Permission denial, horizon renewal and session cancellation are covered with
  doubles; this is distinct from OS delivery and real multi-device evidence.
- Rules deployment: **deployed and verified** on 2026-10-22 using
  `npx -y firebase-tools@latest deploy --only firestore:rules --project lumiomoney --non-interactive`;
  The CLI exited 0 and released `cloud.firestore`; remote source readback
  matched the local file exactly. The pre-deploy backup is at ignored
  `.dart_tool/coach_rules_before.rules`. No Functions were deployed. This
  publication proof is separate from simulator tests against `demo-clearbudget`.

From the repository root, with an already running `demo-clearbudget` Firestore
emulator on port 59180, run:

```sh
npm --prefix functions run test:rules
```

The suite uploads these rules and clears synthetic project data between tests;
coordinate it with other emulator users. To start an isolated test run later,
the main agent can use the existing runner:

```sh
./tool/run_rules_tests.sh
```

For the Flutter persistence test with already running Auth/Firestore emulators
and an iOS simulator, specify the simulator ID (never a physical device):

```sh
E2E_PLATFORM=ios FIREBASE_EMULATOR_HOST=127.0.0.1 \
  FIREBASE_AUTH_EMULATOR_PORT=59199 FIRESTORE_EMULATOR_PORT=59180 \
  ./tool/run_coach_tests.sh ED4C909E-0DD1-4DA1-9E51-3DAF04E1FB5F
```

Set `COACH_START_EMULATORS=1` to have the runner start Auth and Firestore using
the configured default ports for `demo-clearbudget`. Custom port overrides
require already running emulators. The persistence test uses new synthetic
anonymous users and never clears shared emulator data.

The successful 2026-10-22 persistence invocation used the iOS command above
with `COACH_START_EMULATORS=1` to start isolated Auth/Firestore emulators. The
runner refuses a launch while an Xcode operation is active in this checkout.

Native notification delivery (no Firebase initialization or financial writes):

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/coach_notifications_test.dart -d <mobile-device-id> \
  --dart-define=APP_ENV=dev --dart-define=USE_FIREBASE_EMULATORS=true
```

The iPhone requires permission through its native prompt. Android requires the
notification permission before the bounded delivery test can complete.
