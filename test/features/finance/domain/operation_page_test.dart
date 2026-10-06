import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';

void main() {
  test('page exposes whether a cursor is available', () {
    const empty = OperationPage(items: []);
    expect(empty.hasMore, isFalse);

    final page = OperationPage(
      items: const [],
      nextCursor: OperationPageCursor(
        occurredAt: DateTime(2026, 10, 6),
        operationId: 'operation-1',
      ),
    );
    expect(page.hasMore, isTrue);
  });
}
