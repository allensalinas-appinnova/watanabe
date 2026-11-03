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

Authenticated production mobile access passed on the physical iPhone using the registered debug App Check provider, and analysis was activated after this check. Administrative production authentication was verified separately through the portal. Physical-device import evidence is recorded in the latest walkthrough section below; Emulator results remain separate from that live QA evidence. Release attestation and actual camera/file permissions remain separate platform checks. Web protected imports require a configured App Check site key; no browser receipt end-to-end acceptance is implied by mobile builds. Store privacy disclosures and the public policy must be updated before consumer distribution.

Dependency audit after compatible fixes reports no high/critical runtime advisory, with seven moderate runtime advisories still present; test/development tooling has additional advisories. This is not a clean security audit and no forced major Firebase upgrade was applied during qualification.

## Physical iPhone access check

The operator authorized preparing the debug QA client on the connected iPhone. `tool/run_ios_qa.sh` requires project `lumiomoney` and disables Emulator routing. Its normal release entry point is unchanged. `test_driver/main_qa.dart` preserves the real keyboard and exposes session and protected resource-usage diagnostics, plus an explicitly invoked local document-staging bridge restricted to the primary QA account and production project. Staging does not approve an expense: analysis, review and save still use the real application and protected commands.

After Flutter exposes its VM service, run `dart run tool/qa_resource_probe.dart <private-flutter-log> session` before `resource-access`. The probe reads the VM URL privately and returns no Auth or App Check tokens. Keep device logs private because the native debug App Check provider can print its registration token. A valid debug provider proves the QA transport; it does not qualify release App Attest or Android Play Integrity.

The physical-device build completed and the updated QA app was installed and launched. The initial session was not the primary QA identity, so the protected usage probe was not run for that user. The operator then signed in directly on the phone. The session probe confirmed `allensalinasjaramillo@gmail.com`, project `lumiomoney`, the expected iOS app and a non-anonymous session. The protected probe returned `authenticated=true`, `appCheck=true`, `usageRead=true` from the deployed `getResourceUsage` callable. The iPhone debug App Check registration was added for this app only, without disabling enforcement. No financial command, reset or document analysis was executed during this physical-device check.

## Earlier synthetic physical receipt attempt: environment blocked

The operator subsequently authorized retaining one synthetic COP 25,000 expense and its attachment in QA Banco. The read-only baseline was COP 2,710,000, nine operations, zero attachments and zero imports; the expected bank result is COP 2,685,000. This authorization is specific to this synthetic receipt and does not authorize unrelated financial writes.

A synthetic PNG marked QA was generated. A separate Vertex qualification call recognized COP 25,000, COP currency, date 2026-11-01 and personal-care category in 10,744 ms, reporting 2,171 total tokens. This is provider evidence, not evidence of a saved mobile import or a user quota charge.

The debug-only entry point can stage this synthetic image without replacing an existing draft; the host walkthrough refuses accounts other than the primary QA identity. The iPhone build passed after replacing the incompatible CocoaPods-only sharing dependency with the Swift Package Manager compatible receiver and removing the automatically generated residual Podfile. Xcode's own package checkout of webmproject/libwebp remained active while starting debugging, so no VM service became available. The phone was confirmed unlocked with no pending trust prompts. The receipt has not been staged, analyzed through the mobile flow or saved. No expense/attachment success is claimed for this attempt. The sharing receiver dependency alone does not implement receiving shares from other apps.


## Physical iPhone receipt walkthrough: completed financial registration

On 2026-11-01, the operator supplied two JPEG receipts and a PDF and authorized their use as retained QA expenses. The session and project were verified before interacting with the real app. All three imports were analyzed through the protected production callable, reviewed in the app and saved via the normal financial command:

| QA source | Amount (COP) | Original date | Persisted result |
| --- | ---: | --- | --- |
| Image 1 | 850,000 | 2026-10-20 | Confirmed expense and retained JPEG |
| Image 2 | 90,000 | 2026-09-05 | Confirmed expense and retained JPEG |
| PDF purchase payment | 39,000 | 2026-11-01 | Confirmed expense and retained PDF |

