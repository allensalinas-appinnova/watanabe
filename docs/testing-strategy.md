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
- `integration_test/auth_flow_test.dart`: emulator connectivity preflight,
  account creation through the UI,
  email sign-in, owner-only Firestore access, navigation across
  Dashboard/Activity/Budgets/Accounts, account filtering, budget-limit editing,
  expense entry with receipt upload and owner-only Storage access, atomic
  account-balance and budget-total updates, password reset, anonymous sign-in
  and sign-out, plus account rename/delete with transaction and receipt cleanup.

Google OAuth is wired but requires per-platform Firebase/OAuth configuration
and is not exercised against the Auth Emulator. Password reset, budget-limit
editing, account management and receipt attachment are exercised by the
Auth/Firestore/Storage Emulator E2E.

The Figma-backed first mobile vertical slice includes Dashboard, Activity,
Budget planner, Accounts and Add expense. Transfers, income entry, category
management, editable budgets, budget tracking, reports and imports remain
outside this slice. Each feature delivery must include domain/use-case tests,
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
