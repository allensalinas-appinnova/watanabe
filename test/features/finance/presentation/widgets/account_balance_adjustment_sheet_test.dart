import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/offline/pending_operation_queue.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/finance/domain/entities/balance_adjustment.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/widgets/account_balance_adjustment_sheet.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _MockRepository extends Mock implements CanonicalFinanceRepository {}

void main() {
  const account = FinanceAccount(
    id: 'cash-account',
    name: 'Efectivo',
    type: 'cash',
    currency: 'COP',
    currentBalanceMinor: 10000,
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required _MockRepository repository,
    required Future<List<PendingOperation>> Function() loadActiveOperations,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
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
          home: Scaffold(
            body: AccountBalanceAdjustmentSheet(
              userId: 'user-1',
              initialAccount: account,
              accounts: const [account],
              repository: repository,
              loadActiveOperations: loadActiveOperations,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('submits a changed target and keeps request id stable after a recoverable failure', (
    tester,
  ) async {
    final repository = _MockRepository();
    final requestIds = <String>[];
    final submittedTargets = <int>[];
    var attempts = 0;
    when(
      () => repository.adjustAccountBalances(
        'user-1',
        requestId: any(named: 'requestId'),
        adjustments: any(named: 'adjustments'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((invocation) async {
      requestIds.add(invocation.namedArguments[#requestId] as String);
      final rows = invocation.namedArguments[#adjustments] as List<BalanceAdjustmentDraft>;
      submittedTargets.add(rows.single.targetBalanceMinor);
      attempts++;
      if (attempts == 1) return const Left(NetworkFailure('temporary'));
      return Right(
        BalanceAdjustmentResult(
          requestId: requestIds.last,
          adjustments: [
            BalanceAdjustmentRecord(
              accountId: account.id,
              currency: account.currency,
              previousBalanceMinor: 10000,
              targetBalanceMinor: rows.single.targetBalanceMinor,
              deltaMinor: rows.single.targetBalanceMinor - 10000,
            ),
          ],
          adjustedAt: DateTime.utc(2026, 10, 22),
        ),
      );
    });
    await pumpSheet(tester, repository: repository, loadActiveOperations: () async => []);

    final target = find.byKey(const ValueKey('balance_adjustment_target_cash-account'));
    await tester.enterText(target, '125');
    await tester.tap(find.text('Guardar ajustes'));
    await tester.pumpAndSettle();

    expect(find.text('125'), findsOneWidget);
    expect(requestIds, hasLength(1));
    await tester.tap(find.text('Guardar ajustes'));
    await tester.pumpAndSettle();

    expect(submittedTargets, [125, 125]);
    expect(requestIds, hasLength(2));
    expect(requestIds.first, requestIds.last);
    verify(
      () => repository.adjustAccountBalances(
        'user-1',
        requestId: any(named: 'requestId'),
        adjustments: any(named: 'adjustments'),
        reason: any(named: 'reason'),
      ),
    ).called(2);
  });

  testWidgets('blocks an adjustment when a local pending transfer touches the account', (
    tester,
  ) async {
    final repository = _MockRepository();
    final now = DateTime.utc(2026, 10, 22);
    final pending = PendingOperation(
      id: 1,
      idempotencyKey: 'local-op-1',
      operationType: 'transfer',
      payload: jsonEncode({
        'ownerUserId': 'user-1',
        'sourceAccountId': account.id,
        'destinationAccountId': 'other-account',
      }),
      status: 'pending',
      retryCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    await pumpSheet(tester, repository: repository, loadActiveOperations: () async => [pending]);

    await tester.enterText(
      find.byKey(const ValueKey('balance_adjustment_target_cash-account')),
      '125',
    );
    await tester.tap(find.text('Guardar ajustes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Resuelve los movimientos pendientes'), findsOneWidget);
    verifyNever(
      () => repository.adjustAccountBalances(
        any(),
        requestId: any(named: 'requestId'),
        adjustments: any(named: 'adjustments'),
        reason: any(named: 'reason'),
      ),
    );
  });
}
