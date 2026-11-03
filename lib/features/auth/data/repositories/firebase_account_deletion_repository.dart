import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/firebase_failure_mapper.dart';
import '../../domain/services/account_deletion_repository.dart';

class FirebaseAccountDeletionRepository implements AccountDeletionRepository {
  const FirebaseAccountDeletionRepository(this.functions, this.auth);
  final FirebaseFunctions functions;
  final FirebaseAuth auth;
  @override
  Future<Either<Failure, Unit>> request({
    required String userId,
    required String requestId,
    required int expectedGeneration,
  }) async {
    try {
      if (auth.currentUser?.uid != userId) return const Left(AuthFailure('session-expired'));
      final response = await functions
          .httpsCallable('requestAccountDeletion')
          .call<Map<String, dynamic>>({
            'requestId': requestId,
            'expectedOwnerUid': userId,
            'expectedGeneration': expectedGeneration,
            'confirmed': true,
          });
      if (response.data['status'] != 'accepted' || response.data['requestId'] != requestId) {
        return const Left(UnknownFailure('account-deletion-not-confirmed'));
      }
      return const Right(unit);
    } on FirebaseFunctionsException catch (e) {
      if (e.message == 'account-deletion-generation-conflict') {
        return const Left(
          ConflictFailure(
            'account-deletion-generation-conflict',
            technicalCode: 'account-deletion-generation-conflict',
          ),
        );
      }
      if (e.message == 'requires-recent-login') {
        return const Left(
          AuthFailure('requires-recent-login', technicalCode: 'requires-recent-login'),
        );
      }
      return Left(FirebaseFailureMapper.fromException(e));
    } catch (e) {
      return Left(FirebaseFailureMapper.fromException(e));
    }
  }
}
