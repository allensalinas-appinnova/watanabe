#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
npm --prefix functions run build
npx -y firebase-tools@latest emulators:exec --project demo-clearbudget --only auth,firestore,storage \
  'node --test functions/test/account_deletion_test.mjs && node functions/test/firestore_rules_test.mjs && node --test functions/test/document_rules_test.mjs'

npx -y firebase-tools@latest emulators:exec --project demo-clearbudget --only auth,firestore,storage,functions \
  'node --test functions/test/account_deletion_trigger_test.mjs'
