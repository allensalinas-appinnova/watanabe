enum SyncState { pending, syncing, confirmed, rejected }

enum SyncIssueCode { networkUnavailable, permissionDenied, invalidOperation, unexpected }

class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.pending,
    required this.syncing,
    required this.confirmed,
    required this.rejected,
  });

  final int pending;
  final int syncing;
  final int confirmed;
  final int rejected;

  bool get hasActiveWork => pending > 0 || syncing > 0;
}
