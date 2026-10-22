import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/budget_command_failure.dart';

String budgetCommandMessage(AppLocalizations l10n, BudgetCommandIssue issue) => switch (issue) {
  BudgetCommandIssue.network => l10n.budgetConnectionRequired,
  BudgetCommandIssue.session => l10n.sessionExpired,
  BudgetCommandIssue.alreadyExists => l10n.budgetAlreadyExists,
  BudgetCommandIssue.lastItem => l10n.budgetLastItemMessage,
  BudgetCommandIssue.archived => l10n.budgetCommandArchived,
  BudgetCommandIssue.notFound => l10n.budgetCommandNotFound,
  BudgetCommandIssue.categoryUnavailable => l10n.budgetNoCategories,
  BudgetCommandIssue.invalidDay => l10n.budgetDayInvalidForMonth,
  BudgetCommandIssue.amountTooLarge => l10n.amountTooLarge,
  BudgetCommandIssue.invalidInput => l10n.budgetValidateItems,
  BudgetCommandIssue.requestConflict => l10n.budgetCommandConflict,
  BudgetCommandIssue.unexpected => l10n.budgetSaveFailed,
};
