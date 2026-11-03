enum AuthAccessMethod {
  password('password'),
  google('google.com'),
  apple('apple.com');

  const AuthAccessMethod(this.providerId);
  final String providerId;
}

bool isApplePrivateEmail(String? email) =>
    email?.trim().toLowerCase().endsWith('@privaterelay.appleid.com') ?? false;

/// Ephemeral credentials: never serialize or persist this command.
class LinkAccessMethodCommand {
  const LinkAccessMethodCommand({
    required this.expectedUid,
    required this.method,
    this.password,
    this.applePrivateEmailConsent = false,
  });
  final String expectedUid;
  final AuthAccessMethod method;
  final String? password;
  final bool applePrivateEmailConsent;
}
