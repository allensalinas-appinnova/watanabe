import 'auth_user.dart';

class AuthAccountLinkResult {
  const AuthAccountLinkResult({
    required this.user,
    this.emailVerificationSent,
  });

  final AuthUser user;

  /// Null means email verification does not apply to the linked provider.
  final bool? emailVerificationSent;
}
