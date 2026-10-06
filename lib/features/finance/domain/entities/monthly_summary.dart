class MonthlySummary {
  const MonthlySummary({
    required this.monthKey,
    required this.currency,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.transferInMinor,
    required this.transferOutMinor,
    required this.byCategory,
  });

  final String monthKey;
  final String currency;
  final int incomeMinor;
  final int expenseMinor;
  final int transferInMinor;
  final int transferOutMinor;
  final Map<String, int> byCategory;
}
