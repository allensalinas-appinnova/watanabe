import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/offline/pending_operation_queue.dart';
import 'package:personal_finance/core/routing/app_shell.dart';
import 'package:personal_finance/core/utils/async_value_extensions.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/models/movement_save_result.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('confirmed save refreshes Activity while preserving All filter', (tester) async {
    final repository = _MockFinanceRepository();
    var reads = 0;
    final existing = _testOperation(id: 'existing', description: 'Existing');
    final saved = _testOperation(id: 'saved', description: 'New expense');
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
    ).thenAnswer((_) async {
      reads++;
      return Right(OperationPage(items: reads == 1 ? [existing] : [existing, saved]));
    });

    final router = _router(
      initialLocation: '/activity',
      returnReceipts: true,
      watchActivityPager: true,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, repository: repository));
    await tester.pumpAndSettle();
    await _pumpAsync(tester);
    expect(find.textContaining('activity-items:1'), findsOneWidget);
    expect(reads, 1);

    await tester.tap(find.byKey(const ValueKey('global_add_operation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_movement_expense')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fake_save')));
    await tester.pumpAndSettle();

    await _pumpAsync(tester);
    expect(find.textContaining('activity-items:2'), findsOneWidget);
    expect(find.textContaining('All filter'), findsOneWidget);
    expect(reads, 2);
    expect(_selectedTab(tester), 1);
  });

  testWidgets('confirmed save refreshes Home recent activity', (tester) async {
    final repository = _MockFinanceRepository();
    var reads = 0;
    final existing = _testOperation(id: 'existing-home', description: 'Existing home');
    final saved = _testOperation(id: 'saved-home', description: 'New home expense');
    when(
      () => repository.fetchOperationsPage(
        any(),
        cursor: any(named: 'cursor'),
        monthKey: any(named: 'monthKey'),
        currency: any(named: 'currency'),
        type: any(named: 'type'),
        accountId: any(named: 'accountId'),
        startAt: any(named: 'startAt'),
        endAtExclusive: any(named: 'endAtExclusive'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async {
      reads++;
      return Right(OperationPage(items: reads == 1 ? [existing] : [existing, saved]));
    });

    final router = _router(
      initialLocation: '/home',
      returnReceipts: true,
      watchHomeRecent: true,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, repository: repository));
    await tester.pumpAndSettle();
    await _pumpAsync(tester);
    expect(find.text('home-recent:1'), findsOneWidget);
    expect(reads, 1);

    await tester.tap(find.byKey(const ValueKey('global_add_operation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_movement_expense')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fake_save')));
    await tester.pumpAndSettle();

    await _pumpAsync(tester);
    expect(find.textContaining('home-recent:2'), findsOneWidget);
    expect(find.text('New home expense'), findsOneWidget);
    expect(reads, 2);
    expect(_selectedTab(tester), 0);
  });

  testWidgets('save feedback can be dismissed without viewing the transaction', (tester) async {
    final router = _router(initialLocation: '/home', returnReceipts: true);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('global_add_operation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_movement_expense')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fake_save')));
    await tester.pumpAndSettle();

    expect(find.text('View transaction'), findsOneWidget);
    expect(_selectedTab(tester), 0);
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    expect(find.text('View transaction'), findsNothing);
    expect(find.text('Test'), findsNothing);
    expect(_selectedTab(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('budget routes return to the active branch and preserve its tab', (tester) async {
    final router = _router(initialLocation: '/budgets');
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open_create')));
    await tester.pumpAndSettle();
    expect(find.text('Budget create route'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('form_back')));
    await tester.pumpAndSettle();
    expect(find.text('Budget list').hitTestable(), findsOneWidget);
    expect(_selectedTab(tester), 3);

    await tester.tap(find.byKey(const ValueKey('open_detail')));
    await tester.pumpAndSettle();
    expect(find.text('Budget detail'), findsOneWidget);
    expect(find.byKey(const ValueKey('global_add_operation')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('form_back')));
    await tester.pumpAndSettle();
    expect(find.text('Budget list').hitTestable(), findsOneWidget);
    expect(_selectedTab(tester), 3);

    await tester.tap(find.byKey(const ValueKey('open_tracking')));
    await tester.pumpAndSettle();
    expect(find.text('Budget tracking'), findsOneWidget);
    expect(find.byKey(const ValueKey('global_add_operation')), findsNothing);
    expect(_selectedTab(tester), 3);
    await tester.tap(find.byKey(const ValueKey('form_back')));
    await tester.pumpAndSettle();
    expect(find.text('Budget list').hitTestable(), findsOneWidget);
  });

  testWidgets('global add action is limited to Home and Activity', (
    tester,
  ) async {
    final router = _router(initialLocation: '/home');
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('global_add_operation')), findsOneWidget);
    for (final index in [1, 0]) {
      await _selectTab(tester, index);
      expect(find.byKey(const ValueKey('global_add_operation')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('global_add_operation')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('movement_action_sheet')), findsOneWidget);
      expect(find.byKey(const ValueKey('add_movement_income')), findsOneWidget);
      expect(find.byKey(const ValueKey('add_movement_expense')), findsOneWidget);
      expect(find.byKey(const ValueKey('add_movement_transfer')), findsOneWidget);
      expect(find.byKey(const ValueKey('add_movement_debtPayment')), findsOneWidget);
      expect(find.byKey(const ValueKey('global_add_operation')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('add_movement_close')));
      await tester.tap(find.byKey(const ValueKey('add_movement_close')));
      await tester.pumpAndSettle();
      expect(_selectedTab(tester), index);
    }
    for (final index in [2, 3, 4]) {
      await _selectTab(tester, index);
      expect(find.byKey(const ValueKey('global_add_operation')), findsNothing);
    }
  });

  testWidgets('Settings is available on every section and returns to the originating tab', (
    tester,
  ) async {
    final router = _router(initialLocation: '/home');
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    for (final index in [1, 2, 3, 4, 0]) {
      await _selectTab(tester, index);
      expect(find.byKey(const ValueKey('global_settings_action')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('global_settings_action')));
      await tester.pumpAndSettle();
      expect(find.text('Settings route'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('form_back')));
      await tester.pumpAndSettle();
      expect(_selectedTab(tester), index);
    }
  });

  testWidgets('fixed register action remains pinned while the active section scrolls', (
    tester,
  ) async {
    final router = _router(initialLocation: '/home', scrollableHome: true);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    final registerAction = find.byKey(const ValueKey('global_add_operation'));
    final topBeforeScroll = tester.getTopLeft(registerAction).dy;
    expect(registerAction.hitTestable(), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('scrollable_home_fixture'))),
    );
    await gesture.moveBy(const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(registerAction.hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(registerAction).dy, topBeforeScroll);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(registerAction.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each action opens its existing form and back restores the origin tab', (
    tester,
  ) async {
    final router = _router(initialLocation: '/home');
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    for (final action in [
      ('add_movement_income', 'operation:income'),
      ('add_movement_expense', 'operation:expense'),
      ('add_movement_transfer', 'transfer route'),
    ]) {
      await tester.tap(find.byKey(const ValueKey('global_add_operation')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(action.$1)));
      await tester.pumpAndSettle();
      expect(find.text(action.$2), findsOneWidget);
      expect(find.byKey(const ValueKey('global_add_operation')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('form_back')));
      await tester.pumpAndSettle();
      expect(_selectedTab(tester), 0);
      expect(find.text('Home').first.hitTestable(), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('global_add_operation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_movement_debtPayment')));
    await tester.pumpAndSettle();
    expect(find.text('Debt payment picker'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('form_back')));
    await tester.pumpAndSettle();
    expect(_selectedTab(tester), 0);
  });

  testWidgets('sheet fits compact viewport with enlarged Portuguese text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _router(initialLocation: '/home');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      _app(
        router,
        locale: const Locale('pt'),
        textScale: 1.4,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('global_add_operation')));
    await tester.pumpAndSettle();

    expect(find.text('O que você quer adicionar?'), findsOneWidget);
    expect(find.bySemanticsLabel('Adicionar receita'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('add_movement_transfer')));
    expect(find.text('Mover dinheiro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a saved movement excluded by Activity filters keeps them unchanged', (tester) async {
    final router = _router(
      initialLocation: '/activity',
      filteredActivity: true,
      returnReceipts: true,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.text('filter:expense'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('global_add_operation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_movement_income')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fake_save')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('This transaction is hidden by your current filters'),
      findsOneWidget,
    );
    expect(find.text('View transaction'), findsNothing);
    expect(find.text('filter:expense'), findsOneWidget);
    expect(_selectedTab(tester), 1);
  });

  testWidgets('a durably queued movement returns as pending, not confirmed', (tester) async {
    final router = _router(
      initialLocation: '/home',
      returnReceipts: true,
      pendingReceipts: true,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('global_add_operation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_movement_expense')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fake_save')));
    await tester.pumpAndSettle();

    expect(
      find.text('Saved on this device. It will sync when your connection returns.'),
      findsOneWidget,
    );
    expect(find.text('View pending'), findsOneWidget);
    expect(find.textContaining('Expense registered'), findsNothing);
    expect(find.text('Home').first.hitTestable(), findsOneWidget);
    expect(_selectedTab(tester), 0);
  });
}

Widget _app(
  GoRouter router, {
  Locale? locale,
  double textScale = 1,
  CanonicalFinanceRepository? repository,
}) => ProviderScope(
  overrides: [
    pendingOperationsProvider.overrideWith((ref) => Stream<List<PendingOperation>>.value([])),
    pendingOperationAutoSyncProvider.overrideWith((ref) {}),
    if (repository != null) canonicalFinanceRepositoryProvider.overrideWithValue(repository),
    if (repository != null)
      authSessionProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(id: 'test-user', isAnonymous: true)),
      ),
  ],
  child: MaterialApp.router(
    locale: locale,
    routerConfig: router,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  ),
);

GoRouter _router({
  required String initialLocation,
  bool filteredActivity = false,
  bool returnReceipts = false,
  bool pendingReceipts = false,
  bool watchActivityPager = false,
  bool watchHomeRecent = false,
  bool scrollableHome = false,
}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(
        navigationShell: shell,
        currentLocation: state.uri.path,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => watchHomeRecent
                  ? const _HomeRecentTab()
                  : scrollableHome
                  ? const _ScrollableHomeTab()
                  : const _Tab('Home'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/activity',
              builder: (_, _) => watchActivityPager
                  ? const _ActivityPagerTab()
                  : filteredActivity
                  ? const _FilteredActivityTab()
                  : const _Tab('Activity'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/accounts',
              builder: (_, _) => const _Tab('Accounts'),
              routes: [
                GoRoute(
                  path: 'pay-debt',
                  builder: (_, _) => const _BackForm('Debt payment picker'),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/budgets',
              builder: (_, _) => const _BudgetTab(),
              routes: [
                GoRoute(path: 'tracking', builder: (_, _) => const _BackForm('Budget tracking')),
                GoRoute(path: 'new', builder: (_, _) => const _BackForm('Budget create route')),
                GoRoute(path: ':id', builder: (_, _) => const _BackForm('Budget detail')),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/coach', builder: (_, _) => const _Tab('Coach'))],
        ),
      ],
    ),
    GoRoute(
      path: '/operations/new',
      builder: (_, state) => returnReceipts
          ? _SavingForm(
              type: state.uri.queryParameters['type'] == 'income'
                  ? OperationType.income
                  : OperationType.expense,
              pending: pendingReceipts,
            )
          : _BackForm('operation:${state.uri.queryParameters['type']}'),
    ),
    GoRoute(
      path: '/transfers/new',
      builder: (_, _) => returnReceipts
          ? _SavingForm(type: OperationType.transfer, pending: pendingReceipts)
          : const _BackForm('transfer route'),
    ),
    GoRoute(path: '/settings', builder: (_, _) => const _BackForm('Settings route')),
  ],
);

int _selectedTab(WidgetTester tester) => tester
    .widget<NavigationBar>(find.byKey(const ValueKey('finance_bottom_navigation')))
    .selectedIndex;

Future<void> _selectTab(WidgetTester tester, int index) async {
  const keys = [
    'finance_nav_home',
    'finance_nav_activity',
    'finance_nav_accounts',
    'finance_nav_budget',
    'finance_nav_coach',
  ];
  await tester.tap(find.byKey(ValueKey(keys[index])).hitTestable());
  await tester.pumpAndSettle();
}

Future<void> _pumpAsync(WidgetTester tester) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(title)));
}

class _ScrollableHomeTab extends StatelessWidget {
  const _ScrollableHomeTab();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView.builder(
      key: const ValueKey('scrollable_home_fixture'),
      itemCount: 30,
      itemBuilder: (context, index) => SizedBox(height: 56, child: Text('row $index')),
    ),
  );
}

class _BudgetTab extends StatelessWidget {
  const _BudgetTab();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const Text('Budget list'),
        TextButton(
          key: const ValueKey('open_create'),
          onPressed: () => context.push('/budgets/new'),
          child: const Text('Create'),
        ),
        TextButton(
          key: const ValueKey('open_detail'),
          onPressed: () => context.push('/budgets/test-budget'),
          child: const Text('Detail'),
        ),
        TextButton(
          key: const ValueKey('open_tracking'),
          onPressed: () => context.push('/budgets/tracking'),
          child: const Text('Tracking'),
        ),
      ],
    ),
  );
}

