# Account identity in Settings

Implemented in the working tree on 2026-11-02. Settings (`/settings`) starts with an account identity card instead of its former introductory paragraph. This is a client-only feature; it does not require Firebase rules, Functions, indexes or a profile migration.

## Identity and creation date

`FirebaseAuthRemoteDataSource` maps the current Firebase Auth user's `metadata.creationTime` into optional `createdAt` fields on `AuthUserModel` and `AuthUser`. The local auth cache serializes this timestamp; legacy cache objects without it remain valid. Freezed/JSON code is generated, not hand-edited.

The registered-user card displays a decorative person icon, a localized heading, the complete selectable email and a secondary localized calendar date, without a time, in the device's local timezone. The icon occupies the heading row only; email and date use the full content width and can wrap. There is no edit-account action. Missing email uses a localized unavailable label; missing creation metadata omits the date rather than inventing it. The same identity model is used for password and Google sessions.

The label **En LumioMoney desde…** refers to the Auth identity's creation, not the Google account's age, app installation, latest login, financial onboarding or credential-linking date. Linking credentials to an anonymous identity retains its UID and original date. Resetting financial data retains the access identity, so a new financial profile's `createdAt` is not used. No financial-profile query or new Auth reload is added for display.

Guests see an explicit guest-session heading, the existing warning and one **Guardar mi cuenta** action in this same card. No email or membership date is displayed for an anonymous session. When there is no resolved user, the old card is absent and sign-out is disabled. The card follows the existing reactive Auth session, without reading a cached previous UID into the UI.

## Sign-out

The button keeps the existing **Cerrar sesión** label. Its confirmation identifies the registered email and preserves guest/data-loss and pending-operation warnings. Dialog content drops the previous email if the active UID changes. Confirmation is ignored when its captured UID no longer matches the current session, protecting a newly signed-in user from a stale dialog. Cancellation makes no Auth or financial mutation.

Texts are localized in Spanish, English and Portuguese. Normal wrapping, theme surfaces and semantic text remain available at narrow widths and enlarged text sizes; the decorative icon is excluded from screen-reader announcements.

## Verification

Repeatable checks:

```bash
flutter pub get
dart run build_runner build
flutter gen-l10n
flutter test test/features/auth/data/models/auth_user_model_test.dart \
  test/features/finance/presentation/screens/account_identity_settings_test.dart \
  test/features/finance/presentation/screens/guest_account_settings_test.dart
flutter analyze
flutter test
E2E_TEST_FILE=integration_test/guest_account_upgrade_test.dart \
  bash tool/run_emulator_e2e.sh emulator-5554
git diff --check
```

The integration test is restricted to `demo-clearbudget`. It checks anonymous-to-password linking, exact creation metadata/UID preservation, sign-in again, the actual Settings card and cancelled dialog, a second active identity and credential-conflict protection. These Auth/Firestore integration checks render the real Settings screen with its Auth stream; they are not a full native Google login or app-wide navigation walkthrough.

Widget/cache coverage includes legacy JSON, persisted date/domain mapping, optional fields, one guest card, long selectable email, 320dp with enlarged text, es/en/pt, light/dark, cancelled sign-out, pending warnings and account replacement while a dialog is open. The Google repository test checks creation metadata through domain mapping and cache; it does not invoke a real Google identity provider.

Physical QA uses the debug-only entry point and `tool/qa_settings_identity.dart <flutter-log> <android|iphone> [locale]`. The host requires the authorized registered QA identity in `lumiomoney`, compares visible email/date against Auth metadata, opens and cancels sign-out, checks session preservation and returns to the previous route. It never confirms sign-out or performs a financial command. Private screenshots and boolean-only results stay under ignored `artifacts/account-identity/`. The QA metadata extension is not part of the normal release entry point.


## Executed qualification — 2026-11-02

- Dependency resolution, build_runner and localization generation completed; tracked Freezed files were refreshed and ignored JSON mappings generated locally. CI now runs code generation before Flutter compilation and includes the guest/account-identity integration target. The remote workflow itself was not executed here.
- `flutter analyze` passed after import cleanup. The final full Flutter suite passed **560 tests**. The expanded focused auth/cache/Settings suite passed **25 tests**, including Google creation-date mapping/cache and the preserved guest/pending-operation safeguards.
- Android integration against `demo-clearbudget` passed both entries: linking retained the original UID/creation timestamp and synthetic account balance; Settings showed the linked account, cancelled sign-out preserved it, and another Auth account replaced the displayed identity. The credential-conflict scenario still preserved the guest.
- Final clients were built, installed and launched on the physical Android and iPhone. On each, the host compared the card's full email/date with the current QA Auth metadata, opened the actual sign-out dialog, checked its email, cancelled and confirmed the original session remained active. No real sign-out, financial command or reset was performed.
- The first host attempt waited for an unbuilt off-screen sign-out button; the harness now scrolls the real list with a bounded wait. A subsequent widget-diagnostics check omitted text produced by a Consumer despite the correctly displayed dialog; the final probe reads the actual dialog body and always cancels it in cleanup. These harness failures are not counted as passes. The initial stream-widget test also needed its close event pumped rather than awaiting it under the fake clock; the corrected focused/full suites passed.
- Private screenshots/results are ignored under `artifacts/account-identity/`; they are not versioned personal data. Build/launch and successful QA checks do not certify VoiceOver/TalkBack or a new live Google-provider login.
- No Functions, Firestore/Storage rules, indexes or production financial data were deployed or modified for this feature.

## Sign-in methods — current working-tree extension

