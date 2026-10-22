sealed class Failure {
  const Failure(this.message, {this.technicalCode});

  final String message;

  /// Sanitized SDK code only; never contains the raw exception message.
  final String? technicalCode;
}

final class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.technicalCode});
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.technicalCode});
}

final class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {super.technicalCode});
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.technicalCode});
}
