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
    this.nature = 'money',
    this.referenceAt,
    this.principalMinor = 0,
    this.chargesMinor = 0,
    this.limitMinor,
    this.creditor,
    this.lastFour,
    this.statementClosingDay,
    this.paymentDueDay,
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
  final String nature;
  final DateTime? referenceAt;
  final int principalMinor;
  final int chargesMinor;
  final int? limitMinor;
  final String? creditor;
  final String? lastFour;
  final int? statementClosingDay;
  final int? paymentDueDay;

  bool get isDebt => nature == 'debt';
  bool get isCreditCard => isDebt && type == 'creditCard';
  int get debtMinor => isDebt && currentBalanceMinor < 0 ? -currentBalanceMinor : 0;
  int get creditBalanceMinor => isCreditCard && currentBalanceMinor > 0 ? currentBalanceMinor : 0;
}
