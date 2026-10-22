import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_command_failure.dart';
import 'package:personal_finance/features/finance/presentation/widgets/budget_command_message.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  for (final language in ['es', 'en', 'pt']) {
    test(
      'budget failures are localized without promising background synchronization ($language)',
      () {
        final l10n = lookupAppLocalizations(Locale(language));
        for (final issue in BudgetCommandIssue.values) {
          expect(budgetCommandMessage(l10n, issue), isNotEmpty);
          expect(budgetCommandMessage(l10n, issue), isNot(contains('budget-command')));
        }
        final message = budgetCommandMessage(l10n, BudgetCommandIssue.network);
        expect(message, l10n.budgetConnectionRequired);
        expect(message.toLowerCase(), isNot(contains('pendiente')));
      },
    );
  }
}