Read-only Firestore verification found one deterministic operation per approved import, all `expense` / `confirmed`, and three attachment documents. QA Banco changed from COP 2,710,000 to COP 1,731,000, exactly the COP 979,000 combined expense. Storage metering reported three attachments / 1,598,675 bytes, zero temporary files and zero reserved bytes. The first retained image was opened and rendered on the iPhone. Opening the remaining retained files is still pending and will continue on Android at the operator's request; their persisted references do not alone prove viewer rendering.

The first image used the native image selection performed during the walkthrough. Subsequent files were staged from the supplied originals through the restricted debug bridge; the preview, analysis, review and save were real mobile flows. This does not qualify automated native camera or Files picker interaction.

Two blockers were corrected: Storage cross-service rules required the standard Firestore service-agent role on the Storage service identity (explicitly authorized, preserving the private bucket), and the analyzer incorrectly rejected purchase payments merely described as transfers. The revised prompt distinguishes merchant purchases from clearly identified own-account transfers and requires manual review for ambiguous category/account. The operator confirmed the PDF was a purchase. Its first unsupported proposal was discarded through the app; the new analysis returned COP 39,000 and the original date without inventing category or account. Only `mutateDocumentImport` was redeployed for this prompt correction. The 18 document tests, two feature-security tests and 27 existing rules tests passed again in Emulator (47 total); a separate real-provider PDF evaluation also returned the expected amount/date. These results remain distinct from release attestation and platform-native picker checks.

The earlier authorized synthetic COP 25,000 fixture was not saved in addition to these supplied documents. No financial repair or console write was used.


## Android Emulator regression expansion — 2026-11-02

The physical Android was unavailable; no production QA data was changed in this continuation. The expanded `document_import_flow_test.dart` passed on Pixel_9 against Auth, Firestore, Storage and Functions Emulator in `demo-clearbudget`. The only substituted boundaries were local file selection/connectivity and the external AI provider; a synthetic one-page purchase PDF is versioned under `integration_test/fixtures/` and contains no customer data.

The route covered an image selected offline (no server proposal until explicit retry), an approved COP 25,000 expense, then a COP 39,000 PDF with no suggested category/account. The real form required performed confirmation and manual account/category selection. Two confirmed expenses and two retained attachments left the bank at COP 36,000 from COP 100,000. The PDF bytes matched the source exactly and its attachment route instantiated the PDF viewer. Importing the identical PDF again offered the existing operation: two operations, two attachments, two analysis units and the same COP 36,000 balance. Retained byte totals matched attachment sizes and temporary bytes were zero.

`artifacts/document-imports/result.json` records both checkpoints (`checks` for the image and `pdfAndDuplicateChecks` for the final state); the screenshot contains only synthetic receipt data. The final host process exited successfully and the structured PDF/duplicate assertions were checked. Two preceding app runs failed in test orchestration (a hardcoded Spanish label on an English device and a tap during popup dismissal); those were corrected and are not counted as passing runs.

