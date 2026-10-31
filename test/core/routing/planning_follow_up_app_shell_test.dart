import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/offline/pending_operation_queue.dart';
import 'package:personal_finance/core/routing/app_shell.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/planning_agenda_entry.dart';
import 'package:personal_finance/features/finance/domain/entities/planning_follow_up.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/domain/repositories/planning_follow_up_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/widgets/planning_follow_up_controls.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _FollowUps implements PlanningFollowUpRepository {
  @override
  Stream<PlanningFollowUpSnapshot> watch(String userId) =>
      Stream.value(const PlanningFollowUpSnapshot());

  @override
  Future<Either<Failure, PlanningFollowUp?>> readCurrent(
    String userId,
    PlanningSource source,
  ) async => const Right(null);

  @override
  Future<Either<Failure, PlanningFollowUp>> mutate(
    String uid,
    PlanningFollowUpCommand command,
  ) async => Right(
    PlanningFollowUp(
      source: command.source,
      state: PlanningFollowUpState.dismissed,
      version: 1,
      dataGeneration: command.expectedGeneration,
    ),
  );
}

const _profile = UserProfile(
  id: 'qa',
  locale: 'es',
  countryCode: 'CO',
  timeZone: 'America/Bogota',
  defaultCurrency: 'COP',
  onboardingStatus: 'complete',
  categoryCatalogVersion: 100,
  dataGeneration: 1,
);

final _entry = PlanningAgendaEntry(
  id: 'debt:qa-car:2026-10',
  kind: PlanningEntryKind.debt,
  date: DateTime(2026, 10, 15),
  title: 'QA Vehículo',
  currency: 'COP',
  plannedMinor: 2400000,
  recordedMinor: 0,
  pendingMinor: 2400000,
  monthKey: '2026-10',
  commitmentId: 'qa-car',
  debtAccountId: 'qa-car-account',
);

void main() {
  testWidgets('tap opens the item detail; follow-up opens a contextual modal and hides Register', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('global_add_operation')), findsOneWidget);
    final semantics = tester.ensureSemantics();
    final tileSemantics = tester
        .getSemantics(find.byKey(const ValueKey('agenda_entry_debt:qa-car:2026-10')))
        .getSemanticsData();
    expect(tileSemantics.label, contains('Ver detalle de QA Vehículo'));
    expect(tileSemantics.hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
    await tester.tap(find.text('QA Vehículo'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de cuota QA'), findsOneWidget);
    expect(find.byKey(const ValueKey('global_add_operation')), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('global_add_operation')), findsOneWidget);

    final followUpButton = find.byKey(const ValueKey('planning_follow_up_debt:qa-car:2026-10'));
    expect(tester.widget<IconButton>(followUpButton).tooltip, 'Opciones de seguimiento de QA Vehículo');
    await tester.tap(followUpButton);
    await tester.pumpAndSettle();

    expect(find.text('Seguimiento de QA Vehículo'), findsOneWidget);
    expect(find.text('Tarjetas y préstamos · 15 oct 2026'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('global_add_operation')), findsNothing);
    expect(
      ProviderScope.containerOf(tester.element(find.byType(AppShell)))
          .read(planningFollowUpSheetOpenProvider),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('follow_up_dismiss')));
    await tester.pumpAndSettle();
    expect(find.text('Seguimiento de QA Vehículo'), findsNothing);
    expect(find.byKey(const ValueKey('global_add_operation')), findsOneWidget);
    expect(
      ProviderScope.containerOf(tester.element(find.byType(AppShell)))
          .read(planningFollowUpSheetOpenProvider),
      isFalse,
    );
  });

  testWidgets('closing the follow-up sheet with system back restores Register', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('planning_follow_up_debt:qa-car:2026-10')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('global_add_operation')), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Seguimiento de QA Vehículo'), findsNothing);
    expect(find.byKey(const ValueKey('global_add_operation')), findsOneWidget);
    expect(
      ProviderScope.containerOf(tester.element(find.byType(AppShell)))
          .read(planningFollowUpSheetOpenProvider),
      isFalse,
    );
  });

  testWidgets('modal barrier consumes taps on Home controls', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('planning_follow_up_debt:qa-car:2026-10')));
    await tester.pumpAndSettle();
    final settingsAction = find.byKey(const ValueKey('global_settings_action'));
    await tester.tapAt(tester.getCenter(settingsAction));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(find.byKey(const ValueKey('follow_up_dismiss')), findsNothing);
    expect(find.byKey(const ValueKey('global_add_operation')), findsOneWidget);
  });

  for (final (locale, optionLabel, sheetTitle) in [
    ('es', 'Opciones de seguimiento de QA Vehículo', 'Seguimiento de QA Vehículo'),
    ('en', 'Follow-up options for QA Vehículo', 'Follow-up for QA Vehículo'),
    ('pt', 'Opções de acompanhamento de QA Vehículo', 'Acompanhamento de QA Vehículo'),
  ]) {
    testWidgets('follow-up context is localized in $locale', (tester) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router, locale: Locale(locale)));
      await tester.pumpAndSettle();

      final button = find.byKey(const ValueKey('planning_follow_up_debt:qa-car:2026-10'));
      expect(tester.widget<IconButton>(button).tooltip, optionLabel);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(sheetTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('global_add_operation')), findsNothing);
    });
  }
}

GoRouter _router() => GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(
        navigationShell: shell,
        currentLocation: state.uri.path,
      ),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/home', builder: (_, _) => const _PlanningEntryHome())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/activity', builder: (_, _) => const Scaffold())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/accounts', builder: (_, _) => const Scaffold())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/budgets',
              builder: (_, _) => const Scaffold(),
              routes: [
                GoRoute(
                  path: 'debt-payments/:id',
                  builder: (_, _) => const Scaffold(body: Text('Detalle de cuota QA')),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/coach', builder: (_, _) => const Scaffold())],
        ),
      ],
    ),
  ],
);

Widget _app(GoRouter router, {Locale locale = const Locale('es')}) => ProviderScope(
  overrides: [
    authSessionProvider.overrideWith(
      (ref) => Stream.value(const AuthUser(id: 'qa', isAnonymous: false)),
    ),
    pendingOperationsProvider.overrideWith((ref) => Stream<List<PendingOperation>>.value([])),
    pendingOperationAutoSyncProvider.overrideWith((ref) {}),
    canonicalUserProfileProvider('qa').overrideWith((ref) => Stream.value(_profile)),
    planningFollowUpRepositoryProvider.overrideWithValue(_FollowUps()),
  ],
  child: MaterialApp.router(
    locale: locale,
    theme: ThemeData.light(),
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

class _PlanningEntryHome extends StatelessWidget {
  const _PlanningEntryHome();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: [
        PlanningEntryTile(
          entry: _entry,
          userId: 'qa',
          accounts: const [
            FinanceAccount(
              id: 'qa-car-account',
              name: 'QA Vehículo',
              type: 'loan',
              currency: 'COP',
              currentBalanceMinor: 20000000,
            ),
          ],
        ),
      ],
    ),
  );
}
