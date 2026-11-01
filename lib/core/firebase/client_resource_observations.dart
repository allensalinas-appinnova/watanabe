import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/request_id.dart';

/// Advisory server-result counts, not invoice reads or commercial quota authority.
class ClientResourceObservations {
  ClientResourceObservations(this.functions, this.auth);
  final FirebaseFunctions functions;
  final FirebaseAuth auth;
  final Map<String, int> _counts = {};
  final Map<String, ({String id, int count})> _pending = {};
  Timer? _timer;
  bool _flushing = false;
  void record(String uid, int documentResults) {
    if (auth.currentUser?.uid != uid || documentResults < 0) return;
    _counts.update(uid, (v) => v + documentResults, ifAbsent: () => documentResults);
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => flush());
  }

  Future<void> flush() async {
    if (_flushing) return;
    final uid = auth.currentUser?.uid;
    if (uid == null || ((_counts[uid] ?? 0) == 0 && !_pending.containsKey(uid))) return;
    final batch = _pending.putIfAbsent(
      uid,
      () => (id: newRequestId(), count: (_counts.remove(uid) ?? 0).clamp(0, 100000)),
    );
    final count = batch.count;
    _flushing = true;
    try {
      await functions.httpsCallable('submitUsageObservation').call<Object?>({
        'batchId': batch.id,
        'documentResults': count,
      });
      _pending.remove(uid);
    } catch (_) {
      /* Retain the same batch identity after a lost response. */
    } finally {
      _flushing = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _counts.clear();
  }
}
