import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> observeSession();

  Future<Either<Failure, AuthUser>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, AuthUser>> createAccount({
    required String email,
    required String password,
  });

  Future<Either<Failure, AuthUser>> signInWithGoogle();

  Future<Either<Failure, Unit>> sendPasswordResetEmail({required String email});

  Future<Either<Failure, AuthUser>> signInAnonymously();

  Future<Either<Failure, Unit>> signOut();
}
