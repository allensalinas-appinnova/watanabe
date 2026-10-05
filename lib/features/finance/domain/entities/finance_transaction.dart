class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.description,
    required this.category,
    required this.accountId,
    required this.amount,
    required this.date,
    required this.type,
  });

  final String id;
  final String description;
  final String category;
  final String accountId;
  final double amount;
  final DateTime date;
  final String type;

  bool get isIncome => type == 'income';
}
