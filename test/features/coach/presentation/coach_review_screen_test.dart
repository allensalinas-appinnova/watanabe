import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/utils/currency_formatter.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/coach/domain/entities/coach_models.dart';
import 'package:personal_finance/features/coach/presentation/screens/coach_review_screen.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';

import 'coach_test_support.dart';

void main() {
  setUpAll(registerCoachFallbacks);

  for (final cached in [false, true]) {
    testWidgets(
      'no-movements retry revalidates ${cached ? 'cached' : 'new activity'} even without a report signal',
      (tester) async {
        final repo = repositoryFor();
        var changed = false;
        when(
          () => repo.loadReport(
            coachUid,
            startAt: any(named: 'startAt'),
            endAtExclusive: any(named: 'endAtExclusive'),
          ),
        ).thenAnswer(
          (call) async => Right(
            CoachPeriodReport(
              startAt: call.namedArguments[#startAt] as DateTime,
              endAtExclusive: call.namedArguments[#endAtExclusive] as DateTime,
              operations: changed && !cached
                  ? [operation('Server movement', OperationType.expense, 100)]
                  : [],
              freshness: changed && cached ? CoachFreshness.cached : CoachFreshness.fresh,
            ),
          ),
        );
        when(
          () => repo.complete(
            coachUid,
            periodKey: '2026-10-22',
            kind: CoachReviewKind.daily,
            noMovements: true,
          ),
        ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
        await pumpCoach(tester, const CoachReviewScreen(kind: CoachReviewKind.daily), repo);
        await tapCoach(tester, find.byKey(const ValueKey('coach_no_movements')));
        verify(
          () => repo.complete(
            coachUid,
            periodKey: '2026-10-22',
            kind: CoachReviewKind.daily,
            noMovements: true,
          ),
        ).called(1);
        changed = true;
        await tapCoach(tester, find.text(strings(tester).retry));
        expect(find.text(strings(tester).coachNoMovementsUnavailable), findsOneWidget);
        expect(find.byKey(const ValueKey('coach_reviewed')), findsNothing);
        verifyNever(
          () => repo.complete(
            coachUid,
            periodKey: '2026-10-22',
            kind: CoachReviewKind.daily,
            noMovements: true,
          ),
        );
      },
    );
  }

  for (final status in OperationStatus.values) {
    testWidgets('no-movements retry cannot declare empty after ${status.name} activity arrives', (
      tester,
    ) async {
      final repo = repositoryFor();
      final changes = StreamController<void>.broadcast();
      addTearDown(changes.close);
      var operations = <FinancialOperation>[];
      when(
        () => repo.watchReportChanges(
          coachUid,
          startAt: any(named: 'startAt'),
          endAtExclusive: any(named: 'endAtExclusive'),
        ),
      ).thenAnswer((_) => changes.stream);
      when(
        () => repo.loadReport(
          coachUid,
          startAt: any(named: 'startAt'),
          endAtExclusive: any(named: 'endAtExclusive'),
        ),
      ).thenAnswer(
        (call) async => Right(
          CoachPeriodReport(
            startAt: call.namedArguments[#startAt] as DateTime,
            endAtExclusive: call.namedArguments[#endAtExclusive] as DateTime,
            operations: operations,
            freshness: CoachFreshness.fresh,
          ),
        ),
      );
      when(
        () => repo.complete(
          coachUid,
          periodKey: '2026-10-22',
          kind: CoachReviewKind.daily,
          noMovements: true,
        ),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
      await pumpCoach(tester, const CoachReviewScreen(kind: CoachReviewKind.daily), repo);
      await tapCoach(tester, find.byKey(const ValueKey('coach_no_movements')));
      verify(
        () => repo.complete(
          coachUid,
          periodKey: '2026-10-22',
          kind: CoachReviewKind.daily,
          noMovements: true,
        ),
      ).called(1);
      operations = [operation('New movement', OperationType.expense, 200, status: status)];
      changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('New movement'), findsOneWidget);
      expect(find.byKey(const ValueKey('coach_no_movements')), findsNothing);
      final retry = find.text(strings(tester).retry);
      if (retry.evaluate().isNotEmpty) await tapCoach(tester, retry);
      verifyNever(
        () => repo.complete(
          coachUid,
          periodKey: '2026-10-22',
          kind: CoachReviewKind.daily,
          noMovements: true,
        ),
      );
    });
  }

  testWidgets('historical completion document updates outside rolling completion window', (
    tester,
  ) async {
    final repo = repositoryFor();
    final completions = StreamController<CoachCompletion?>.broadcast();
    addTearDown(completions.close);
    when(
      () => repo.watchCompletion(coachUid, kind: CoachReviewKind.daily, periodKey: '2026-08-01'),
    ).thenAnswer((_) async* {
      yield null;
      yield* completions.stream;
    });
    await pumpCoach(
      tester,
      const CoachReviewScreen(kind: CoachReviewKind.daily, periodKey: '2026-08-01'),
      repo,
    );
    expect(find.byKey(const ValueKey('coach_reviewed')), findsNothing);
    completions.add(
      const CoachCompletion(kind: CoachReviewKind.daily, periodKey: '2026-08-01', pending: true),
    );
    await tester.pumpAndSettle();
    final l10n = strings(tester);
    expect(find.text(l10n.coachSavePending), findsOneWidget);
    completions.add(const CoachCompletion(kind: CoachReviewKind.daily, periodKey: '2026-08-01'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.coachSavePending), findsNothing);
    expect(find.text(l10n.coachReviewed), findsOneWidget);
    verify(
      () => repo.watchCompletion(coachUid, kind: CoachReviewKind.daily, periodKey: '2026-08-01'),
    ).called(1);
  });

  for (final changeUser in [false, true]) {
    for (final oldFails in [false, true]) {
      testWidgets(
        'old ${oldFails ? 'failure' : 'success'} cannot affect new save after ${changeUser ? 'user' : 'period'} switch',
        (tester) async {
          final repo = repositoryFor();
          final oldResult = Completer<Either<Failure, CoachWriteState>>();
          final newResult = Completer<Either<Failure, CoachWriteState>>();
          final period = ValueNotifier('2026-10-20');
          final sessions = StreamController<AuthUser?>.broadcast();
          addTearDown(period.dispose);
          addTearDown(sessions.close);
          when(
            () => repo.complete(
              coachUid,
              periodKey: '2026-10-20',
              kind: CoachReviewKind.daily,
              noMovements: false,
            ),
          ).thenAnswer((_) => oldResult.future);
          final newUid = changeUser ? 'second-user' : coachUid;
          final newPeriod = changeUser ? '2026-10-20' : '2026-10-21';
          when(
            () => repo.complete(
              newUid,
              periodKey: newPeriod,
              kind: CoachReviewKind.daily,
              noMovements: false,
            ),
          ).thenAnswer((_) => newResult.future);
          await pumpCoach(
            tester,
            ValueListenableBuilder<String>(
              valueListenable: period,
              builder: (context, key, child) =>
                  CoachReviewScreen(kind: CoachReviewKind.daily, periodKey: key),
            ),
            repo,
            sessionStream: (() async* {
              yield const AuthUser(id: coachUid, isAnonymous: true);
              yield* sessions.stream;
            })(),
          );
          final complete = find.byKey(const ValueKey('coach_complete'));
          await tester.ensureVisible(complete);
          await tester.tap(complete);
          await tester.pump();
          if (changeUser) {
            sessions.add(const AuthUser(id: 'second-user', isAnonymous: true));
          } else {
            period.value = newPeriod;
          }
          for (var frame = 0; frame < 5; frame++) {
            await tester.pump();
          }
          expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
          await tester.ensureVisible(complete);
          await tester.tap(complete);
          await tester.pump();
          oldResult.complete(
            oldFails
                ? const Left(NetworkFailure('old command failed'))
                : const Right(CoachWriteState.confirmed),
          );
          await tester.pump();
          expect(find.byKey(const ValueKey('coach_reviewed')), findsNothing);
          expect(find.text(strings(tester).coachSaveFailed), findsNothing);
          expect(tester.widget<FilledButton>(complete).onPressed, isNull);
          newResult.complete(const Right(CoachWriteState.confirmed));
          await tester.pumpAndSettle();
          expect(find.text(strings(tester).coachReviewed), findsOneWidget);
          verify(
            () => repo.complete(
              newUid,
              periodKey: newPeriod,
              kind: CoachReviewKind.daily,
              noMovements: false,
            ),
          ).called(1);
        },
      );
    }
  }

  testWidgets('late server rejection clears locally pending reviewed state and allows retry', (
    tester,
  ) async {
    final repo = repositoryFor();
    final failures = StreamController<CoachWriteFailure>.broadcast();
    addTearDown(failures.close);
    when(() => repo.watchWriteFailures(coachUid)).thenAnswer((_) => failures.stream);
    when(
      () => repo.complete(
        coachUid,
        periodKey: '2026-10-22',
        kind: CoachReviewKind.daily,
        noMovements: false,
      ),
    ).thenAnswer((_) async => const Right(CoachWriteState.pending));
    await pumpCoach(tester, const CoachReviewScreen(kind: CoachReviewKind.daily), repo);
    await tapCoach(tester, find.byKey(const ValueKey('coach_complete')));
    final l10n = strings(tester);
    expect(find.text(l10n.coachSavePending), findsOneWidget);
    for (final command in ['preferences', 'daily:2026-10-21', 'weekly:2026-10-22']) {
      failures.add(
        CoachWriteFailure(failure: const NetworkFailure('unrelated command'), commandKey: command),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.coachSavePending), findsOneWidget);
      expect(find.text(l10n.coachSaveFailed), findsNothing);
    }
    failures.add(
      const CoachWriteFailure(
        failure: NetworkFailure('server rejected write'),
        commandKey: 'daily:2026-10-22',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coach_reviewed')), findsNothing);
    expect(find.text(l10n.coachSavePending), findsNothing);
    expect(find.text(l10n.coachSaveFailed), findsOneWidget);
    when(
      () => repo.complete(
        coachUid,
        periodKey: '2026-10-22',
        kind: CoachReviewKind.daily,
        noMovements: false,
      ),
    ).thenAnswer((_) async => const Right(CoachWriteState.confirmed));
    await tapCoach(tester, find.text(l10n.retry));
    expect(find.text(l10n.coachSaveFailed), findsNothing);
    expect(find.text(l10n.coachReviewed), findsOneWidget);
    verify(
      () => repo.complete(
        coachUid,
        periodKey: '2026-10-22',
        kind: CoachReviewKind.daily,
        noMovements: false,
      ),
    ).called(2);
  });

  testWidgets('daily summary shows confirmed currency totals without weekly category ranking', (
    tester,
  ) async {
    final repo = repositoryFor(
      operations: [
        operation('salary', OperationType.income, 123456),
        operation('food', OperationType.expense, 23456, categoryId: 'food'),
        operation('euro income', OperationType.income, 9000, currency: 'EUR'),
        operation('euro expense', OperationType.expense, 2000, currency: 'EUR'),
        operation('transfer', OperationType.transfer, 999999),
        operation('pending', OperationType.income, 77777, status: OperationStatus.pending),
      ],
    );
    await pumpCoach(tester, const CoachReviewScreen(kind: CoachReviewKind.daily), repo);
    final netLabels = find.text(strings(tester).activityTotalsNet);
    expect(netLabels, findsNWidgets(2));
    expect(find.text('USD 1,000.00'), findsOneWidget);
    expect(find.text('EUR 70.00'), findsOneWidget);
    expect(find.text(strings(tester).coachTopCategories), findsNothing);
  });

  testWidgets('weekly ranking shows only top three confirmed spending categories per currency', (
    tester,
  ) async {
    final repo = repositoryFor(
      operations: [
        operation('a', OperationType.expense, 4000, categoryId: 'a'),
        operation('b', OperationType.expense, 3000, categoryId: 'b'),
        operation('c', OperationType.expense, 2000, categoryId: 'c'),
        operation('d', OperationType.expense, 1000, categoryId: 'd'),
        operation(
          'pending',
          OperationType.expense,
          90000,
          categoryId: 'pending',
          status: OperationStatus.pending,
        ),
        operation('eur', OperationType.expense, 5000, categoryId: 'eur', currency: 'EUR'),
      ],
    );
    await pumpCoach(tester, const CoachReviewScreen(kind: CoachReviewKind.weekly), repo);
    await tester.scrollUntilVisible(find.text(strings(tester).coachTopCategories), 250);
    expect(find.text('USD 40.00'), findsOneWidget);
    expect(find.text('USD 30.00'), findsOneWidget);
    expect(find.text('USD 20.00'), findsOneWidget);
    expect(find.text('USD 10.00'), findsNothing);
    expect(find.text(strings(tester).category), findsNWidgets(4));
  });

  testWidgets('report read failure retries the same requested interval', (tester) async {
    final repo = repositoryFor();
    var attempts = 0;
    when(
      () => repo.loadReport(
        any(),
        startAt: any(named: 'startAt'),
        endAtExclusive: any(named: 'endAtExclusive'),
      ),
    ).thenAnswer(
      (call) async => ++attempts == 1
          ? const Left(NetworkFailure('offline'))
          : Right(
              CoachPeriodReport(
                startAt: call.namedArguments[#startAt] as DateTime,
                endAtExclusive: call.namedArguments[#endAtExclusive] as DateTime,
                operations: [],
                freshness: CoachFreshness.fresh,
              ),
            ),
    );
    await pumpCoach(
      tester,
      const CoachReviewScreen(kind: CoachReviewKind.daily, periodKey: '2026-10-20'),
      repo,
    );
    final l10n = strings(tester);
    expect(find.text(l10n.coachReadFailure), findsOneWidget);
    expect(find.byKey(const ValueKey('coach_complete')), findsNothing);
    await tapCoach(tester, find.text(l10n.retry));
    expect(find.text(l10n.coachReadFailure), findsNothing);
    expect(find.byKey(const ValueKey('coach_complete')), findsOneWidget);
    verify(
      () => repo.loadReport(
        coachUid,
        startAt: DateTime.utc(2026, 10, 20, 5),
        endAtExclusive: DateTime.utc(2026, 10, 21, 5),
      ),
    ).called(2);
  });

  testWidgets('completion disables both actions while awaiting repository', (tester) async {
    final repo = repositoryFor();
    final result = Completer<Either<Failure, CoachWriteState>>();
    when(
      () => repo.complete(
        coachUid,
        periodKey: '2026-10-22',
        kind: CoachReviewKind.daily,
        noMovements: false,
      ),
    ).thenAnswer((_) => result.future);
    await pumpCoach(tester, const CoachReviewScreen(kind: CoachReviewKind.daily), repo);
    final complete = find.byKey(const ValueKey('coach_complete'));
    await tester.ensureVisible(complete);
    await tester.tap(complete);
    await tester.pump();
    expect(tester.widget<FilledButton>(complete).onPressed, isNull);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const ValueKey('coach_no_movements'))).onPressed,
      isNull,
    );
    result.complete(const Right(CoachWriteState.confirmed));
    await tester.pumpAndSettle();
    expect(find.text(strings(tester).coachReviewed), findsOneWidget);
    verify(
      () => repo.complete(
        coachUid,
        periodKey: '2026-10-22',
        kind: CoachReviewKind.daily,
        noMovements: false,
      ),
    ).called(1);
  });

  testWidgets('default daily retry keeps attempted period if rebuild happens after midnight', (
    tester,
  ) async {
    final repo = repositoryFor();
    final clock = TestCoachClock();
    final result = Completer<Either<Failure, CoachWriteState>>();
    when(
      () => repo.complete(
        coachUid,
        periodKey: '2026-10-22',
        kind: CoachReviewKind.daily,
        noMovements: true,
      ),
    ).thenAnswer((_) => result.future);
    await pumpCoach(
      tester,
      const CoachReviewScreen(kind: CoachReviewKind.daily),
      repo,
      clock: clock,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('coach_no_movements')));
    await tester.tap(find.byKey(const ValueKey('coach_no_movements')));
    await tester.pump();
    clock.instant = DateTime.utc(2026, 10, 23, 18);
    result.complete(const Left(NetworkFailure('offline')));
    await tester.pumpAndSettle();
    await tapCoach(tester, find.text(strings(tester).retry));
    verify(
      () => repo.complete(
        coachUid,
        periodKey: '2026-10-22',
        kind: CoachReviewKind.daily,
        noMovements: true,
      ),
    ).called(2);
    verifyNever(
      () => repo.complete(
        coachUid,
        periodKey: '2026-10-23',
        kind: any(named: 'kind'),
        noMovements: any(named: 'noMovements'),
      ),
    );
  });

  testWidgets('weekly totals use confirmed amounts per currency and exclude transfers', (
    tester,
  ) async {
    final repo = repositoryFor(
      operations: [
        operation('salary', OperationType.income, 123456),
        operation('food', OperationType.expense, 23456),
        operation('euro income', OperationType.income, 9000, currency: 'EUR'),
        operation('euro expense', OperationType.expense, 2000, currency: 'EUR'),
        operation('transfer', OperationType.transfer, 999999),
        operation(
          'pending purchase',
          OperationType.expense,
          77777,
          status: OperationStatus.pending,
        ),
        operation('rejected income', OperationType.income, 88888, status: OperationStatus.rejected),
      ],
    );
    await pumpCoach(tester, const CoachReviewScreen(kind: CoachReviewKind.weekly), repo);
    final l10n = strings(tester);
    expect(find.text(l10n.coachConfirmedCount), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    for (final pair in [
      (123456, 'USD'),
      (23456, 'USD'),
      (100000, 'USD'),
      (9000, 'EUR'),
      (2000, 'EUR'),
      (7000, 'EUR'),
    ]) {
      expect(
        find.text(CurrencyFormatter.formatMinor(pair.$1, pair.$2, locale: 'en')),
        findsOneWidget,
      );
    }
    expect(find.text(CurrencyFormatter.formatMinor(999999, 'USD', locale: 'en')), findsNothing);
    await tester.ensureVisible(find.text('pending purchase'));
    expect(find.text('pending purchase'), findsOneWidget);
    expect(find.text('rejected income'), findsOneWidget);
    expect(find.text(l10n.coachPendingCount), findsNWidgets(2));
    expect(find.text(l10n.coachRejectedCount), findsNWidgets(2));
    expect(find.byKey(const ValueKey('coach_no_movements')), findsNothing);
    verify(
      () => repo.loadReport(
        coachUid,
        startAt: DateTime.utc(2026, 10, 12, 5),
        endAtExclusive: DateTime.utc(2026, 10, 19, 5),
      ),
    ).called(1);
  });

  for (final status in OperationStatus.values) {
    testWidgets('known ${status.name} operation prevents no-movements declaration', (tester) async {
      final repo = repositoryFor(
        operations: [operation('known movement', OperationType.expense, 300, status: status)],
      );
      await pumpCoach(tester, const CoachReviewScreen(kind: CoachReviewKind.daily), repo);
      expect(find.text('known movement'), findsOneWidget);
      expect(find.byKey(const ValueKey('coach_no_movements')), findsNothing);
    });
  }

  testWidgets('cached empty report shows stale notice and prevents no movements', (tester) async {
    await pumpCoach(
      tester,
      const CoachReviewScreen(kind: CoachReviewKind.daily),
      repositoryFor(freshness: CoachFreshness.cached),
    );
    expect(find.text(strings(tester).coachCached), findsOneWidget);
    expect(find.byKey(const ValueKey('coach_no_movements')), findsNothing);
  });

  testWidgets('failed no-movements completion retries original period after clock advances', (
    tester,
  ) async {
    final repo = repositoryFor();
    final clock = TestCoachClock();
    var attempts = 0;
    when(
      () => repo.complete(
        coachUid,
        periodKey: '2026-10-22',
        kind: CoachReviewKind.daily,
        noMovements: true,
      ),
    ).thenAnswer(
      (_) async => ++attempts == 1
          ? const Left(NetworkFailure('offline'))
          : const Right(CoachWriteState.confirmed),
    );
    await pumpCoach(
      tester,
      const CoachReviewScreen(kind: CoachReviewKind.daily, periodKey: '2026-10-22'),
      repo,
      clock: clock,
    );
    await tapCoach(tester, find.byKey(const ValueKey('coach_no_movements')));
    final l10n = strings(tester);
    expect(find.text(l10n.coachSaveFailed), findsOneWidget);
    expect(find.byKey(const ValueKey('coach_reviewed')), findsNothing);
    clock.instant = DateTime.utc(2026, 10, 23, 18);
    await tapCoach(tester, find.text(l10n.retry));
    expect(find.text(l10n.coachSaveFailed), findsNothing);
    expect(find.text(l10n.coachReviewed), findsOneWidget);
    verify(
      () => repo.complete(
        coachUid,
        periodKey: '2026-10-22',
        kind: CoachReviewKind.daily,
        noMovements: true,
      ),
    ).called(2);
    verifyNever(
      () => repo.complete(
        coachUid,
        periodKey: '2026-10-23',
        kind: any(named: 'kind'),
        noMovements: any(named: 'noMovements'),
      ),
    );
  });

  for (final state in CoachWriteState.values) {
    testWidgets('daily successful ${state.name} completion reports synchronization state', (
      tester,
    ) async {
      final repo = repositoryFor();
      when(
        () => repo.complete(
          coachUid,
          periodKey: '2026-10-22',
          kind: CoachReviewKind.daily,
          noMovements: false,
        ),
      ).thenAnswer((_) async => Right(state));
      await pumpCoach(tester, const CoachReviewScreen(kind: CoachReviewKind.daily), repo);
      await tapCoach(tester, find.byKey(const ValueKey('coach_complete')));
      final l10n = strings(tester);
      expect(
        find.text(state == CoachWriteState.pending ? l10n.coachSavePending : l10n.coachReviewed),
        findsOneWidget,
      );
      verify(
        () => repo.complete(
          coachUid,
          periodKey: '2026-10-22',
          kind: CoachReviewKind.daily,
          noMovements: false,
        ),
      ).called(1);
    });
  }

  testWidgets('empty weekly review completes previous Monday period without noMovements', (
    tester,
  ) async {
    final repo = repositoryFor();
    await pumpCoach(tester, const CoachReviewScreen(kind: CoachReviewKind.weekly), repo);
    expect(find.text(strings(tester).coachNoRecords), findsOneWidget);
    expect(find.byKey(const ValueKey('coach_no_movements')), findsNothing);
    await tapCoach(tester, find.byKey(const ValueKey('coach_complete')));
    expect(find.text(strings(tester).coachReviewed), findsOneWidget);
    verify(
      () => repo.complete(
        coachUid,
        periodKey: '2026-10-12',
        kind: CoachReviewKind.weekly,
        noMovements: false,
      ),
    ).called(1);
  });

  for (final language in ['es', 'en', 'pt']) {
    for (final kind in CoachReviewKind.values) {
      testWidgets('${kind.name} review fits compact enlarged text in $language', (tester) async {
        await pumpCoach(
          tester,
          CoachReviewScreen(kind: kind),
          repositoryFor(
            operations: [
              operation('Market', OperationType.expense, 123456),
              operation('Pending', OperationType.expense, 98765, status: OperationStatus.pending),
            ],
          ),
          language: language,
          compact: true,
        );
        await tester.ensureVisible(find.byKey(const ValueKey('coach_complete')));
        await tester.pumpAndSettle();
        expect(find.text(strings(tester).coachPendingCount), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
