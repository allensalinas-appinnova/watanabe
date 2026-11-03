// Browser smoke probe: compile with `dart compile js` and serve alongside the
// prepared web/sqlite3.wasm and web/drift_worker.dart.js assets.
import 'dart:js_interop';

import 'package:personal_finance/core/offline/pending_operation_queue.dart';

@JS('document.body.textContent')
external set _result(JSString value);

Future<void> main() async {
  const key = 'web-portability-probe';
  try {
    final phase = Uri.base.queryParameters['phase'] ?? 'write';
    final database = await openPendingOperationDatabase();
    try {
      if (phase == 'write') {
        await database.enqueue(
          idempotencyKey: key,
          operationType: 'operation',
          payload: const {
            'type': 'expense',
            'ownerUserId': 'web-probe',
            'amountMinor': 125,
            'currency': 'COP',
          },
        );
      } else {
        final row = await database.findByIdempotencyKey(key, userId: 'web-probe');
        if (row == null || row.status != 'pending' || row.operationType != 'operation') {
          throw StateError('Pending operation did not survive browser restart.');
        }
        await database.claim('web-probe', 'attempt', DateTime.now().toUtc());
        await database.finish(row.id, 'web-probe', 'attempt', 'confirmed');
        final confirmed = await database.findByIdempotencyKey(key, userId: 'web-probe');
        if (confirmed?.status != 'confirmed') throw StateError('Confirmation failed.');
        await database.clearConfirmed(key, 'web-probe');
      }
    } finally {
      await database.close();
    }
    _result = 'PASS:$phase'.toJS;
  } catch (error) {
    _result = 'FAIL:$error'.toJS;
  }
}
