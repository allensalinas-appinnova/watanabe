import 'package:fpdart/fpdart.dart';
import '../../../core/error/failure.dart';
import 'debt_command.dart';

abstract interface class DebtRepository {
  Future<Either<Failure, DebtCommandResult>> execute(String userId, DebtCommand command);
}
