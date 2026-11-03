import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/firebase_failure_mapper.dart';
import '../../domain/entities/auth_access_method.dart';
import '../../domain/entities/auth_account_link_result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  AuthUser? get currentUser => _remoteDataSource.currentUser?.toEntity();

  @override
  Stream<AuthUser?> observeSession() async* {
    // Firebase Auth is the source of truth for the active UID. Yielding a cached
    // user before Firebase publishes the active UID after
    // logout/login, causing owner-scoped Firestore writes to be rejected.
    await for (final user in _remoteDataSource.observeSession()) {
      if (user == null) {
        await _localDataSource.clearCachedUser();
      } else {
        await _localDataSource.cacheUser(user);
      }
      yield user?.toEntity();
    }
  }

  @override
  Future<Either<Failure, AuthUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remoteDataSource.signIn(
        email: email,
        password: password,
      );
      await _localDataSource.cacheUser(user);
      return Right(user.toEntity());
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, AuthUser>> createAccount({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remoteDataSource.createAccount(
        email: email,
        password: password,
      );
      await _localDataSource.cacheUser(user);
      return Right(user.toEntity());
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, AuthUser>> refreshAccessMethods({required String expectedUid}) async {
    try {
      final user = await _remoteDataSource.refreshAccessMethods(expectedUid: expectedUid);
      if (user.id != expectedUid || _remoteDataSource.currentUser?.id != expectedUid) {
        return const Left(AuthFailure('Session changed', technicalCode: 'user-mismatch'));
      }
      await _cacheLinkedUserBestEffort(user);
      return Right(user.toEntity());
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> reauthenticateForLinking({
    required String expectedUid,
    required AuthAccessMethod method,
    String? password,
  }) async {
    try {
      await _remoteDataSource.reauthenticateForLinking(
        expectedUid: expectedUid,
        method: method,
        password: password,
      );
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, AuthAccountLinkResult>> addAccessMethod(
    LinkAccessMethodCommand command,
  ) async {
    try {
      final user = await _remoteDataSource.addAccessMethod(command);
      if (user.id != command.expectedUid ||
          _remoteDataSource.currentUser?.id != command.expectedUid) {
        return const Left(AuthFailure('Session changed', technicalCode: 'user-mismatch'));
      }
      bool? sent;
      if (command.method == AuthAccessMethod.password && user.emailVerified != true) {
        sent = false;
        try {
          await _remoteDataSource.sendEmailVerification();
          sent = true;
        } on Object {
          /* Link is already committed. */
        }
      }
      await _cacheLinkedUserBestEffort(user);
      return Right(AuthAccountLinkResult(user: user.toEntity(), emailVerificationSent: sent));
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, AuthUser>> signInWithGoogle() async {
    try {
      final user = await _remoteDataSource.signInWithGoogle();
      await _localDataSource.cacheUser(user);
      return Right(user.toEntity());
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, AuthUser>> signInWithApple() async {
    try {
      final user = await _remoteDataSource.signInWithApple();
      await _localDataSource.cacheUser(user);
      return Right(user.toEntity());
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, AuthAccountLinkResult>> linkApple() async {
    try {
      final user = await _remoteDataSource.linkApple();
      await _cacheLinkedUserBestEffort(user);
      return Right(AuthAccountLinkResult(user: user.toEntity()));
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> reauthenticateForDeletion({String? password}) async {
    try {
      await _remoteDataSource.reauthenticateForDeletion(password: password);
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, AuthAccountLinkResult>> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remoteDataSource.linkEmailPassword(email: email, password: password);
      var verificationSent = false;
      try {
        await _remoteDataSource.sendEmailVerification();
        verificationSent = true;
      } on Object {
        // Linking already succeeded. Delivery is a separate recoverable step.
      }
      await _cacheLinkedUserBestEffort(user);
      return Right(
        AuthAccountLinkResult(user: user.toEntity(), emailVerificationSent: verificationSent),
      );
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, AuthAccountLinkResult>> linkGoogle() async {
    try {
      final user = await _remoteDataSource.linkGoogle();
      await _cacheLinkedUserBestEffort(user);
      return Right(AuthAccountLinkResult(user: user.toEntity()));
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> sendEmailVerification() async {
    try {
      await _remoteDataSource.sendEmailVerification();
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> sendPasswordResetEmail({required String email}) async {
    try {
      await _remoteDataSource.sendPasswordResetEmail(email: email);
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, AuthUser>> signInAnonymously() async {
    try {
      final user = await _remoteDataSource.signInAnonymously();
      await _localDataSource.cacheUser(user);
      return Right(user.toEntity());
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _remoteDataSource.signOut();
      await _localDataSource.clearCachedUser();
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  Future<void> _cacheLinkedUserBestEffort(AuthUserModel user) async {
    try {
      await _localDataSource.cacheUser(user);
    } on Object {
      // Firebase remains the source of truth after a successful link.
    }
  }
}
