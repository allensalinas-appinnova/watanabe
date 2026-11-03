#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "${GCLOUD_PROJECT:-}" == demo-clearbudget ]] || { echo 'Emulator only' >&2; exit 1; }
device="${E2E_DEVICE:?Set Simulator UUID}"
flutter drive --driver=test_driver/document_import_driver.dart --target=integration_test/document_import_flow_test.dart -d "$device" \
  --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
cp artifacts/document-imports/result.json artifacts/document-imports/result-ios.json
flutter build ios --simulator --debug --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
xcrun simctl install "$device" build/ios/iphonesimulator/Runner.app
node functions/tool/seed_native_share_qa.mjs
xcodebuild -workspace ios/Runner.xcworkspace -scheme ReceiptShareQA -destination "id=$device" \
  -clonedSourcePackagesDirPath build/ios/SourcePackages -derivedDataPath build/ios/share-uitests -resultBundlePath "artifacts/document-imports/share-ios-$(date +%s).xcresult" \
  CODE_SIGNING_ALLOWED=NO test
