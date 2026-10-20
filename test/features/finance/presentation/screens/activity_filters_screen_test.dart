import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/offline/sync_state.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/activity_filters_screen.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_activity_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _MockFinanceRepository extends Mock implements CanonicalFinanceRepository {}

void main() {
  late _MockFinanceRepository repository;
  late GoRouter router;

  setUp(() {
    repository = _MockFinanceRepository();
    when(
      () => repository.fetchOperationsPage(
        any(),
        cursor: any(named: 'cursor'),
        monthKey: any(named: 'monthKey'),
        currency: any(named: 'currency'),
        type: any(named: 'type'),
        accountId: any(named: 'accountId'),
        accountIds: any(named: 'accountIds'),
        startAt: any(named: 'startAt'),
        endAtExclusive: any(named: 'endAtExclusive'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const Right(OperationPage(items: [])));
    router = GoRouter(
      initialLocation: '/activity',
      routes: [
        GoRoute(
          path: '/activity',
          builder: (context, state) => const CanonicalActivityScreen(),
          routes: [
            GoRoute(
              path: 'filters',
              builder: (context, state) => const ActivityFiltersScreen(),
            ),
          ],
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  Widget buildSubject() => ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
      ),
      canonicalFinanceRepositoryProvider.overrideWithValue(repository),
      canonicalAccountsProvider('user-1').overrideWith(
        (ref) => Stream.value(const [
          FinanceAccount(id: 'account-1', name: 'Banco1 Ahorros', type: 'savings'),
          FinanceAccount(id: 'account-2', name: 'Efectivo', type: 'cash'),
        ]),
      ),
      pendingOperationSyncStatusProvider.overrideWith(
        (ref) => Stream.value(
          const SyncStatusSnapshot(pending: 0, syncing: 0, confirmed: 0, rejected: 0),
        ),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );

  testWidgets('applies account selection and returns to Activity with the filter visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_open_filters')));
    await tester.pumpAndSettle();

    expect(find.text('Filter activity'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity_filter_account_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_account_option_account-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity_account_selection_done')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity_account_selection_done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_filter_apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity_filter_summary')), findsOneWidget);
    expect(find.textContaining('Banco1 Ahorros'), findsWidgets);
    expect(find.textContaining('Todas las cuentas'), findsNothing);
  });

  testWidgets('closing filters discards the draft and leaves Activity context intact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_open_filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_filter_account_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_account_option_account-1')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 300));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.text('All accounts'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity_filter_account_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_account_option_account-1')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_filters_close')));
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsOneWidget);
    expect(find.textContaining('All accounts'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity_filter_summary')), findsNothing);
  });

  testWidgets('selects several accounts and applies their union to Activity', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_open_filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_filter_account_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_account_option_account-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_account_option_account-2')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .where(
            (tile) =>
                tile.key == const ValueKey('activity_account_option_account-1') ||
                tile.key == const ValueKey('activity_account_option_account-2'),
          )
          .every((tile) => tile.value == true),
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('activity_account_selection_done')));
    await tester.pumpAndSettle();

    expect(find.text('2 accounts'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity_filter_apply')));
    await tester.pumpAndSettle();
    verify(
      () => repository.fetchOperationsPage(
        'user-1',
        cursor: any(named: 'cursor'),
        monthKey: any(named: 'monthKey'),
        currency: any(named: 'currency'),
        type: any(named: 'type'),
        accountId: any(named: 'accountId'),
        accountIds: ['account-1', 'account-2'],
        startAt: any(named: 'startAt'),
        endAtExclusive: any(named: 'endAtExclusive'),
        pageSize: any(named: 'pageSize'),
      ),
    ).called(greaterThan(0));
  });

  testWidgets('date range controls fit compact screens with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_open_filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date range'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity_filter_start_date_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('activity_filter_end_date_field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
