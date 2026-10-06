# Automated Testing Strategy

## Test layers

| Layer | What it covers | Command |
| --- | --- | --- |
| Unit | Entities, use cases, repositories, DTO mapping, formatters and failure mapping | `flutter test test` |
| Widget | Form validation, loading/error states, navigation and accessible controls | `flutter test test` |
| Integration/E2E | Real Flutter UI + Firebase Auth/Firestore Emulator Suite | `./tool/run_emulator_e2e.sh` |
| Build smoke | Compile target platforms after material changes | platform-specific `flutter build` |

All tests must be deterministic, use synthetic data and avoid production Firebase projects.

## Firebase Local Emulator Suite

The checked-in `.firebaserc` selects the reserved `demo-clearbudget` project ID.
`tool/run_emulator_e2e.sh` explicitly supplies this project and starts Auth,
Firestore and Storage, then executes the Flutter integration test while those emulators
are running. The Flutter bootstrap switches endpoints only when
`USE_FIREBASE_EMULATORS=true` is set.

Default emulator endpoints:

- Auth: `127.0.0.1:59199`
- Firestore: `127.0.0.1:59180`
- Storage: `127.0.0.1:59191`
- Emulator Suite UI: `127.0.0.1:59100`

The test project ID starts with `demo-`, so Firebase CLI cannot accidentally
target a live Firebase project. Never remove this protection from the E2E
script. Android emulators use `10.0.2.2` as the host. iOS simulators use
`127.0.0.1`; physical devices need the development machine's reachable LAN
address. Chrome on this machine uses `127.0.0.1`.

The Firebase Auth/Firestore/Storage test requires Node.js, Firebase CLI (invoked with `npx`),
Java supported by the currently downloaded emulator, Flutter, and an Android
or iOS simulator (or attached device). By default the runner targets Android's
`emulator-5554` with host `10.0.2.2`. For an iOS simulator, set
`E2E_PLATFORM=ios` and `DEVELOPER_DIR` to the selected Xcode developer path;
the default host is `127.0.0.1`. Pass the target device ID as the first
argument. Set `FIREBASE_EMULATOR_HOST` when using another target, for example
a physical device's reachable development-machine address.
The suite is isolated per invocation and its emulator data is discarded when
the `emulators:exec` process exits.

The Firestore/Auth emulators require a Java runtime on the PATH. Unit and
static-analysis tests remain independent of Java; emulator E2E cannot run until
the local Java runtime is installed.

On macOS with Homebrew JDK 21, configure the shell before running the suite:

```bash
export JAVA_HOME="$(brew --prefix openjdk@21)"
export PATH="$JAVA_HOME/bin:$PATH"
./tool/run_emulator_e2e.sh
./tool/run_rules_tests.sh

# Verifies the 100-record cursor and filtered month/currency query
./tool/run_pagination_test.sh
```

The canonical integration test contains both a fresh-user UI onboarding check
and repository-level invariants for income, expense, transfer, ledger entries,
idempotency and itemized budgets. Android uses `10.0.2.2`; iOS Simulator uses
`127.0.0.1`. If `adb install` hangs, restart the selected emulator and verify
that no previous `firebase emulators:exec` process still owns ports 59180,
59191 or 59199.

## Current automated coverage

- `test/core/utils/currency_formatter_test.dart`: COP number formatting.
- `test/features/auth/data/repositories/auth_repository_impl_test.dart`:
  email/Google repository mapping, failure conversion and cache invalidation.
- `test/features/auth/presentation/screens/login_screen_test.dart`: client-side
  validation, switch to account creation and password visibility control.
- `test/features/finance/data/repositories/finance_repository_impl_test.dart`:
  atomic budget-limit update delegation and failure mapping.
- `test/features/finance/data/datasources/receipt_image_picker_test.dart`:
  image selection, supported content types and cancellation.
- `integration_test/canonical_finance_flow_test.dart`: fresh-user UI onboarding,
  emulator connectivity preflight, canonical account creation, localized user
  profile, income, expense, transfer with two ledger entries, idempotency key and
  itemized budget persistence.
- `functions/test/firestore_rules_test.mjs`: unauthenticated access, user
  isolation, catalog reads, calculated-field protection and invalid operations.

Google OAuth is wired but requires per-platform Firebase/OAuth configuration
and is not exercised against the Auth Emulator. Password reset, budget-limit
editing, account management and receipt attachment are exercised by the
Auth/Firestore/Storage Emulator E2E.

The canonical vertical slice includes onboarding/category bootstrap, Dashboard,
Activity, Accounts, income, expense, transfer, itemized budgets and budget
tracking. Each feature delivery must include domain/use-case tests,
repository tests, widget tests for its key states and emulator-backed
integration tests for Firebase persistence and access rules where applicable.

## CI guidance

Run unit/widget tests on each pull request. Run the emulator E2E job on pull
requests that affect authentication, Firestore data sources, security rules,
navigation or shared application startup. Cache Flutter/Dart packages and
Firebase emulator binaries when the CI platform permits it. Do not store or
inject production credentials into emulator tests.

## References

- [Firebase Auth Flutter setup and Auth Emulator](https://firebase.google.com/docs/auth/flutter/start)
- [Connect the app to the Auth Emulator](https://firebase.google.com/docs/emulator-suite/connect_auth)
- [Connect the app to the Firestore Emulator](https://firebase.google.com/docs/emulator-suite/connect_firestore)
- [Test Firestore Security Rules](https://firebase.google.com/docs/firestore/security/test-rules-emulator)
