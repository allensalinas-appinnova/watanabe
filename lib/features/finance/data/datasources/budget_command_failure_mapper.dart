import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/error/failure.dart';

abstract final class BudgetCommandFailureMapper {
  static Failure fromException(Object error) {
    if (error is! FirebaseFunctionsException) {
      return const UnknownFailure('budget-command-failed');
    }
    final details = error.details;
    final issue = details is Map ? details['issue'] : null;
    const allowed = {
      'budget-already-exists',
      'budget-last-item',
      'budget-archived',
      'budget-item-archived',
      'budget-not-found',
      'budget-item-not-found',
      'budget-category-unavailable',
      'budget-invalid-day',
      'budget-amount-too-large',
      'budget-request-conflict',
      'budget-item-conflict',
      'budget-identity-conflict',
      'budget-invalid-input',
      'budget-invalid-item',
      'budget-invalid-items',
      'budget-invalid-reference',
      'budget-invalid-request-id',
      'budget-invalid-action',
    };
    if (issue is String && allowed.contains(issue)) {
      return ConflictFailure(issue, technicalCode: issue);
    }
    return switch (error.code) {
      'unavailable' || 'deadline-exceeded' || 'cancelled' => NetworkFailure(
        'budget-connection-required',
        technicalCode: error.code,
      ),
      'unauthenticated' ||
      'permission-denied' => AuthFailure('budget-session-expired', technicalCode: error.code),
      _ => const UnknownFailure('budget-command-failed'),
    };
  }
}
