import 'financial_operation.dart';

/// Stable cursor for loading the next page of operations.
class OperationPageCursor {
  const OperationPageCursor({required this.occurredAt, required this.operationId});

  final DateTime occurredAt;
  final String operationId;
}

class OperationPage {
  const OperationPage({required this.items, this.nextCursor});

  final List<FinancialOperation> items;
  final OperationPageCursor? nextCursor;

  bool get hasMore => nextCursor != null;
}
