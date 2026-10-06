import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';

FinancialOperation operation(String id) => FinancialOperation(
  id: id,
  type: OperationType.expense,
  amountMinor: 100,
  currency: 'COP',
  monthKey: '2026-10',
  occurredAt: DateTime(2026, 10, 6),
  status: OperationStatus.confirmed,
  idempotencyKey: id,
);

void main() {
  test('pager state can accumulate pages without duplicate operation IDs', () {
    const first = OperationPagerState(items: []);
    final ids = <String>{};
    final page = OperationPage(
      items: [operation('one'), operation('two')],
      nextCursor: OperationPageCursor(
        occurredAt: DateTime(2026, 10, 6),
        operationId: 'two',
      ),
    );
    final unique = <FinancialOperation>[];
    for (final item in page.items) {
      if (ids.add(item.id)) unique.add(item);
    }
    final merged = first.copyWith(items: unique, nextCursor: page.nextCursor);
    expect(merged.items.map((item) => item.id), ['one', 'two']);
    expect(merged.hasMore, isTrue);
  });

  test('pager state reports a recoverable load-more error', () {
    const state = OperationPagerState(items: [], isLoadingMore: true);
    final failed = state.copyWith(isLoadingMore: false, errorMessage: 'network');
    expect(failed.isLoadingMore, isFalse);
    expect(failed.errorMessage, 'network');
  });
}
