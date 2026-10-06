class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.operationId,
    required this.accountId,
    required this.deltaMinor,
    required this.currency,
  });

  final String id;
  final String operationId;
  final String accountId;
  final int deltaMinor;
  final String currency;
}
