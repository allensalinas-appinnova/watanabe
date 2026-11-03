import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/auth_access_method.dart';
import '../entities/auth_account_link_result.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

/// Reconciles uncertain responses before reauthentication and linking.
class LinkRegisteredAccessMethod {
  const LinkRegisteredAccessMethod(this.repository);
  final AuthRepository repository;

  Future<Either<Failure, AuthAccountLinkResult>> call({
    required AuthUser expectedUser,
    required AuthAccessMethod reauthenticateWith,
    required LinkAccessMethodCommand command,
    String? currentPassword,
  }) async {
    const changed = AuthFailure('Session changed', technicalCode: 'user-mismatch');
    final uid = expectedUser.id;
    if (expectedUser.isAnonymous ||
        command.expectedUid != uid ||
        repository.currentUser?.id != uid) {
      return const Left(changed);
    }
    final refreshed = await repository.refreshAccessMethods(expectedUid: uid);
    if (refreshed.isLeft()) return Left(refreshed.getLeft().toNullable()!);
    if (repository.currentUser?.id != uid) return const Left(changed);
    final current = refreshed.getRight().toNullable()!;
    if (current.id != uid) return const Left(changed);
    if (current.providerIds?.contains(command.method.providerId) == true) {
      return Right(AuthAccountLinkResult(user: current));
    }
    if (command.method == AuthAccessMethod.password && current.email != expectedUser.email) {
      return const Left(
        AuthFailure('Account details changed', technicalCode: 'access-details-changed'),
      );
    }
    final confirmed = await repository.reauthenticateForLinking(
      expectedUid: uid,
      method: reauthenticateWith,
      password: currentPassword,
    );
    if (confirmed.isLeft()) return Left(confirmed.getLeft().toNullable()!);
    if (repository.currentUser?.id != uid) return const Left(changed);
    final result = await repository.addAccessMethod(command);
    final resultUid = result.getRight().toNullable()?.user.id;
    if (repository.currentUser?.id != uid || (resultUid != null && resultUid != uid)) {
      return const Left(changed);
    }
    return result;
  }
}
