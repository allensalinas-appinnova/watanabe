class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.description,
    required this.amountMinor,
    required this.dayOfMonth,
    this.actualAmountMinor = 0,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String description;
  final int amountMinor;
  final int dayOfMonth;

  /// Confirmed amount of movements linked to this item. Legacy items default to zero.
  final int actualAmountMinor;

  /// Missing values in older records are treated as active.
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;

  bool get isActive => status != 'archived';
}
