import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/offline/sync_state.dart';
import 'package:personal_finance/features/finance/presentation/widgets/sync_issue_localization.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  test('shows a localized, actionable explanation for a permission rejection', () async {
    final spanish = await AppLocalizations.delegate.load(const Locale('es'));
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    final portuguese = await AppLocalizations.delegate.load(const Locale('pt'));
    const issue = SyncFailureInfo(
      issue: SyncIssueCode.permissionDenied,
      technicalCode: 'permission-denied',
    );

    expect(syncIssueMessage(spanish, issue), contains('Firebase rechazó'));
    expect(syncIssueMessage(english, issue), contains('Firebase rejected'));
    expect(syncIssueMessage(portuguese, issue), contains('O Firebase rejeitou'));
    expect(
      spanish.syncDiagnosticCode(issue.technicalCode!),
      'Código de diagnóstico: permission-denied',
    );
  });

  test('selects the first persisted sync issue and ignores unknown legacy codes', () {
    expect(
      firstSyncFailure(const ['unknown-format', 'networkUnavailable:unavailable']),
      const SyncFailureInfo(
        issue: SyncIssueCode.networkUnavailable,
        technicalCode: 'unavailable',
      ),
    );
  });
}
