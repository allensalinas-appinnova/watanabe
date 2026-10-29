import 'budget_flow_type.dart';
import 'budget_item.dart';

class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.flowType,
    required this.monthKey,
    required this.currency,
    required this.plannedAmountMinor,
    required this.status,
    this.itemCount = 0,
    this.items = const [],
  });

  final String id;
  final String categoryId;
  final BudgetFlowType flowType;
  final String monthKey;
  final String currency;
  final int plannedAmountMinor;
  final String status;
  final int itemCount;
  final List<BudgetItem> items;

  Budget copyWith({int? plannedAmountMinor, int? itemCount}) => Budget(
    id: id,
    categoryId: categoryId,
    flowType: flowType,
    monthKey: monthKey,
    currency: currency,
    plannedAmountMinor: plannedAmountMinor ?? this.plannedAmountMinor,
    status: status,
    itemCount: itemCount ?? this.itemCount,
    items: items,
  );
}