class _BackForm extends StatelessWidget {
  const _BackForm(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label),
        TextButton(
          key: const ValueKey('form_back'),
          onPressed: context.pop,
          child: const Text('Back'),
        ),
      ],
    ),
  );
}

class _FilteredActivityTab extends ConsumerStatefulWidget {
  const _FilteredActivityTab();

  @override
  ConsumerState<_FilteredActivityTab> createState() => _FilteredActivityTabState();
}

class _ActivityPagerTab extends ConsumerWidget {
  const _ActivityPagerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Text('No test user'));
    final type = ref.watch(activityTypeFilterProvider);
    final page = ref.watch(
      operationsPagerProvider((userId: user.id, type: type, debtPaymentsOnly: false)),
    );
    return Scaffold(
      body: Center(
        child: Text('activity-items:${page.valueOrNull?.items.length ?? 0} · All filter'),
      ),
    );
  }
}

class _HomeRecentTab extends ConsumerWidget {
  const _HomeRecentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Text('No test user'));
    final page = ref.watch(
      canonicalOperationsPageProvider((
        userId: user.id,
        cursor: null,
        monthKey: null,
        currency: null,
        type: null,
        accountIds: null,
        pageSize: 10,
      )),
    );
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('home-recent:${page.valueOrNull?.items.length ?? 0}'),
            for (final operation in page.valueOrNull?.items ?? const <FinancialOperation>[])
              Text(operation.description),
          ],
        ),
      ),
    );
  }
}

