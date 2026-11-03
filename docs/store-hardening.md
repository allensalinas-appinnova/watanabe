# Store hardening and audit remediation

Implementation date: 2026-11-02. This document distinguishes checkout implementation, local qualification and live publication. It does not certify a store release.

## Offline ownership and interrupted delivery — AUD-01 / AUD-02

The outbox schema is version 2. `ownerUserId` is indexed separately from the immutable financial payload. Migration copies a verifiable payload owner; ownerless/malformed legacy records enter `quarantined`. They are not displayed as another user's financial records, sent, automatically removed, or reassigned. The shell offers a generic notice and explicit local discard confirmation.

Selections, counters, reset cleanup and delivery are owner-scoped. A session epoch stops further sends and ignores obsolete callbacks. Each atomic claim has a technical attempt ID and a 120-second lease. Expired claims can be retried with the original financial request ID and generation. A callback can complete only its matching owner/attempt. A 121-second recovery check is scheduled while an interrupted claim remains active. Confirmed requests cannot be revived by enqueueing the same key; different payload/owner content conflicts locally.

New `mutateOperation` requests include `expectedOwnerUid`. The server compares this assertion to Firebase Auth before parsing/receipts, discards the assertion from the canonical financial payload, and continues deriving the effective UID from Auth. Older clients remain wire-compatible while the updated client is distributed. This change does not recalculate balances or repair historical projections.

## Calendar and integration lifecycle — AUD-10 / AUD-11

Home and default Activity/Plan periods consume the existing profile calendar and injectable clock. Manually selected periods are retained. Tests control October 2026 explicitly instead of depending on the current date, dispose UI listeners before identity changes, and locate the balance through deliberate scrolling.

Explicit `FIREBASE_EMULATOR_HOST` values disable FlutterFire's automatic localhost-to-10.0.2.2 mapping. This is necessary for physical Android devices using `adb reverse` and `127.0.0.1`; default emulator mapping remains available when no host define is supplied. Emulator clients continue using the named `demo-clearbudget` Firebase app, separate from the native real-project Auth session.

## Account deletion and Apple — AUD-03 / AUD-04

`requestAccountDeletion` accepts `{requestId, expectedGeneration, expectedOwnerUid, confirmed:true}` with Firebase Auth and App Check. The owner assertion must match Firebase Auth; the effective UID is still derived exclusively from Auth, never from a caller-supplied UID/email. Registered identities require `auth_time` within five minutes unless the same persisted request was already accepted. Request content is digested for idempotency. Acceptance blocks writes using a deletion marker and increments the profile generation before acknowledging.

`processAccountDeletion`, the private `processAccountDeletionTask` queue and `retryAccountDeletions` provide leased, retryable cleanup. An accepted request is durably dispatched with a deterministic task identity; the document trigger and periodic retry provide recovery. Cleanup: disable/revoke Auth, delete user Storage prefixes by object generation, recursively delete financial/resource records, redact audit identifiers, remove operator membership, delete Auth, then finalize a minimal marker. Missing Auth identities are successful retries. Completed markers expire after 90 days. No cancel-after-acceptance flow is offered.

Only already aggregated, known operational cost subtotals are added idempotently to `anonymousUsageTotals/{month}` without UID, names or receipt references. These expire after 400 days. In-flight usage, storage events and maintenance commits check deletion markers; financial commands read the invalidated profile generation. Rules prevent cached-token reads, writes, profile recreation and reserved uploads during deletion.

The mobile deletion command preserves UID, generation and request ID through errors. A generation conflict requires explicit reload. Accepted requests clear owned outbox/media/reminders and auth cache. Firestore disk persistence cannot be cleared while the SDK is active: a durable flag clears it before the first Firestore operation on next startup; authentication and the server marker block further account access immediately. Local cleanup interrupted by process termination resumes on startup. Lifecycle cache/notice flags are scoped by Firebase project, and interrupted cleanup signs out only the same deleting UID, never a subsequently authenticated user. Unknown legacy outbox records remain quarantined under the separate agreed policy.

Apple provider sign-in, guest linking and reauthentication are implemented through Firebase provider APIs. Credential conflicts do not merge accounts; linking checks unchanged UID. Deletion revokes a freshly reauthenticated Apple grant using the native authorization code on Apple platforms or the supported Firebase token-revocation endpoint elsewhere. On 2026-11-02, the owner authorized and we configured the native capability for `com.appinnova.lumiomoney.app`, Services ID `com.appinnova.lumiomoney.auth`, Firebase callback and an exclusive Apple key. Firebase read-back confirms the enabled provider with the expected bundle/team/service identifiers. The private key is outside the repository with owner-only filesystem permissions. The Runner entitlement preserves the existing App Group and adds Sign in with Apple. A signed development iOS build succeeded; embedded provisioning and codesign entitlements confirm both capabilities under the expected team, with the renewed profile expiring on 2027-11-02. A subsequent physical iPhone QA run enabled Apple only through its launch define. The owner completed native authorization; the application reached Home and a read-only Firebase Auth lookup confirmed `apple.com` on the authenticated identity. No financial commands were executed. Guest linking, cancellation/conflicts, Android/web Apple and revocation remain unqualified in production; distribution defaults remain off.

Apple and deletion activation default to off through `AUTH_APPLE_ENABLED` and `ACCOUNT_DELETION_ENABLED`. Public help links are enabled following verified Hosting publication. Production deletion also requires server policy `servicePolicies/accountLifecycle.deletionEnabled == true`. Do not activate while external prerequisites or qualification remain blocked.

