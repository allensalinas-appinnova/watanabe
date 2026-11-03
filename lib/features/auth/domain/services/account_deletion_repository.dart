import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';

abstract interface class AccountDeletionRepository {
  Future<Either<Failure, Unit>> request({
    required String userId,
    required String requestId,
    required int expectedGeneration,
  });
}
