enum SyncState { pending, syncing, confirmed, rejected }

enum SyncIssueCode { networkUnavailable, permissionDenied, invalidOperation, unexpected }

class SyncFailureInfo {
  const SyncFailureInfo({required this.issue, this.technicalCode});

  final SyncIssueCode issue;
  final String? technicalCode;

  @override
  bool operator ==(Object other) =>
      other is SyncFailureInfo && other.issue == issue && other.technicalCode == technicalCode;

  @override
  int get hashCode => Object.hash(issue, technicalCode);

  String encode() {
    final code = technicalCode;
    if (code == null || !RegExp(r'^[a-z0-9-]{1,48}$').hasMatch(code)) {
      return issue.name;
    }
    return '${issue.name}:$code';
  }

  static SyncFailureInfo? parse(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    final matchingIssues = SyncIssueCode.values.where((item) => item.name == parts.first);
    if (matchingIssues.isEmpty) return null;
    final issue = matchingIssues.first;
    final technicalCode = parts.length > 1 && RegExp(r'^[a-z0-9-]{1,48}$').hasMatch(parts[1])
        ? parts[1]
        : null;
    return SyncFailureInfo(issue: issue, technicalCode: technicalCode);
  }
}

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
