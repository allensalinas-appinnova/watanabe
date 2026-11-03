#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! java -version >/dev/null 2>&1 && [[ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
npm --prefix functions run build
node --test functions/test/receipt_evaluation_test.mjs functions/test/document_analysis_failure_test.mjs
firebase emulators:exec --project demo-clearbudget --only auth,firestore,storage \
  "node --test --test-concurrency=1 functions/test/document_imports_test.mjs functions/test/resource_costs_test.mjs functions/test/resource_costs_store_test.mjs functions/test/resource_observation_test.mjs functions/test/storage_capacity_test.mjs functions/test/maintenance_jobs_test.mjs && node --test functions/test/document_rules_test.mjs && node functions/test/firestore_rules_test.mjs"
