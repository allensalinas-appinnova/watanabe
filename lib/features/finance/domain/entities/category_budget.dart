class CategoryBudget {
  const CategoryBudget({
    required this.id,
    required this.category,
    required this.spent,
    required this.limit,
    required this.colorValue,
  });

  final String id;
  final String category;
  final double spent;
  final double limit;
  final int colorValue;
}
