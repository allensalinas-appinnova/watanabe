import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';

void main() {
  for (final sample in [
    (instant: DateTime.utc(2026,11,1,1), expected: DateTime(2026,10,31)),
    (instant: DateTime.utc(2027,1,1,1), expected: DateTime(2026,12,31)),
    (instant: DateTime.utc(2028,3,1,1), expected: DateTime(2028,2,29)),
  ]) {
    test('profile calendar controls Home, Plan and Activity at ${sample.instant}', () async {
      final container=ProviderContainer(overrides:[
        authSessionProvider.overrideWith((_)=>Stream.value(const AuthUser(id:'qa-calendar',isAnonymous:false))),
        planningClockProvider.overrideWithValue(()=>sample.instant),
        planningTickProvider.overrideWith((_)=>Stream.value(sample.instant)),
        canonicalUserProfileProvider('qa-calendar').overrideWith((_)=>Stream.value(const UserProfile(id:'qa-calendar',locale:'es',countryCode:'CO',timeZone:'America/Bogota',defaultCurrency:'COP',onboardingStatus:'complete',categoryCatalogVersion:1))),
      ]);
      addTearDown(container.dispose);
      final authSubscription = container.listen(authSessionProvider, (_, _) {});
      final profileSubscription = container.listen(canonicalUserProfileProvider('qa-calendar'), (_, _) {});
      addTearDown(authSubscription.close);
      addTearDown(profileSubscription.close);
      await container.read(authSessionProvider.future);
      await container.read(canonicalUserProfileProvider('qa-calendar').future);
      expect(container.read(planningTodayProvider('qa-calendar')),sample.expected);
      expect(container.read(planningMonthProvider('qa-calendar')),DateTime(sample.expected.year,sample.expected.month));
      expect(container.read(activityQueryFiltersProvider).monthKey,DateFormatMonth.key(sample.expected));
      container.read(planningMonthProvider('qa-calendar').notifier).select(DateTime(2030,4));
      container.read(activityQueryFiltersProvider.notifier).apply(const ActivityQueryFilters(monthKey:'2030-04',hasBeenApplied:true));
      expect(container.read(planningMonthProvider('qa-calendar')),DateTime(2030,4));
      expect(container.read(activityQueryFiltersProvider).monthKey,'2030-04');
    });
  }
}