`/settings/access-methods` is reachable from **Tu cuenta → Métodos de acceso**.
`AuthUser` and its DTO expose nullable `providerIds` and `emailVerified`; null in
legacy caches means unknown until Firebase reload, not an empty provider list.
The current Auth session is authoritative. The screen refreshes on entry, resume
and completed linking, retaining the last known list with retry on failure and
blocking additions while stale. Guests retain the existing upgrade route.

`LinkRegisteredAccessMethod` reconciles an uncertain previous result before
reauthentication and mutation. Its typed `LinkAccessMethodCommand` is ephemeral;
passwords and OAuth tokens are never serialized. The registered-user contracts
are separate from guest upgrade and deletion reauthentication. Owner assertions
are checked around asynchronous stages and results, including a changed email
before adding password. Apple reauthentication for linking never revokes the
Apple grant; deletion's explicit revocation remains separate.

Google and Apple use Firebase user linking APIs, not Auth sign-in APIs. Adding a
first password uses the reauthenticated user's `updatePassword` API with the
current non-relay email, followed by provider reload. Existing password methods
are never changed by this flow. This also avoids the Auth Emulator signUp path,
which rejects its own OAuth identity's existing email before resolving idToken.
Successful linking requires the same UID and the intended provider in Firebase.
A lost response is reconciled by reload before another attempt; a credential
already belonging to another UID is a conflict, never an automatic merge.
Verification delivery after adding an unverified email is a separate recoverable
step; delivery failure does not misreport an already committed password method.

Apple private relay addresses cannot receive a new password through this screen.
Changing to a personal email is deferred. Explicit consent is required before
linking Apple or associating another method with an Apple private-relay identity.
Methods cannot be removed. The available additions follow platform support and
`AUTH_APPLE_ENABLED`; an existing Apple identity can still reauthenticate to add
another supported method. User-facing texts are localized in es/en/pt.

This extension changes only the client, generated Auth mappings and CI coverage;
no Functions, rules, indexes, financial migration or production Auth policy is
required. `integration_test/access_methods_flow_test.dart` exercises the actual
app navigation against demo-clearbudget with a deterministic Google credential
source. It is not evidence of a live Google account chooser or Apple consent.
Native-provider QA and its remaining gaps must be recorded separately.

### Native-provider observation and qualification — 2026-11-02

The full Flutter suite for this extension passes **621 tests** and static analysis
is clean. Android Emulator qualification additionally covers password → Google,
Google → password, sign-in through both resulting methods, and a conflicting
Google credential that must preserve the two distinct identities. Its synthetic
OAuth adapter replaces only Google's external credential picker; Firebase Auth,
Firestore, application navigation and the registered-user repository are real
Emulator paths. The target is included in the Android CI job; the remote CI run
itself has not been executed here.

On physical Android with real Firebase, the owner completed Google authorization
for the approved QA account. Read-back confirms Google resolves to the same
pre-existing Auth identity and financial profile. **Firebase removed the previous
unverified password method**: the Emulator did not reproduce this trusted-provider
replacement. The screen now warns before linking from an unverified password
account and reports a removed password from the actual resulting provider list.
It never silently restores an old password that Firebase deliberately removed.
The user can reauthenticate with Google and explicitly choose a new password.

On physical iPhone, the owner completed Apple reauthentication and added a first
password to the approved Apple QA identity. Read-back confirms Apple and password
coexist on the same pre-existing UID. No financial commands were executed during
these native checks. The owner subsequently signed out and successfully signed in with Google on Android
and with the new password on iPhone. Those are owner-observed physical results,
separate from the automated backend checks; the owner also completed the live Apple-on-Google conflict in Android. The UI
reported the conflict, and backend read-back confirmed the two UIDs remained
separate, each with its original provider ownership. Successful read-back alone would not establish these login outcomes.

Earlier failed Emulator attempts are not approvals: the original password-link
signUp path hit the existing-email check, and the conflict assertion initially
assumed Spanish while the actual app locale was English. The harness now compares
the active localization rather than hardcoding that string. The production path
uses the documented authenticated-user password API for a missing password,
never a sign-up call or an Emulator-only bypass.

Remaining native matrix: successful addition of a previously unbound Apple
identity to an existing registered account, additional platform combinations,
provider cancellation and private-relay delivery. Those paths are covered by
unit/widget contracts where applicable, but are not claimed as live acceptance.
Normal release Apple activation remains gated by the existing define; QA builds
explicitly enable it. No Firebase deployment is necessary for this extension.

Final automated results for sign-in methods: **621 Flutter tests passed**, clean
`flutter analyze`, and **3/3 Android E2E passed** in demo-clearbudget. Both debug QA
clients build; iOS is development-signed. `git diff --check` and changed-content
credential scanning passed. Native-provider user input remained on the phones.
Private result files/screenshots are ignored under `artifacts/access-methods/`;
this is not a production release or a signed store-distribution acceptance.

The final session-change widget regression also clears all in-memory credential
fields and replaces the old identity's dialog if the active UID changes. The
physical checks use approved QA identities only. Final debug APK and signed iOS
builds include the unverified-password warning; neither artifact is a store
release. Live cancellation/private-relay and successful addition of an unused
Apple identity remain unqualified; the conflict test is not counted as successful
Apple linking.

The final development clients were installed/launched after the session-change
regression. Android's latest screen was inspected successfully. The final iPhone
inspection lost the wireless VM connection after launch (device changed from
connected to paired/available), with no Dart/crash signal in the retained run log.
This limits the last automatic UI inspection; it does not replace or invalidate
the earlier physical linking and owner-observed login results above.
