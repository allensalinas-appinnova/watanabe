# Receipt sharing and compact attachments

LumioMoney accepts one image or PDF from the native **Share** sheet on Android/iOS. Receiving a file creates a private local handoff, not an analysis or financial operation. The normal document review still requires an account, category, date, amount and performed-expense confirmation. Internal camera/gallery/PDF selection remains available.

## Receipt presentation

Editing a movement places its compact attachment row below Expense/Income and above Amount. The row opens the viewer and shows localized file format/size. Its options menu contains deletion with the existing confirmation. Empty results occupy no row; loading and read failures remain visible. Deletion does not alter the movement or its financial effects. Usage and storage keeps its administrative list.

## Local handoff

`SharedReceiptInbox` receives the initial native intent and subsequent events. It copies/normalizes data privately before native grants expire, resets consumed callbacks and deletes only consumed copies inside known cache/App Group roots. Images are normalized to JPEG with EXIF removed, including supported HEIC input; PDFs keep their bytes. Upload limits remain 5 MB per normalized image and 10 MB per PDF. Pre-conversion images are bounded at 20 MB. Server PDF validation still checks page count/password and all quotas.

The inbox is bound to UID/data generation when known. An unowned receipt can survive sign-in but requires explicit account confirmation. Guests are offered Save my account. Changing an established UID/generation or entering reset invalidates its pending handoff. Unowned files are never silently attached to the next account. Post-sign-in confirmation waits until the authentication/onboarding route finishes; route changes reschedule the handoff. An implicit dialog closure during navigation preserves the file rather than treating it as an explicit discard.

One local document draft and one incoming handoff can coexist. A conflict offers Keep current or Use new file, followed by confirmation before discarding the old draft. A failed server discard keeps both. A successful adoption reuses its stable import ID, and an old controller load cannot overwrite a newer adopted draft. Unrelated form routes remain in the navigation stack. Multiple/unsupported files are rejected rather than silently selecting one.

Receiving does not automatically analyze after reconnection. The existing explicit Analyze action checks connectivity and reports the offline message while preserving the draft. Cancelled/expired incoming copies are removed; the 24-hour expiry is enforced while running and on startup/resume. iOS additionally purges expired regular files in its dedicated App Group, skipping hidden container metadata. No production document content or native path is logged by this implementation.

## Native configuration

Android registers SEND and SEND_MULTIPLE for image/* and application/pdf. MainActivity uses singleTask so subsequent shares reach the existing Flutter engine. The Dart bridge enforces a single file even for SEND_MULTIPLE.

iOS has a ShareExtension using the existing receive-sharing-intent Swift Package product. Runner and the extension use `group.com.appinnova.lumiomoney.receipts`; the extension bundle is `com.appinnova.lumiomoney.app.ShareExtension`. The existing Google Sign-In URL scheme is preserved. The typed, idempotent setup tool is:

```sh
swift run --package-path tool/ios_share_setup ios_share_setup ios/Runner.xcodeproj --qa-tests
```

It uses XcodeProj and synchronized source folders rather than PBX text replacement or CocoaPods. The --qa-tests option adds a separate native sender and XCTest UI scheme; those targets are not embedded in Runner. If the receive-sharing-intent version changes, update its generated local-package reference through this tool before building the extension.

Device signing requires the existing Apple team, App Groups on both identifiers and a provisioning profile for the extension. On 2026-11-02, signing passed after the operator renewed the Xcode account; both signed binaries were checked for the exact receipt App Group. Build success does not establish a physical share-sheet pass.

## Qualification

Run `bash tool/run_document_e2e.sh` with Firebase Emulator in demo-clearbudget. Android builds a separate QA sender APK, uses Android's real chooser for image/PDF input, verifies review/approval/duplicates and compact attachment deletion, then checks a cold-start share without financial mutations. Its host bridge accepts only a named Android Emulator and the explicit demo project. Synthetic test identities end in @example.test; passwords are test-only fixtures, never production credentials.

For iOS set E2E_PLATFORM=ios and E2E_DEVICE to a Simulator UUID. The runner first exercises the Firebase-backed Flutter flow, then builds/installs the normal Emulator client and runs ReceiptShareQA. Its native sender opens UIActivityViewController and XCTest selects the actual extension. Results/screenshots are written under artifacts/document-imports and are distinct from physical-device qualification.

Current results and blockers are recorded in [receipt qualification](document-import-qualification.md). No Functions, Firestore/Storage rules, quota policy or financial calculation changes are required by sharing or the compact row.
