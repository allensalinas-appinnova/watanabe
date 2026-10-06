class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.description,
    required this.amountMinor,
    required this.dayOfMonth,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String description;
  final int amountMinor;
  final int dayOfMonth;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
