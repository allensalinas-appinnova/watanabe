class FinanceAccount {
  const FinanceAccount({
    required this.id,
    required this.name,
    required this.type,
    this.currency = 'COP',
    this.openingBalanceMinor = 0,
    this.currentBalanceMinor = 0,
    this.includeInDashboard = true,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String type;
  final String currency;
  final int openingBalanceMinor;
  final int currentBalanceMinor;
  final bool includeInDashboard;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;
}
