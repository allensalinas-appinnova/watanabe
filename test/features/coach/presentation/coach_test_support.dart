import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/coach/domain/entities/coach_models.dart';
import 'package:personal_finance/features/coach/domain/repositories/coach_repository.dart';
import 'package:personal_finance/features/coach/domain/usecases/coach_routine.dart';
import 'package:personal_finance/features/coach/presentation/providers/coach_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/planning_agenda_entry.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class MockCoachRepository extends Mock implements CoachRepository {}

class TestCoachClock implements CoachClock {
  DateTime instant = DateTime.utc(2026, 10, 22, 18);
  @override
  DateTime now() => instant;
}

const coachUid = 'coach-user';

MockCoachRepository repositoryFor({
  CoachPreferences preferences = const CoachPreferences(),
  List<CoachCompletion> completions = const [],
  List<FinancialOperation> operations = const [],
  CoachFreshness freshness = CoachFreshness.fresh,
}) {
  final repository = MockCoachRepository();
  when(() => repository.watchWriteFailures(any())).thenAnswer((_) => const Stream.empty());
  when(
    () => repository.watchCompletion(
      any(),
      kind: any(named: 'kind'),
      periodKey: any(named: 'periodKey'),
    ),
  ).thenAnswer(
    (call) => Stream.value(
      completions
          .where(
            (c) =>
                c.kind == call.namedArguments[#kind] &&
                c.periodKey == call.namedArguments[#periodKey],
          )
          .firstOrNull,
    ),
  );
  when(
    () => repository.watchReportChanges(
      any(),
      startAt: any(named: 'startAt'),
      endAtExclusive: any(named: 'endAtExclusive'),
    ),
  ).thenAnswer((_) => const Stream.empty());
  when(() => repository.watchPreferences(any())).thenAnswer((_) => Stream.value(preferences));
  when(() => repository.watchRoutinePreferences(any())).thenAnswer(
    (_) => Stream.value(CoachRoutinePreferences.fromProfile(null, legacy: preferences)),
  );
  when(() => repository.watchUnallocatedPayments(any())).thenAnswer(
    (_) => Stream.value(
      CoachUnallocatedPayments(
        operations: operations
            .where((value) => value.type == OperationType.unallocatedDebtPayment)
            .toList(),
        freshness: freshness,
      ),
    ),
  );
  when(() => repository.watchBudgetProgress(any(), any())).thenAnswer(
    (_) => Stream.value(const <CoachBudgetProgress>[]),
  );
  when(
    () => repository.watchCompletions(any(), since: any(named: 'since')),
  ).thenAnswer((_) => Stream.value(completions));
  when(
    () => repository.loadReport(
      any(),
      startAt: any(named: 'startAt'),
      endAtExclusive: any(named: 'endAtExclusive'),
    ),
  ).thenAnswer(
    (call) async => Right(
      CoachPeriodReport(
        startAt: call.namedArguments[#startAt] as DateTime,
        endAtExclusive: call.namedArguments[#endAtExclusive] as DateTime,
        operations: operations,
        freshness: freshness,
      ),
    ),
  );
  when(
    () => repository.complete(
      any(),
      periodKey: any(named: 'periodKey'),
      kind: any(named: 'kind'),
      noMovements: any(named: 'noMovements'),
    ),
  ).thenAnswer((_) async => const Right(CoachWriteState.confirmed));
  when(
    () => repository.savePreferences(any(), any()),
  ).thenAnswer((_) async => const Right(CoachWriteState.confirmed));
  when(
    () => repository.saveRoutinePreferences(any(), any()),
  ).thenAnswer((_) async => const Right(CoachWriteState.confirmed));
  return repository;
}

void registerCoachFallbacks() {
  registerFallbackValue(DateTime.utc(2026));
  registerFallbackValue(const CoachPreferences());
  registerFallbackValue(const CoachRoutinePreferences());
  registerFallbackValue(CoachReviewKind.daily);
}

Future<void> pumpCoach(
  WidgetTester tester,
  Widget screen,
  MockCoachRepository repository, {
  String language = 'en',
  TestCoachClock? clock,
  bool compact = false,
  bool settle = true,
  Stream<UserProfile?>? profileStream,
  Stream<List<CoachBudgetProgress>>? budgetProgressStream,
  Stream<AuthUser?>? sessionStream,
}) async {
  tester.view.physicalSize = compact ? const Size(360, 800) : const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (compact) {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => sessionStream ?? Stream.value(const AuthUser(id: coachUid, isAnonymous: true)),
        ),
        coachRepositoryProvider.overrideWithValue(repository),
        coachClockProvider.overrideWithValue(clock ?? TestCoachClock()),
        coachNotificationServiceProvider.overrideWithValue(null),
        coachTickProvider.overrideWith((ref) => Stream.value((clock ?? TestCoachClock()).now())),
        canonicalUserProfileProvider.overrideWith(
          (ref, uid) =>
              profileStream ??
              Stream.value(
                UserProfile(
                  id: uid,
                  locale: 'en',
                  countryCode: 'CO',
                  timeZone: 'America/Bogota',
                  defaultCurrency: 'COP',
                  onboardingStatus: 'complete',
                  categoryCatalogVersion: 1,
                ),
              ),
        ),
        coachBudgetProgressProvider.overrideWith(
          (ref, request) => budgetProgressStream ?? Stream.value(const []),
        ),
        canonicalCategoriesProvider.overrideWith((ref, uid) => Stream.value(const [])),
        canonicalAccountsProvider.overrideWith(
          (ref, uid) => Stream.value(const <FinanceAccount>[]),
        ),
        debtCommitmentsProvider.overrideWith((ref, uid) => Stream.value(const [])),
        debtCommitmentPaymentsProvider.overrideWith((ref, uid) => Stream.value(const [])),
        planningAgendaEntriesProvider.overrideWith(
          (ref, request) async => const <PlanningAgendaEntry>[],
        ),
        pendingOperationsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

AppLocalizations strings(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

Future<void> tapCoach(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

FinancialOperation operation(
  String id,
  OperationType type,
  int amount, {
  String currency = 'USD',
  OperationStatus status = OperationStatus.confirmed,
  String? categoryId,
}) => FinancialOperation(
  id: id,
  type: type,
  amountMinor: amount,
  currency: currency,
  monthKey: '2026-10',
  occurredAt: DateTime.utc(2026, 10, 22, 12),
  status: status,
  idempotencyKey: id,
  description: id,
  categoryId: categoryId,
);