class _FilteredActivityTabState extends ConsumerState<_FilteredActivityTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityTypeFilterProvider.notifier).select(OperationType.expense);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text('filter:${ref.watch(activityTypeFilterProvider)?.name}')),
  );
}

class _SavingForm extends StatelessWidget {
  const _SavingForm({required this.type, this.pending = false});
  final OperationType type;
  final bool pending;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('fake_save'),
        onPressed: () => context.pop(
          MovementSaveResult(
            type: type,
            status: pending ? MovementSaveStatus.pending : MovementSaveStatus.confirmed,
            amountMinor: 8000,
            currency: 'COP',
            idempotencyKey: 'test-operation-123456',
            occurredAt: DateTime(2026, 10, 20),
            description: 'Test',
          ),
        ),
        child: const Text('Save'),
      ),
    ),
  );
}

class _MockFinanceRepository extends Mock implements CanonicalFinanceRepository {}

FinancialOperation _testOperation({required String id, required String description}) =>
    FinancialOperation(
      id: id,
      type: OperationType.expense,
      amountMinor: 5000,
      currency: 'COP',
      monthKey: '2026-10',
      occurredAt: DateTime(2026, 10, 19),
      status: OperationStatus.confirmed,
      idempotencyKey: 'idempotency-$id',
      description: description,
    );