An earlier build was blocked before app launch because `receive_sharing_intent` 1.9.0 requires compile SDK 37. Android now uses compile SDK 37 and AGP 9.1.1; target/min SDK remain unchanged. This aligns with the [package changelog](https://pub.dev/packages/receive_sharing_intent/changelog) and [Android API/AGP support table](https://developer.android.com/build/releases/about-agp). SDK 37 is also installed explicitly in the CI Android job.

Validation in this continuation: 508 Flutter tests passed, `flutter analyze` reported no issues, Functions built, and 48 document/resource/security/rules tests passed (19 document/resource tests, two feature-rule tests, 27 existing Firestore rule tests). The new server regression verifies a merchant-payment PDF, mandatory performed confirmation, original attachment preservation and idempotent approval. The normal `lib/main.dart` Android debug APK also built successfully after the E2E. Formatting, workflow YAML parsing and `git diff --check` passed. CI now includes the server document suite and Android document E2E with structured evidence upload; the remote workflow itself has not been run here.

Remaining release checks are unchanged: protected access and native file/camera selection on physical Android, release Play Integrity/App Attest, and outstanding retained-file viewer checks on the physical device. The iPhone financial results above are not repeated or overwritten. No Firebase deployment was required by this test/Android-build continuation.


## Physical Android App Check diagnosis — 2026-11-02

The connected debug Android showed `403 App attestation failed`, followed by SDK throttling (`Too many attempts`), before protected imports/usage could load. Its Android App Check debug installation had not been registered. After the operator renewed Firebase CLI authentication, this installation alone was registered on the existing Android Firebase app. Enforcement, production attestation providers and IAM remained unchanged; the debug secret was handled privately and is not part of repository evidence. The debug exchange returned HTTP 200 with a one-hour App Check token.

Restarting only the application process cleared the in-memory failed-attempt backoff, preserving session and local data. Native navigation on the phone then loaded the protected usage screen (zero analyses today, four for the month; 1.6 MB retained, zero temporary bytes) and rendered both the saved PDF and the second image from the protected attachment reader. No analysis or financial command was executed in this check. The earlier pending physical viewer checks are therefore complete for those files. The screenshot/error from iPhone was not reproduced live in this Android check; debug installations must be registered separately per platform/installation, and release attestation remains a separate check.

## Compact attachment and native receipt sharing — 2026-11-02

The editing form now places a compact localized receipt row below Expense/Income and above Amount. The viewer and confirmed attachment deletion remain available; the administrative storage list keeps its existing presentation. Native receipt intake stages a private local handoff and requires explicit review: receiving alone does not analyze or create a movement. UID/generation isolation, 24-hour expiry, duplicate callbacks and draft replacement are covered by focused tests. A controller-load race discovered during repeated native runs was fixed with an epoch guard and a regression test.

The final full Flutter suite passed **529 tests**; `flutter analyze` reported **no issues** and `git diff --check` passed. Android debug APKs and iOS Simulator builds compiled. After the operator signed into Xcode, an iOS device build also signed successfully; both Runner and ShareExtension contained the exact `group.com.appinnova.lumiomoney.receipts` entitlement. Signing/build results are separate from native share-sheet acceptance.

The Android Emulator's open-app native image/PDF share route passed repeatedly against `demo-clearbudget`: the real Android chooser delivered each source to the review flow, confirmed operations/attachments/balances matched the synthetic expectations, duplicate input did not debit twice, and deleting a compact-row attachment preserved its movement/balance. The latest run's Flutter integration portion passed all three test entries. The additional normal-entry cold-start check subsequently passed: clearing only the Emulator client's local data, sharing a PDF, signing in through the real form and confirming the account reached the receipt preview. A before/after comparison found identical financial records. The successful run used software rendering after the hardware-rendered AVD stopped answering ADB. Earlier failed harness attempts are retained as failures, not counted as successes. The cold run exposed and fixed a real navigation race: authentication could remove the receipt confirmation route and its null result was incorrectly treated as a discard. The coordinator now waits for auth navigation, observes route changes and retains incoming data on implicit modal closure.

The updated physical Android client was installed and its read-only probe confirmed the authorized QA identity and real `lumiomoney` project. The phone initially rejected the separate sender installation; after the operator accepted a renewed installation request, the native PDF chooser selected LumioMoney and its draft-conflict dialog appeared. Choosing Keep current preserved the pre-existing COP 39,000 receipt, visibly reopened from Register; usage stayed at zero analyses today and four for the month. The sender must keep its grant-owning activity alive while Xiaomi transfers the URI, and carries explicit ClipData/read permission. No real import was analyzed, discarded or posted. This qualifies physical PDF reception/conflict preservation, not replacement or approval of a new real document. The attempted physical image chooser did not complete and is not counted as passed.

The iOS Simulator Firebase-backed import regression also passed all three test entries, including compact-row placement/deletion and exact PDF preservation. The native XCTest selected LumioMoney from the actual share sheet, opened the app via its extension and displayed the Shared file sign-in invitation. A subsequent native XCTest passed both PDF and image previews, using the form's native Next/Done keyboard actions to avoid this runtime's inconsistent secure-field AX type. Both screenshots were inspected, and the provider was not called (zero analysis units). Preceding sender/selector/typing harness failures remain recorded as failures. The repeat with the final auth-navigation fix passed as well: `native-ios-result.json` records one native test passed and zero failed, covering both source types. Android's repeated `cold-share.json` confirms the shared-file invitation, submitted sign-in form, ready preview and unchanged financial records. None of these Simulator results certifies physical-iPhone sharing. The latest signed QA client was installed successfully on the paired iPhone; both binaries again passed the exact App Group entitlement check. The physical iPhone result below is a separate manual-assisted check, not an automated XCTest pass.

Implementation/setup and repeatable Emulator commands: [shared receipts](shared-receipts.md). No Firebase deployment was made for the compact-row/sharing feature.


### Final physical iPhone check

After installation of the final signed QA client, the read-only session probe initially found a different account. No receipt was shared into that session. The operator switched to the authorized primary QA identity; the probe then confirmed `lumiomoney`, the expected registered QA account, valid App Check and a successful protected usage read.

The native sender prepared a synthetic PDF and the real iPhone share sheet contained LumioMoney. XCTest could not reliably activate the partially clipped share-sheet cell; those physical automated attempts remain failures. The operator selected LumioMoney manually and chose **Keep current** in the actual draft-conflict dialog. Returning to Home is the intended behavior for that choice. The host then reopened Register → From photo or file through the real Flutter UI and observed the pre-existing receipt image intact. The visible usage remained **0 analyses today / 4 this month**. No Analyze, Save, replacement, financial command or manual Firebase write was performed. The new incoming file was discarded while the old draft was preserved. Physical evidence is private under `/tmp`, not a versioned customer screenshot.

The physical result qualifies native PDF reception and safe draft preservation with an operator touch. It does not claim an automated physical iPhone pass or a newly imported/approved real expense. New-file PDF/image previews and the full approval path remain independently covered by the Simulator and Android Emulator results above. Both final clients retain access to the original draft for review.

## Field review iteration — 2026-11-02

Implemented typed warning propagation and localized field-origin hints in the canonical imported-expense form. Missing fields show Review; extracted values show Suggested; manual choices remain identified after offline save/reopen. The test fixture starts with authentication pending, covering the initial-load race. Closing the form no longer reads providers after unmount. Review persistence preserves existing draft metadata. Currency disagreement is explained without converting amounts or changing financial command rules.

The server/client date guards now match the existing 2000–2100 picker range and reject normalized invalid dates. Boundary/leap-day assertions extend the existing extraction test. This changes future extraction suggestions, not historical transactions or saved financial totals.

Executed checks:

- `flutter pub get`, `dart run build_runner build`, `flutter gen-l10n`, scoped Dart formatting and `git diff --check`.
- `flutter analyze`: no issues. `flutter test`: **538 passed**, including nine new mapper/domain/widget tests for warnings, languages, dark/light themes, 320dp with enlarged text, offline persistence/reopening and mismatched currency/invalid draft dates.
- `bash tool/run_document_tests.sh`: **41 document/resource**, **2 import-rule**, and **27 general Firestore-rule** tests passed in `demo-clearbudget`.
- Final `bash tool/run_document_e2e.sh` on **emulator-5554** completed with exit 0. All three Flutter integration entries passed. New assertions verified suggested amount/account hints and the PDF's missing-account/category hints and explicit manual account choice. Structured results retained two operations, two original attachments before the deletion check, bank balance **COP 36,000** from **COP 100,000** after the **25,000 + 39,000** expenses, and two analysis units. Duplicate detection did not debit again; deleting one attachment retained both operations and the same balance.
- The normal-entry-point cold-share check passed: native chooser, login form submission, shared-file invitation and preview, with financial records unchanged. Results are in ignored `artifacts/document-imports/result-android.json` and `cold-share.json`; stale failure files from older runs are not current results.
- Android debug APK compiled with explicit `lumiomoney` configuration and emulators disabled. Final iOS debug build with the existing iOS configuration passed with `--no-codesign`. The unsigned iOS app is compile evidence, not installation or physical-device acceptance. No mobile client was installed on a physical device during this iteration.

The widget harness initially exposed a review loading timeout and unsafe provider access during disposal; both were corrected before the final green suite. Its oversized non-scrolling demonstration column and an off-screen checkbox tap were also corrected; the offline-save test now asserts the checkbox and enabled save action before verifying the preserved draft. The final suite had no missed-hit warning. Existing Kotlin migration notices and Firebase Installations/App Check placeholder warnings in the demo environment are distinct from failures and do not certify production mobile App Check.

Published to **lumiomoney**: `functions:mutateDocumentImport`, Firestore rules and Storage rules. Rule source was unchanged; Firebase released its existing validated versions. The updated document-import service was ready and rejected an unauthenticated HTTP call with `401 UNAUTHENTICATED`. No production receipt analysis, financial operation or reset was executed. The new hint UX requires running the updated mobile client; Firebase publication alone does not update installed Flutter binaries. A refreshed, more varied real-model evaluation remained pending at the close of that iteration; the subsequent qualification below supersedes that pending status when completed.


## Diverse provider qualification and physical read checks — 2026-11-02

The follow-up replaces the earlier homogeneous PDF benchmark with a repeatable corpus in `functions/tool/receipt_evaluation_cases.mjs` and an explicit operator runner in `functions/tool/qualify_receipts.mjs`. This is a provider qualification, not an integration suite pointed at production. It deliberately calls the deployed analyzer model using synthetic documents and does not create an import or financial record. Model/location were read from the active `mutateDocumentImport` configuration before interpreting the results.

The runner has per-attempt checkpoints, a single-process lock, sanitized error codes and resume validation. A finished/failed attempt is not retried when resuming; interrupted attempts retain unknown consumption instead of silently spending again. The deterministic runner tests use an injected provider and never call Google. The report separates required-field matches, category/account suggestion matches, API availability, latency and partial cost estimates. See [the operating procedure](document-imports.md#repeatable-synthetic-provider-qualification).

### Observed provider results

The live `multiformat-v1` run completed all **30 attempts** using **gemini-3.8-flash / global**, matching the active Function. The final private report is `artifacts/document-imports/provider-qualification-20261102.json`. Resuming that completed report with the final runner made **zero additional provider calls** and refreshed its aggregate summary; the 30 original attempts, including failures, were preserved.

| Measure | Observed |
| --- | --- |
| API responses / attempts | 27 / 30 |
| Exact required-field responses / responses | 26 / 27 |
| Supported/unsupported classification | 27 / 27 |
| Amount and currency checks, each | 20 / 21 applicable responses |
| Date checks, including deliberate omission | 21 / 21 applicable responses |
| Category suggestion | 17 / 18 assessed |
| Account resolution | 15 / 16 assessed |
| Median / p95 / maximum latency | 7.664 / 87.877 / 87.942 seconds |

Spanish completed 10/10 with exact required fields; English returned 8/10 with exact required fields; Portuguese returned 9/10, of which 8 were exact. All six own-account transfer/statement cases were correctly rejected. The untrusted-document instruction cases retained the expected classification and amount. The Portuguese missing-date PNG did not produce a valid amount/currency and also required manual category/account selection. Date omission itself was correct. This is an incomplete extraction requiring review, not evidence of a posted wrong amount: no movement was created.

Technical failures were **HTTP 429** for one English USD PDF and **HTTP 504** for the English missing-date PDF and Portuguese simple JPEG. No failed case was silently retried or excluded from the denominator. The normalized-field matches above do not measure raw OCR text accuracy, representative real-customer accuracy or human correction time. A corpus with ten documents per format is a regression/qualification sample, not a production reliability estimate.

The known token-cost subtotal was **USD 0.06347025**, using the existing reviewed tariff snapshot. It is **partial**, not a total bill: failures did not return usage, cached-token measurement was absent, and transport/shared compute/free-tier/credit effects are outside this estimate. All 30 attempt costs remain marked incomplete. These are shared qualification costs, never commercial analysis units assigned to the QA user. Live-call token measurements are retained in the private report; source bytes and raw response text are not.

This run supports continuing a review-assisted beta. It does not justify automatic financial posting. Provider availability and tail latency remain observed limitations; any model/prompt/timeout change should receive its own evaluation rather than replacing this evidence with successful retries.

### Physical-device scope

The updated debug-only QA entry point was rebuilt, installed and launched on the connected physical Android and iPhone. Both sessions were verified as the authorized primary QA identity in `lumiomoney`; both obtained App Check and successfully read protected usage. Android restored the existing image draft and opened its enlarged preview. A previously retained PDF was opened and visually inspected on both phones; its content actually rendered, rather than merely loading an attachment route. These checks use existing QA documents, not the newly generated benchmark corpus.

No Analyze, Save, replacement, discard, financial mutation or reset was invoked in the physical walkthrough. Read-only hashes and document counts compared before/after were identical for operations, accounts, budgets and debt payments. Android displayed zero analyses today and four this month. Source documents and device screenshots remain private in ignored artifacts; the versioned report contains no receipt contents or financial identifiers. Both apps were returned from their viewers to their previous navigation context.

These are debug-client/protected-read and viewer checks. They do not qualify release Play Integrity/App Attest, a new live import approval, native camera/chooser/sharing, TalkBack/VoiceOver or receipt-field correctness on either physical device. Those remain distinct from the mock-assisted field-review tests and existing Emulator financial E2E. The initial parallel host probes collided in Dart native-asset preparation, and the old iPhone VM connection had expired. Sequential probes and a new signed launch recovered those harness conditions; the failed probes are not counted as device successes.

### Verification and publication scope

- Functions TypeScript build and JavaScript syntax checks passed.
- Seven deterministic evaluation tests passed; the document/resource/rule suite passed separately in `demo-clearbudget` (41 document/resource, 2 import rules and 27 general Firestore rules).
- `flutter analyze` reported no issues; all 538 Flutter tests passed again.
- Android QA debug build/install/launch and signed iPhone debug build/install/launch passed. Physical screenshots were inspected privately.
- `git diff --check`, ignored-artifact checks and a scoped credential scan passed.

No runtime Function, Firestore/Storage rule, index, IAM policy or financial contract changed in this iteration. No Firebase deployment was needed. The newly added runner/tests are operator tooling and CI coverage; they do not ship inside the mobile client or the administrative portal.


## Wait-state and provider-failure feedback — 2026-11-02

Implemented a 15-second localized long-wait explanation and safe, persistent failure reasons. The model, prompt, SDK timeout, callable timeout and analysis lease remain unchanged: this iteration does not claim a speed or extraction-quality improvement. Provider failures are separated from offline errors and an unconfirmed client response. See [analysis waits and retryable failures](document-imports.md#analysis-waits-and-retryable-failures).

Executed automated checks:

- `flutter gen-l10n`, scoped formatting, Functions TypeScript build and `git diff --check`.
- Focused mapper/progress/controller suite: 15 passed. It covers initial/15-second status, disposal, 320dp with enlarged text, light/dark and es/en/pt; stored safe reasons, explicit retry preservation and removal of a previous error when a completed server snapshot arrives are also checked.
- `flutter analyze`: no issues after correcting one import-order lint. Full `flutter test`: **547 passed**.
- `bash tool/run_document_tests.sh`: **79 passed** across eight deterministic evaluation/classifier tests, 42 document/resource tests, two import-rule tests and 27 general Firestore-rule tests. The per-user server regression verifies busy/timeout/generic failure classification, no private provider text, one released reservation, one technical attempt, same-source retry, cleared old issue and no operation/attachment/balance changes.
- `E2E_DEVICE=emulator-5554 bash tool/run_document_e2e.sh`: exit 0, all three integration entries passed. The actual screen displayed a synthetic HTTP 429 message, the failed analysis returned commercial usage to zero and the retry used the same import ID. Subsequent image/PDF approvals retained two operations/two attachments before deletion and bank COP 36,000 from COP 100,000. Duplicate import did not debit again; attachment deletion preserved operations and balance. `result-android.json` records `providerBusyRecovered`, `failedAttemptRefunded` and `retryKeptImportId`.
- The normal-entry cold native-share check also passed, with financial records unchanged. Failure injection uses the emulator-only provider fixture and an explicitly demo-project REST setup; no production failure switch was introduced. Existing Kotlin migration and demo Firebase Installations/App Check warnings are separate from the passing integration results.

Published only `functions:mutateDocumentImport` to **lumiomoney**. The service was ACTIVE at revision `mutatedocumentimport-00007-boq`; an unauthenticated POST returned **401 UNAUTHENTICATED**. No Firestore/Storage rule, index, IAM policy or other Function was changed or redeployed. Old clients remain compatible and ignore the optional public issue field; localized wait/recovery UX requires the updated mobile client.


### Physical smoke check with the final clients

The final debug QA client was installed and launched on both connected physical phones. Each session was confirmed as the authorized primary QA account in `lumiomoney`, and each successfully obtained App Check and called protected `getResourceUsage`. The usage screen remained accessible. Read-only hashes/counts of operations, accounts, budgets and debt payments matched the prior QA baseline. No new live analysis, expense approval, discard, replacement or reset was executed.

The deliberate 429/timeout failures and the 15-second transition were validated in Emulator/unit/widget tests, not forced against the live provider on the phones. Debug App Check acceptance is not release Play Integrity/App Attest certification. A terminal attach attempt could not reconnect to the existing VM session; fresh launches recovered the harness and the final access checks passed. Device build/launch and access are reported separately from the automated error-recovery E2E.
