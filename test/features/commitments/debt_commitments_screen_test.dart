import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/commitments/domain/commitment_repository.dart';
import 'package:personal_finance/features/commitments/domain/debt_commitment.dart';
import 'package:personal_finance/features/commitments/presentation/debt_commitments_screen.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  final month = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

  Widget subject({List<DebtCommitment> commitments = const []}) {
    final router = GoRouter(
      initialLocation: '/budgets/debt-payments',
      routes: [
        GoRoute(
          path: '/budgets/debt-payments',
          builder: (context, state) => const DebtCommitmentsScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const Scaffold(body: Text('New commitment form')),
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: false)),
        ),
        canonicalAccountsProvider.overrideWith((ref, userId) => Stream.value(const [])),
        debtCommitmentsProvider.overrideWith((ref, userId) => Stream.value(commitments)),
        debtCommitmentPaymentsProvider.overrideWith(
          (ref, userId) => Stream.value(const <DebtCommitmentPaymentLink>[]),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('es'),
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
  }

  testWidgets('keeps the plan payment action fixed when there are no commitments', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    final create = find.byKey(const ValueKey('debt_commitment_create'));
    expect(create.hitTestable(), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Aún no has planificado pagos de deudas.'), findsOneWidget);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('New commitment form'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the plan payment action visible with a long list', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final manyCommitments = List.generate(
      24,
      (index) => DebtCommitment(
        id: 'commitment-$index',
        debtAccountId: 'debt-$index',
        currency: 'COP',
        amountMinor: 100000,
        firstDueMonth: month,
        dueDay: 15,
      ),
    );
    await tester.pumpWidget(subject(commitments: manyCommitments));
    await tester.pumpAndSettle();

    final create = find.byKey(const ValueKey('debt_commitment_create'));
    expect(create.hitTestable(), findsOneWidget);
    final listScrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    final scrollable = tester.state<ScrollableState>(listScrollable.first);
    expect(scrollable.position.maxScrollExtent, greaterThan(500));
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(create.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('excludes skipped and paused occurrences from planned count and total', (
    tester,
  ) async {
    final commitments = [
      DebtCommitment(
        id: 'scheduled',
        debtAccountId: 'debt-scheduled',
        currency: 'COP',
        amountMinor: 20000,
        firstDueMonth: month,
        dueDay: 15,
      ),
      DebtCommitment(
        id: 'skipped',
        debtAccountId: 'debt-skipped',
        currency: 'COP',
        amountMinor: 30000,
        firstDueMonth: month,
        dueDay: 10,
        skippedMonths: {month},
      ),
      DebtCommitment(
        id: 'paused',
        debtAccountId: 'debt-paused',
        currency: 'COP',
        amountMinor: 40000,
        firstDueMonth: month,
        dueDay: 20,
        pausedFromMonth: month,
      ),
    ];
    await tester.pumpWidget(subject(commitments: commitments));
    await tester.pumpAndSettle();

    expect(find.text('1 pagos planeados · 1 pendientes'), findsOneWidget);
    final plannedLine = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data ?? '').startsWith('Previsto para este mes'),
      ),
    );
    expect(plannedLine.data, contains('20.000'));
    expect(plannedLine.data, isNot(contains('90.000')));
    expect(find.byKey(ValueKey('debt_commitment_occurrence_scheduled_$month')), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('debt_commitment_occurrence_skipped_$month')), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('debt_commitment_occurrence_paused_$month')), findsOneWidget);
  });
}
