# Receipt import qualification

Working-tree qualification on 2026-11-01. No production financial transactions are used in this qualification. Deployment status is recorded separately below.

## Evidence

- Flutter full suite: 508 passed in the final rerun; `flutter analyze` reported no issues and `git diff --check` passed.
- Android Emulator: the actual app completed offline selection → retained local draft → explicit analysis → review → one expense and retained receipt. Bank COP 100,000 became COP 75,000, one operation and one attachment were persisted, one analysis unit was used, and the attachment could be read. Only camera/file picking and connectivity were controlled; the external AI was a deterministic Emulator fixture.
- Server document/security rerun: 18 document/cost/observation tests, two feature security tests and 27 existing Firestore rules tests passed. Coverage includes image/PDF validation, account identification, bank/card approvals, replay, quota reservation/refund, reset, late events and object deletion.
- Financial regression: 89 tests passed across operations, corrections, debts, budgets, follow-ups, adjustments, generations, reset and projections. Twelve additional real callable/trigger tests passed against Firebase Emulator.
- iOS device build: `flutter build ios --debug --no-codesign` passed after aligning Firebase Core 4.15.0 and App Check 0.4.8 with the existing iOS SDK 12.19.0. This is a build result, not a physical-device walkthrough.
- Android debug APK was built both by the passing E2E run and separately from the normal application entry point (`flutter build apk --debug`). Portal production build passed.
- iOS Simulator completed the receipt E2E with synthetic data. Android also passed with the final Firebase dependency alignment: its structured result reports project `demo-clearbudget`, one operation, one attachment, bank balance `75000` and one analysis unit. Device discovery and the AVD crash-report dialog initially blocked the repeat; restarting without snapshots and without sending crash reports recovered it. The failed startup attempts were not counted as application successes.

## Real provider evaluation

`functions/tool/evaluate_receipts.mjs` generated thirty synthetic, text-only PDF receipts in es/en/pt, with an explicit total, subtotal, tax, date and partial payment reference. Raw receipt content was not added to operational logs. `functions/artifacts/receipt-evaluation/results.json` stores expected-field equality, reported token units, model and latency only.

Thirty cases produced 27 usable API responses and three HTTP 504 technical failures. Of the 27 responses, 26 matched expected amount, currency and date; all 27 recognized the document as supported. The median latency including failures was 6.524 seconds; maximum was 87.916 seconds. Those observations qualify a review-assisted beta, not unattended financial posting. They do not represent measured accuracy on real customer receipts, blurred photos or every bank format.

Three additional synthetic PNG receipts were evaluated with the current single-attempt SDK configuration: two matched all checked fields; one recognized the receipt but did not match all expected fields. `functions/artifacts/receipt-evaluation/images.json` contains that evidence. The client always requires review and confirmation; missing/invalid values do not become invented defaults. Technical failures preserve drafts and refund commercial quota, while unknown provider costs remain pending.

The first PDF benchmark process used the SDK's default retry behavior. Production code subsequently disabled automatic SDK retries so explicit technical attempts can be accounted for; the PNG benchmark exercised that configuration. Benchmark calls are shared qualification costs, not user commercial quota.

## Cloud configuration observed

- Vertex AI API enabled and model `gemini-3.8-flash` responded to synthetic PDFs and PNGs.
- Private default bucket `lumiomoney.firebasestorage.app` provisioned in US-CENTRAL1; public access prevention enforced.
- Android Play Integrity and iOS App Attest configs registered, token TTL one hour. The physical iPhone debug provider was validated; release App Attest and Android Play Integrity still require platform-specific release validation.
- Dedicated document/job runtime identities and scoped Storage/BigQuery permissions provisioned.
- Standard Cloud Billing export enabled through Google Cloud Console with explicit operator confirmation, targeting private `lumiomoney.lumio_billing`. Initial export availability is asynchronous.
- The standard export table exists and an explicitly project-scoped query succeeded with zero rows. Reconciliation records `billing-export-awaiting-data`, not zero costs or a successful empty cost reconciliation.
- Server policy initially disabled; limits and expiring AI tariffs seeded through the reviewed provisioning script.
- After the physical iPhone QA identity and protected access check passed, document analysis was enabled for registered users with limits of five/day, twenty/month and 100,000,000 retained bytes. The policy was read back after activation. This did not create a production financial operation or document import.
- Firestore and Storage rules, indexes and TTL declarations deployed. All composite indexes were read back as `READY`; existing administrative/device TTLs were preserved.
- Both Storage object triggers were successfully deployed after granting the dedicated job identity Eventarc receiver permission. The Storage service agent has Pub/Sub publisher permission for event delivery.
- All ten new callable/trigger/job Functions were read back as `ACTIVE`. Analysis concurrency is two, attachment reads four and scheduled jobs one per instance. The six new callables have only service-scoped `allUsersIngress=True`/HTTP invoker exceptions, authorized by the operator; unauthenticated HTTP requests returned 401. Auth/App Check and administrative-role checks remain in the handlers.
- The administrative portal was published to `https://lumiomoney-admin.web.app`. Its new consumption page was opened successfully with the authorized Google operator, showing quotas, storage and explicitly incomplete cost coverage. No financial records or receipt content were accessed.

