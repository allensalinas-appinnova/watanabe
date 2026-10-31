import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/planning_agenda_entry.dart';
import 'package:personal_finance/features/finance/domain/entities/planning_follow_up.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/domain/repositories/planning_follow_up_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/widgets/planning_follow_up_controls.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _FollowUps implements PlanningFollowUpRepository {
  final commands = <PlanningFollowUpCommand>[];
  bool loseResponse = false;
  @override
  Stream<PlanningFollowUpSnapshot> watch(String userId) =>
      Stream.value(const PlanningFollowUpSnapshot());
  @override
  Future<Either<Failure, PlanningFollowUp>> mutate(
    String uid,
    PlanningFollowUpCommand command,
  ) async {
    commands.add(command);
    if (loseResponse && commands.length == 1) {
      return const Left(NetworkFailure('planning-follow-up-failed'));
    }
    return Right(
      PlanningFollowUp(
        source: command.source,
        state: PlanningFollowUpState.completed,
        version: 1,
        dataGeneration: command.expectedGeneration,
      ),
    );
  }
}

const profile = UserProfile(
  id: 'qa',
  locale: 'es',
  countryCode: 'CO',
  timeZone: 'America/Bogota',
  defaultCurrency: 'COP',
  onboardingStatus: 'complete',
  categoryCatalogVersion: 1,
  dataGeneration: 7,
);
PlanningAgendaEntry item({PlanningEntryKind kind = PlanningEntryKind.expense}) =>
    PlanningAgendaEntry(
      id: 'budget:barber:one',
      kind: kind,
      date: DateTime(2026, 10, 15),
      title: 'QA Barber',
      currency: 'COP',
      plannedMinor: 50000,
      recordedMinor: 25000,
      pendingMinor: 25000,
      monthKey: '2026-10',
      budgetId: 'barber',
      itemId: 'one',
      commitmentId: kind == PlanningEntryKind.debt ? 'loan' : null,
    );
FinancialOperation expense() => FinancialOperation(
  id: 'one',
  type: OperationType.expense,
  amountMinor: 25000,
  currency: 'COP',
  monthKey: '2026-10',
  occurredAt: DateTime(2026, 10, 15),
  status: OperationStatus.confirmed,
  idempotencyKey: 'one',
);

Future<void> _pump(
  WidgetTester tester,
  _FollowUps repository, {
  List<FinancialOperation> records = const [],
  PlanningEntryKind kind = PlanningEntryKind.expense,
  String locale = 'es',
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        planningFollowUpRepositoryProvider.overrideWithValue(repository),
        canonicalUserProfileProvider('qa').overrideWith((ref) => Stream.value(profile)),
        canonicalBudgetItemOperationsProvider((
          userId: 'qa',
          budgetId: 'barber',
          itemId: 'one',
        )).overrideWith((ref) => Stream.value(records)),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => PlanningFollowUpSheet(
                  userId: 'qa',
                  entry: item(kind: kind),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'expense completion requires an associated confirmed record, while debt never offers manual paid status',
    (tester) async {
      await _pump(tester, _FollowUps());
      expect(
        tester.widget<ListTile>(find.byKey(const ValueKey('follow_up_completeExpense'))).onTap,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await _pump(tester, _FollowUps(), kind: PlanningEntryKind.debt);
      expect(find.byKey(const ValueKey('follow_up_completeExpense')), findsNothing);
      expect(find.byKey(const ValueKey('follow_up_dismiss')), findsOneWidget);
    },
  );
  testWidgets('lost response retry retains request identity, generation and content', (
    tester,
  ) async {
    final repository = _FollowUps()..loseResponse = true;
    await _pump(tester, repository, records: [expense()]);
    await tester.tap(find.byKey(const ValueKey('follow_up_completeExpense')));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo guardar el seguimiento. Reintenta con conexión.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(repository.commands, hasLength(2));
    expect(identical(repository.commands[0], repository.commands[1]), isTrue);
    expect(repository.commands.first.expectedGeneration, 7);
    expect(repository.commands.first.expectedVersion, 0);
    expect(find.byKey(const ValueKey('follow_up_completeExpense')), findsNothing);
    expect(find.text('Seguimiento actualizado'), findsOneWidget);
  });
  for (final locale in ['es', 'en', 'pt']) {
    testWidgets(
      'follow-up controls remain scrollable and readable in $locale with large text and dark theme',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(tester, _FollowUps(), records: [expense()], locale: locale, scale: 2);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('follow_up_edit')),
          220,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.byKey(const ValueKey('follow_up_edit')).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
