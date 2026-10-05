import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/finance_repository.dart';

class UpdateBudgetLimits {
  const UpdateBudgetLimits(this._repository);

  final FinanceRepository _repository;

  Future<Either<Failure, Unit>> call(
    String userId,
    Map<String, double> limitsByBudgetId,
  ) {
    return _repository.updateBudgetLimits(userId, limitsByBudgetId);
  }
}
