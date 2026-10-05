import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/send_password_reset_email.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';

final authSessionProvider = StreamProvider<AuthUser?>((ref) {
  return getIt<AuthRepository>().observeSession();
});

final authControllerProvider = NotifierProvider<AuthController, AuthActionState>(
  AuthController.new,
);

enum AuthActionStatus { idle, loading, success, failure }

class AuthActionState {
  const AuthActionState({
    this.status = AuthActionStatus.idle,
    this.failure,
    this.navigateToHome = false,
    this.message,
  });

  const AuthActionState.loading() : this(status: AuthActionStatus.loading);

  const AuthActionState.success({bool navigateToHome = false})
    : this(status: AuthActionStatus.success, navigateToHome: navigateToHome);

  const AuthActionState.completedWithMessage(String message)
    : this(status: AuthActionStatus.success, message: message);

  const AuthActionState.failure(Failure failure)
    : this(status: AuthActionStatus.failure, failure: failure);

  final AuthActionStatus status;
  final Failure? failure;
  final bool navigateToHome;
  final String? message;
}

class AuthController extends Notifier<AuthActionState> {
  AuthRepository get _repository => getIt<AuthRepository>();

  @override
  AuthActionState build() => const AuthActionState();

  Future<void> signIn({required String email, required String password}) async {
    state = const AuthActionState.loading();
    final result = await SignIn(_repository)(email: email, password: password);
    state = result.match(
      AuthActionState.failure,
      (_) => const AuthActionState.success(navigateToHome: true),
    );
  }

  Future<void> signInAnonymously() async {
    state = const AuthActionState.loading();
    final result = await _repository.signInAnonymously();
    state = result.match(
      AuthActionState.failure,
      (_) => const AuthActionState.success(navigateToHome: true),
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AuthActionState.loading();
    final result = await SignInWithGoogle(_repository)();
    state = result.match(
      AuthActionState.failure,
      (_) => const AuthActionState.success(navigateToHome: true),
    );
  }

  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    state = const AuthActionState.loading();
    final result = await _repository.createAccount(
      email: email,
      password: password,
    );
    state = result.match(
      AuthActionState.failure,
      (_) => const AuthActionState.success(navigateToHome: true),
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    state = const AuthActionState.loading();
    final result = await SendPasswordResetEmail(_repository)(email: email);
    state = result.match(
      AuthActionState.failure,
      (_) => const AuthActionState.completedWithMessage(
        'If an account exists for this email, a reset link has been sent.',
      ),
    );
  }

  Future<void> signOut() async {
    state = const AuthActionState.loading();
    final result = await SignOut(_repository)();
    state = result.match(
      AuthActionState.failure,
      (_) => const AuthActionState.success(),
    );
  }
}
