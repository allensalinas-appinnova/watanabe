import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/budget.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_flow_type.dart';
import 'package:personal_finance/features/finance/domain/entities/home_dashboard_preferences.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/home_dashboard_preferences_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _MockRepository extends Mock implements CanonicalFinanceRepository {}

class _FakeHomePreferences extends Fake implements HomeDashboardPreferences {}

const _profile = UserProfile(
  id: 'user-1',
  locale: 'es',
  countryCode: 'CO',
  timeZone: 'UTC',
  defaultCurrency: 'COP',
  onboardingStatus: 'complete',
  categoryCatalogVersion: 1,
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeHomePreferences()));

  Widget subject(_MockRepository repository) => ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: false)),
      ),
      canonicalFinanceRepositoryProvider.overrideWithValue(repository),
      canonicalUserProfileProvider('user-1').overrideWith((ref) => Stream.value(_profile)),
      canonicalCategoriesProvider('user-1').overrideWith((ref) => Stream.value(const [])),
      canonicalBudgetsProvider.overrideWith(
        (ref, input) => Stream.value([
          Budget(
            id: 'budget-1',
            categoryId: 'food',
            flowType: BudgetFlowType.expense,
            monthKey: input.monthKey,
            currency: 'COP',
            plannedAmountMinor: 10000,
            status: 'active',
          ),
        ]),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('es'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeDashboardPreferencesScreen(),
    ),
  );

  testWidgets('saves a selected widget and category preference immediately', (tester) async {
    final repository = _MockRepository();
    when(
      () => repository.updateHomeDashboardPreferences(any(), any()),
    ).thenAnswer((_) async => const Right(unit));
    await tester.pumpWidget(subject(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home_widget_incomeSummary')));
    await tester.pumpAndSettle();
    final captured =
        verify(
              () => repository.updateHomeDashboardPreferences(
                'user-1',
                captureAny(),
              ),
            ).captured.single
            as HomeDashboardPreferences;
    expect(captured.shows(HomeDashboardWidget.incomeSummary), isFalse);

    await tester.scrollUntilVisible(find.byKey(const ValueKey('home_budget_food')), 250);
    await tester.tap(find.byKey(const ValueKey('home_budget_food')));
    await tester.pumpAndSettle();
    final saves = verify(
      () => repository.updateHomeDashboardPreferences('user-1', captureAny()),
    ).captured;
    final latest = saves.last as HomeDashboardPreferences;
    expect(latest.showsBudget('food'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preserves selection after save error and retries it', (tester) async {
    final repository = _MockRepository();
    var calls = 0;
    when(() => repository.updateHomeDashboardPreferences(any(), any())).thenAnswer((_) async {
      calls++;
      return calls == 1 ? const Left(NetworkFailure('offline')) : const Right(unit);
    });
    await tester.pumpWidget(subject(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home_widget_recentActivity')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tu selección se conserva'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byKey(const ValueKey('home_widget_recentActivity'))).value,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('home_preferences_retry')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('Tu selección se conserva'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
