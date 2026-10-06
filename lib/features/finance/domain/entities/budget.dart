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
    this.items = const [],
  });

  final String id;
  final String categoryId;
  final BudgetFlowType flowType;
  final String monthKey;
  final String currency;
  final int plannedAmountMinor;
  final String status;
  final List<BudgetItem> items;
}
