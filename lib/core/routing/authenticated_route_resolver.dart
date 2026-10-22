import '../../features/finance/domain/entities/user_profile.dart';

typedef UserProfileLoader = Future<UserProfile?> Function();

final Map<String, Future<UserProfile?>> _profileReads = {};

Future<UserProfile?> loadCachedUserProfile(String userId, UserProfileLoader loader) =>
    _profileReads.putIfAbsent(userId, () {
      late final Future<UserProfile?> cached;
      cached = loader().then(
        (profile) => profile,
        onError: (Object error, StackTrace stackTrace) {
          _profileReads.remove(userId);
          Error.throwWithStackTrace(error, stackTrace);
        },
      );
      return cached;
    });

void invalidateCachedUserProfile(String userId) => _profileReads.remove(userId);

Future<String?> resolveAuthenticatedRoute({
  required bool authenticated,
  required String matchedLocation,
  required UserProfileLoader loadProfile,
}) async {
  const login = '/login';
  const onboarding = '/onboarding';
  const recovery = '/session-recovery';
  if (!authenticated) return matchedLocation == login ? null : login;
  if (matchedLocation == recovery) return null;

  try {
    final profile = await loadProfile();
    final onboardingComplete = profile?.onboardingStatus == 'complete';
    if (!onboardingComplete && matchedLocation != onboarding) return onboarding;
    if (onboardingComplete && (matchedLocation == onboarding || matchedLocation == login)) {
      return '/home';
    }
    return null;
  } on Object {
    return recovery;
  }
}
