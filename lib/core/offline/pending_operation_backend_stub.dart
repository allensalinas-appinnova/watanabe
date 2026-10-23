import 'package:drift/drift.dart';

/// Platforms without either native IO or browser APIs are unsupported.
Future<QueryExecutor> openPendingOperationExecutor() async {
  throw UnsupportedError('The native pending-operation queue is unavailable on this platform.');
}
