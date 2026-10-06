class UserProfile {
  const UserProfile({
    required this.id,
    required this.locale,
    required this.countryCode,
    required this.timeZone,
    required this.defaultCurrency,
    required this.onboardingStatus,
    required this.categoryCatalogVersion,
  });

  final String id;
  final String locale;
  final String countryCode;
  final String timeZone;
  final String defaultCurrency;
  final String onboardingStatus;
  final int categoryCatalogVersion;
}
