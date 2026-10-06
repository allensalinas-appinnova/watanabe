class Money {
  const Money({required this.amountMinor, required this.currency})
    : assert(amountMinor >= 0),
      assert(currency.length == 3);

  final int amountMinor;
  final String currency;

  Money copyWith({int? amountMinor, String? currency}) => Money(
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
  );
}
