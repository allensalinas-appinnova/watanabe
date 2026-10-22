import '../../../../core/offline/sync_state.dart';
import '../../../../l10n/generated/app_localizations.dart';

String syncIssueMessage(AppLocalizations l10n, SyncFailureInfo info) => switch (info.issue) {
  SyncIssueCode.networkUnavailable => l10n.syncIssueNetwork,
  SyncIssueCode.permissionDenied => l10n.syncIssuePermissionDenied,
  SyncIssueCode.invalidOperation => l10n.syncIssueInvalidOperation,
  SyncIssueCode.unexpected => l10n.syncIssueUnexpected,
};

SyncFailureInfo? firstSyncFailure(Iterable<String?> storedErrors) {
  for (final storedError in storedErrors) {
    final info = SyncFailureInfo.parse(storedError);
    if (info != null) return info;
  }
  return null;
}
