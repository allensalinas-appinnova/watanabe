import '../../domain/entities/financial_operation.dart';

class PickerUsageOrder<T> {
  const PickerUsageOrder({required this.ordered, required this.frequent});

  final List<T> ordered;
  final List<T> frequent;
}

/// Ranks options using a bounded, newest-first list of synchronized operations.
PickerUsageOrder<T> orderPickerOptionsByUsage<T>({
  required List<T> options,
  required List<FinancialOperation> recentOperations,
  required String Function(T) idOf,
  required Iterable<String> Function(FinancialOperation) usageIdsOf,
  required int Function(T, T) compareAlphabetically,
  int maximumFrequent = 5,
  int minimumUses = 2,
}) {
  final usageCounts = <String, int>{};
  final mostRecentIndex = <String, int>{};
  final eligibleIds = options.map(idOf).toSet();

  for (var index = 0; index < recentOperations.length; index++) {
    final operation = recentOperations[index];
    if (operation.status != OperationStatus.confirmed) continue;

    // One operation can refer to an account in more than one field. Count it
    // only once per option, while still counting both sides of a transfer.
    for (final id in usageIdsOf(operation).toSet()) {
      if (!eligibleIds.contains(id)) continue;
      usageCounts.update(id, (count) => count + 1, ifAbsent: () => 1);
      mostRecentIndex.putIfAbsent(id, () => index);
    }
  }

  final frequentCandidates = options
      .where((option) => (usageCounts[idOf(option)] ?? 0) >= minimumUses)
      .toList(growable: false);
  final frequent = [...frequentCandidates]
    ..sort((left, right) {
      final leftId = idOf(left);
      final rightId = idOf(right);
      final countDifference = (usageCounts[rightId] ?? 0).compareTo(usageCounts[leftId] ?? 0);
      if (countDifference != 0) return countDifference;
      final recencyDifference = (mostRecentIndex[leftId] ?? 1 << 30).compareTo(
        mostRecentIndex[rightId] ?? 1 << 30,
      );
      return recencyDifference != 0 ? recencyDifference : compareAlphabetically(left, right);
    });
  final visibleFrequent = frequent.take(maximumFrequent).toList(growable: false);
  final frequentIds = visibleFrequent.map(idOf).toSet();
  final otherOptions = options.where((option) => !frequentIds.contains(idOf(option))).toList()
    ..sort(compareAlphabetically);
  return PickerUsageOrder(
    ordered: [...visibleFrequent, ...otherOptions],
    frequent: visibleFrequent,
  );
}

Iterable<String> accountUsageIds(FinancialOperation operation) sync* {
  if (operation.accountId != null) yield operation.accountId!;
  if (operation.debtAccountId != null) yield operation.debtAccountId!;
  if (operation.type == OperationType.transfer) {
    if (operation.sourceAccountId != null) yield operation.sourceAccountId!;
    if (operation.destinationAccountId != null) yield operation.destinationAccountId!;
  }
}

Iterable<String> categoryUsageIds(FinancialOperation operation, OperationType type) sync* {
  final isExpense = type == OperationType.expense;
  final matchesType = isExpense
      ? operation.type == OperationType.expense || operation.type == OperationType.expenseRefund
      : operation.type == OperationType.income;
  if (matchesType && operation.categoryId != null) yield operation.categoryId!;
}
