# Local queue assets

`sqlite3.wasm` and `drift_worker.dart.js` are served by this application, with
no runtime CDN. Regenerate after upgrading Drift or sqlite3:

```sh
dart run tool/prepare_pending_operation_web.dart
```

Run from the project root with Dart and `shasum` available. The script compiles
the installed Drift worker and verifies its bundled WASM against the installed
sqlite3 package's SHA-256 before copying it. It fails on incompatible assets.

Serve WASM with `Content-Type: application/wasm`. SharedWorker plus IndexedDB
provides persistence without cross-origin isolation; Drift can also use OPFS
when supported. The queue rejects nonpersistent and unsafe single-tab fallback
implementations. No DI skip is needed for web.

Browser persistence probe (use an isolated browser profile): compile
`test/core/offline/pending_operation_web_probe.dart` to JavaScript and load it
from a page beside these assets. First load with `?phase=write`, close the
browser, then reopen the same origin/profile with `?phase=read`. Both phases
must display `PASS`. The read phase verifies the pending row, confirms it,
and removes only that test row.
