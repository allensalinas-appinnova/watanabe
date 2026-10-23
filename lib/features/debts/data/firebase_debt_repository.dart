import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';
import '../../../core/error/failure.dart';
import '../domain/debt_command.dart';
import '../domain/debt_repository.dart';

abstract interface class DebtCommandService {
  Future<Map<String, dynamic>> execute(String userId, Map<String, Object?> command);
}

class FirebaseDebtCommandService implements DebtCommandService {
  FirebaseDebtCommandService(this.functions, this.auth);
  final FirebaseFunctions functions;
  final FirebaseAuth auth;
  @override
  Future<Map<String, dynamic>> execute(String userId, Map<String, Object?> command) async {
    if (auth.currentUser?.uid != userId) {
      throw FirebaseFunctionsException(code: 'unauthenticated', message: 'debt-session-expired');
    }
    final response = await functions
        .httpsCallable(
          'mutateDebt',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        )
        .call<Map<String, dynamic>>(command);
    return Map<String, dynamic>.from(response.data);
  }
}

class FirebaseDebtRepository implements DebtRepository {
  FirebaseDebtRepository(this.service);
  final DebtCommandService service;
  @override
  Future<Either<Failure, DebtCommandResult>> execute(String userId, DebtCommand command) async {
    try {
      final result = await service.execute(userId, command.toMap());
      return Right(
        DebtCommandResult(
          accountId: result['accountId'] as String,
          operationIds: List<String>.from(result['operationIds'] as List),
          overLimit: result['overLimit'] as bool,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final raw = details is Map ? details['issue'] : null;
      final issue = raw is String && RegExp(r'^debt-[a-z-]{1,64}$').hasMatch(raw)
          ? raw
          : 'debt-command-failed';
      return Left(switch (error.code) {
        'unauthenticated' => const AuthFailure('debt-session-expired'),
        'unavailable' || 'deadline-exceeded' => const NetworkFailure('debt-connection-required'),
        'already-exists' => ConflictFailure(issue),
        _ => UnknownFailure(issue),
      });
    } catch (_) {
      return const Left(UnknownFailure('debt-command-failed'));
    }
  }
}
