import 'home_dashboard_preferences.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.locale,
    required this.countryCode,
    required this.timeZone,
    required this.defaultCurrency,
    required this.onboardingStatus,
    required this.categoryCatalogVersion,
    this.homeDashboardPreferences = const HomeDashboardPreferences(),
  });

  final String id;
  final String locale;
  final String countryCode;
  final String timeZone;
  final String defaultCurrency;
  final String onboardingStatus;
  final int categoryCatalogVersion;
  final HomeDashboardPreferences homeDashboardPreferences;
}