## Public site and privacy

`public_portal` is a separate Firebase Hosting site (`lumiomoney-support`), independent from administration. It includes support, draft privacy and authenticated deletion routes. Firebase code loads only for deletion. Auth supports password/Google and gated Apple; deletion requires App Check configuration, explicit confirmation, matching active UID and the existing server command. Shared links never analyze documents or perform financial operations.

Controller confirmed by the owner: Appinnova SAS, Medellín, Colombia. Active public contact confirmed: lumiomoney@appinnova.co. The public notice reflects the technical inventory; store disclosures and legal review remain distinct qualification work. Configure the web Firebase app/domains and `VITE_APP_CHECK_WEB_SITE_KEY` before enabling web deletion. The separate site is published at https://lumiomoney-support.web.app and native privacy/support links are enabled. Its two Hosting domains are authorized in Firebase Auth. Public deletion remains off until web App Check and production lifecycle qualification are complete; the page honestly offers support rather than an enabled deletion form.

## Resource maintenance and tariffs — AUD-06

Maintenance jobs have an exclusive lease, run identity, cutoff and durable cursor. User pages contain at most 100 documents; events, inventory objects and provider listings use pages of at most 250. Cost event pages checkpoint independently; publication of a user's monthly/daily result is transactional only when its scan finishes. The previous complete result remains visible during refresh. Tariff changes invalidate incompatible in-progress cost state.

Storage listings and per-user inventory resume independently. Absence from a listing never proves deletion: provider metadata is checked before releasing capacity. Inventory remains diagnostic and never overwrites occupied-byte counters blindly. `continueResourceMaintenance` resumes interrupted jobs every 15 minutes without starting another complete daily scan. Deletion checks protect per-user stage/result writes.

The portal exposes missing, expiring-within-30-days and expired tariff states. Known subtotal, component coverage, incomplete attribution and last update remain separate. This is not a full per-user provider invoice or a measured commercial margin.

## Release and validation — AUD-05 / AUD-08

Node major version is 22; Flutter is pinned to 3.47.4. Release runtime rejects `APP_ENV=dev`. `tool/build_store_release.sh` requires explicit staging/prod, validates the Firebase registration/platform, then builds a signed AAB or IPA. The manual store workflow requires private signing/configuration secrets and does not upload to stores. No signing secrets belong in Git.

Local production defines were derived from the existing platform registrations and verified to target lumiomoney. They remain ignored/private. Android upload signing material is not configured. The iOS release app compiled with `--no-codesign`; this is not an IPA, signed archive or TestFlight acceptance. SDK privacy bundles are present in the app, but they do not establish complete App Store privacy disclosures or required-reason coverage for first-party code.

Qualification evidence is retained locally under `artifacts/` and temporary sanitized result files. Verified results on 2026-11-02:

- Full Flutter suite: **580 passed**; static analysis clean. These include owner-scoped queue lookup, original draft generation after reset, Apple grant revocation and lifecycle-disposal regressions.
- Canonical Android E2E on API 35 against `demo-clearbudget`: **3/3 passed**. Full account-deletion UI E2E: **1/1 passed**, including accepted request, login return, persisted completion and rejected former credentials. The final rerun after project-scoped preference keys also passed **1/1** in 30 seconds.
- Functions projections/commands: **31 passed**; actual Emulator projection trigger: **1 passed**.
- Deletion core: **5 passed**; actual deletion trigger/callable: **2 passed**; Firestore rules: **28 passed**; Storage rules: **3 passed**.
- Document/resource/tariff/pagination and rules suite: **84 passed** on Node 22. The admin portal's **2 tests** and both portal builds passed.
- Physical Android and iPhone debug QA: registered principal identity/date shown correctly in Settings, sign-out dialogue opened/cancelled and session preserved. No financial commands or real deletion were executed. This does not qualify distribution App Check, Apple sign-in, offline financial operations or native receipt sharing for the final release binary.
- Earlier API 37 AVD service failures and Xiaomi installation restrictions were environmental blocks, not successful E2E results; the later API 35 and allowed physical installations supplied the positive evidence above.
- Production read-back: `mutateOperation`, lifecycle workers, continuation scheduler and deletion callable are ACTIVE. Technical TTL policies are ACTIVE. Unauthenticated deletion HTTP returns 401. Production deletion policy remains **false**.
- Scoped organization-policy exceptions were applied only to the specifically authorized deletion callable. Its handler still enforces Auth and App Check. The task worker is private; only its runtime identity has invocation/enqueue and self-act-as permissions at the required resources.
- Financial ownership command, affected resource/admin/maintenance Functions, Firestore/Storage rules, administrative Hosting and public Hosting were published. Apple provider configuration was verified independently. No production balances were repaired and no real account was deleted.

Remaining release gates: web App Check and a disposable production deletion qualification; remaining live Apple linking/revocation and other-platform checks; Android upload keystore (explicitly deferred); Apple Distribution certificate/signed archive; store privacy declarations and distribution App Check/notification/device acceptance. Do not enable deletion or claim global store acceptance while these remain unresolved.

## Deferred work

Subscriptions/entitlements (AUD-07) and preferred-name/personalized greetings (AUD-09) are outside this remediation. Store readiness remains conditional on the outstanding gates above, even after the reliability changes qualify.
