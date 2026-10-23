import '../../finance/domain/entities/finance_account.dart';

class RecordedPosition {
  const RecordedPosition({this.moneyMinor = 0, this.debtMinor = 0, this.cardCreditMinor = 0});
  final int moneyMinor;
  final int debtMinor;
  final int cardCreditMinor;
  int get netMinor => moneyMinor + cardCreditMinor - debtMinor;
  static Map<String, RecordedPosition> byCurrency(Iterable<FinanceAccount> accounts) {
    final result = <String, RecordedPosition>{};
    for (final account in accounts.where((a) => a.status == 'active' && a.includeInDashboard)) {
      final current = result[account.currency] ?? const RecordedPosition();
      result[account.currency] = RecordedPosition(
        moneyMinor: current.moneyMinor + (account.isDebt ? 0 : account.currentBalanceMinor),
        debtMinor: current.debtMinor + account.debtMinor,
        cardCreditMinor: current.cardCreditMinor + account.creditBalanceMinor,
      );
    }
    return Map.unmodifiable(result);
  }
}
