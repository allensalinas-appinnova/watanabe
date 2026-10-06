import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/firebase_failure_mapper.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Stream<AuthUser?> observeSession() async* {
    // Firebase Auth is the source of truth for the active UID. Yielding a cached
    // user before authStateChanges() can briefly expose another user's UID after
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
}