## Remaining release observations

Authenticated production mobile access passed on the physical iPhone using the registered debug App Check provider, and analysis was activated after this check. Administrative production authentication was verified separately through the portal. A real receipt import/financial posting on a physical phone was not performed; end-to-end financial qualification remains the synthetic Emulator evidence. Release attestation and actual camera/file permissions remain separate platform checks. Web protected imports require a configured App Check site key; no browser receipt end-to-end acceptance is implied by mobile builds. Store privacy disclosures and the public policy must be updated before consumer distribution.

Dependency audit after compatible fixes reports no high/critical runtime advisory, with seven moderate runtime advisories still present; test/development tooling has additional advisories. This is not a clean security audit and no forced major Firebase upgrade was applied during qualification.

## Physical iPhone access check

The operator authorized preparing the debug QA client on the connected iPhone. `tool/run_ios_qa.sh` requires project `lumiomoney` and disables Emulator routing. Its normal release entry point is unchanged. `test_driver/main_qa.dart` preserves the real keyboard and exposes two read-only diagnostics: session identity and protected resource-usage access, restricted to the named primary QA account. It does not create a document import, payment or movement.

After Flutter exposes its VM service, run `dart run tool/qa_resource_probe.dart <private-flutter-log> session` before `resource-access`. The probe reads the VM URL privately and returns no Auth or App Check tokens. Keep device logs private because the native debug App Check provider can print its registration token. A valid debug provider proves the QA transport; it does not qualify release App Attest or Android Play Integrity.

The physical-device build completed and the updated QA app was installed and launched. The initial session was not the primary QA identity, so the protected usage probe was not run for that user. The operator then signed in directly on the phone. The session probe confirmed `allensalinasjaramillo@gmail.com`, project `lumiomoney`, the expected iOS app and a non-anonymous session. The protected probe returned `authenticated=true`, `appCheck=true`, `usageRead=true` from the deployed `getResourceUsage` callable. The iPhone debug App Check registration was added for this app only, without disabling enforcement. No financial command, reset or document analysis was executed during this physical-device check.

## Authorized physical receipt walkthrough: prepared, environment blocked

The operator subsequently authorized retaining one synthetic COP 25,000 expense and its attachment in QA Banco. The read-only baseline was COP 2,710,000, nine operations, zero attachments and zero imports; the expected bank result is COP 2,685,000. This authorization is specific to this synthetic receipt and does not authorize unrelated financial writes.

A synthetic PNG marked QA was generated. A separate Vertex qualification call recognized COP 25,000, COP currency, date 2026-11-01 and personal-care category in 10,744 ms, reporting 2,171 total tokens. This is provider evidence, not evidence of a saved mobile import or a user quota charge.

The debug-only entry point can stage this synthetic image without replacing an existing draft; the host walkthrough refuses accounts other than the primary QA identity. The iPhone build passed after replacing the incompatible CocoaPods-only sharing dependency with the Swift Package Manager compatible receiver and removing the automatically generated residual Podfile. Xcode's own package checkout of webmproject/libwebp remained active while starting debugging, so no VM service became available. The phone was confirmed unlocked with no pending trust prompts. The receipt has not been staged, analyzed through the mobile flow or saved. No expense/attachment success is claimed for this attempt. The sharing receiver dependency alone does not implement receiving shares from other apps.
