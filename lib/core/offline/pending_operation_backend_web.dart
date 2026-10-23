import 'dart:js_interop';

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

@JS('document.baseURI')
external JSString get _documentBaseUri;

Future<QueryExecutor> openPendingOperationExecutor() async {
  // Honor Flutter's base href, including apps hosted below a URL prefix.
  final base = Uri.parse(_documentBaseUri.toDart);
  final result = await WasmDatabase.open(
    databaseName: 'clearbudget',
    sqlite3Uri: base.resolve('sqlite3.wasm'),
    driftWorkerUri: base.resolve('drift_worker.dart.js'),
  );
  if (result.chosenImplementation == WasmStorageImplementation.inMemory ||
      result.chosenImplementation == WasmStorageImplementation.unsafeIndexedDb) {
    await result.resolvedExecutor.close();
    throw UnsupportedError('This browser cannot safely persist the pending-operation queue.');
  }
  return result.resolvedExecutor;
}
