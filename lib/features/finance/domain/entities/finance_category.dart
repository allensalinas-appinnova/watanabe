enum CategoryType { income, expense }

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.type,
    required this.icon,
    required this.sortOrder,
    required this.isSystem,
    required this.isArchived,
    this.catalogId,
    this.customName,
    this.colorValue,
  });

  final String id;
  final CategoryType type;
  final String icon;
  final int sortOrder;
  final bool isSystem;
  final bool isArchived;
  final String? catalogId;
  final String? customName;
  final int? colorValue;
}
