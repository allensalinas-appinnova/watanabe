import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/offline/pending_operation_queue.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';

class _MockFinanceRepository extends Mock implements CanonicalFinanceRepository {}

void main() {
  test('loads all cursor pages using the selected activity filters', () async {
    final repository = _MockFinanceRepository();
    final calls = <({OperationPageCursor? cursor, OperationType? type, List<String>? accounts})>[];
    final nextCursor = OperationPageCursor(
      occurredAt: DateTime(2026, 10, 10),
      operationId: 'page-one-last',
    );
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
    ).thenAnswer((invocation) async {
      final cursor = invocation.namedArguments[#cursor] as OperationPageCursor?;
      final type = invocation.namedArguments[#type] as OperationType?;
      final accounts = invocation.namedArguments[#accountIds] as List<String>?;
      calls.add((cursor: cursor, type: type, accounts: accounts));
      final operation = FinancialOperation(
        id: cursor == null ? 'expense-one' : 'expense-two',
        type: OperationType.expense,
        amountMinor: cursor == null ? 500 : 250,
        currency: 'COP',
        monthKey: '2026-10',
        occurredAt: cursor == null ? DateTime(2026, 10, 12) : DateTime(2026, 10, 10),
        status: OperationStatus.confirmed,
        idempotencyKey: cursor == null ? 'expense-one-key' : 'expense-two-key',
      );
      return Right(
        OperationPage(items: [operation], nextCursor: cursor == null ? nextCursor : null),
      );
    });

    final container = ProviderContainer(
      overrides: [
        canonicalFinanceRepositoryProvider.overrideWithValue(repository),
        pendingOperationsProvider.overrideWith((ref) => Stream.value(const <PendingOperation>[])),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(activityQueryFiltersProvider.notifier)
        .apply(
          const ActivityQueryFilters(monthKey: '2026-10', accountIds: ['account-1']),
        );
    container.read(activityTypeFilterProvider.notifier).select(OperationType.expense);

    final report = await container.read(activityReportProvider('user-1').future);

    expect(calls, hasLength(2));
    expect(calls.first.cursor, isNull);
    expect(calls.last.cursor, same(nextCursor));
    expect(calls.every((call) => call.type == OperationType.expense), isTrue);
    expect(calls.every((call) => call.accounts!.single == 'account-1'), isTrue);
    expect(report.operations, hasLength(2));
    expect(report.totalsByCurrency['COP']!.expenseMinor, 750);
  });
}
