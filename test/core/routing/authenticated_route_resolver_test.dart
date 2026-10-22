import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/routing/authenticated_route_resolver.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';

UserProfile profile(String status) => UserProfile(
  id: 'user-1',
  locale: 'es',
  countryCode: 'CO',
  timeZone: 'America/Bogota',
  defaultCurrency: 'COP',
  onboardingStatus: status,
  categoryCatalogVersion: 1,
);

void main() {
  test('profile reads are cached across redirects and invalidated after profile writes', () async {
    var reads = 0;
    Future<UserProfile?> load() async {
      reads++;
      return profile('complete');
    }

    await loadCachedUserProfile('cache-test-user', load);
    await loadCachedUserProfile('cache-test-user', load);
    expect(reads, 1);
    invalidateCachedUserProfile('cache-test-user');
    await loadCachedUserProfile('cache-test-user', load);
    expect(reads, 2);
    invalidateCachedUserProfile('cache-test-user');
  });

  test('keeps deep links and redirects missing or incomplete profiles to onboarding', () async {
    expect(
      await resolveAuthenticatedRoute(
        authenticated: true,
        matchedLocation: '/activity',
        loadProfile: () async => profile('incomplete'),
      ),
      '/onboarding',
    );
    expect(
      await resolveAuthenticatedRoute(
        authenticated: true,
        matchedLocation: '/activity',
        loadProfile: () async => null,
      ),
      '/onboarding',
    );
    expect(
      await resolveAuthenticatedRoute(
        authenticated: true,
        matchedLocation: '/activity',
        loadProfile: () async => profile('complete'),
      ),
      isNull,
    );
  });

  test('profile read failures navigate to recoverable state instead of throwing', () async {
    expect(
      await resolveAuthenticatedRoute(
        authenticated: true,
        matchedLocation: '/activity',
        loadProfile: () async => throw StateError('permission-denied'),
      ),
      '/session-recovery',
    );
  });

  test(
    'unauthenticated deep links return to login and recovery route avoids redirect loops',
    () async {
      expect(
        await resolveAuthenticatedRoute(
          authenticated: false,
          matchedLocation: '/budgets',
          loadProfile: () async => throw StateError('not called'),
        ),
        '/login',
      );
      expect(
        await resolveAuthenticatedRoute(
          authenticated: true,
          matchedLocation: '/session-recovery',
          loadProfile: () async => throw StateError('not called'),
        ),
        isNull,
      );
    },
  );
}
