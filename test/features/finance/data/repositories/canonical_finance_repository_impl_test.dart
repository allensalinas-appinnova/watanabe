import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/data/datasources/canonical_finance_remote_data_source.dart';
import 'package:personal_finance/features/finance/data/repositories/canonical_finance_repository_impl.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';

void main() {
  test('does not return rejected operations and preserves the page cursor', () async {
    final cursor = OperationPageCursor(
      occurredAt: DateTime(2026, 10, 20),
      operationId: 'last-operation',
    );
    final repository = CanonicalFinanceRepositoryImpl(
      remoteDataSource: _OperationsDataSource(
        RemoteOperationPage(
          records: [
            _operationRecord(id: 'visible', status: 'confirmed'),
            _operationRecord(id: 'deleted', status: 'rejected'),
          ],
          nextCursor: cursor,
        ),
      ),
    );

    final result = await repository.fetchOperationsPage('user');
    final page = result.match(
      (failure) => fail('Unexpected repository failure: ${failure.message}'),
      (page) => page,
    );

    expect(page.items.map((operation) => operation.id), ['visible']);
    expect(page.nextCursor, same(cursor));
  });
}

Map<String, dynamic> _operationRecord({required String id, required String status}) => {
  'id': id,
  'type': 'expense',
  'amountMinor': 1200,
  'currency': 'COP',
  'monthKey': '2026-10',
  'occurredAt': DateTime(2026, 10, 20),
  'status': status,
  'idempotencyKey': id,
  'description': id,
};

class _OperationsDataSource implements CanonicalFinanceRemoteDataSource {
  _OperationsDataSource(this.page);

  final RemoteOperationPage page;

  @override
  Future<RemoteOperationPage> fetchOperationsPage(
    String userId, {
    OperationPageCursor? cursor,
    String? monthKey,
    String? currency,
    OperationType? type,
    String? accountId,
    List<String>? accountIds,
    DateTime? startAt,
    DateTime? endAtExclusive,
    int pageSize = 100,
  }) async => page;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
