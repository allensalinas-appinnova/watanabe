import '../../../../core/error/failure.dart';

enum BudgetCommandIssue {
  network,
  session,
  alreadyExists,
  lastItem,
  archived,
  notFound,
  categoryUnavailable,
  invalidDay,
  amountTooLarge,
  invalidInput,
  requestConflict,
  unexpected,
}

class BudgetCommandException implements Exception {
  factory BudgetCommandException.fromFailure(Failure failure) => BudgetCommandException(
    switch (failure.technicalCode ?? failure.message) {
      'budget-already-exists' => BudgetCommandIssue.alreadyExists,
      'budget-last-item' => BudgetCommandIssue.lastItem,
      'budget-archived' || 'budget-item-archived' => BudgetCommandIssue.archived,
      'budget-not-found' || 'budget-item-not-found' => BudgetCommandIssue.notFound,
      'budget-category-unavailable' => BudgetCommandIssue.categoryUnavailable,
      'budget-invalid-day' => BudgetCommandIssue.invalidDay,
      'budget-amount-too-large' => BudgetCommandIssue.amountTooLarge,
      'budget-request-conflict' ||
      'budget-item-conflict' ||
      'budget-identity-conflict' => BudgetCommandIssue.requestConflict,
      'budget-invalid-input' ||
      'budget-invalid-item' ||
      'budget-invalid-items' ||
      'budget-invalid-reference' ||
      'budget-invalid-request-id' ||
      'budget-invalid-action' => BudgetCommandIssue.invalidInput,
      _ => switch (failure) {
        NetworkFailure() => BudgetCommandIssue.network,
        AuthFailure() => BudgetCommandIssue.session,
        _ => BudgetCommandIssue.unexpected,
      },
    },
  );
  const BudgetCommandException(this.issue);

  final BudgetCommandIssue issue;
}
