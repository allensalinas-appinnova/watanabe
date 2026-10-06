class MonthKey {
  const MonthKey._(this.value);

  factory MonthKey.fromDate(DateTime date) => MonthKey._(
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}',
  );

  factory MonthKey.parse(String value) {
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) {
      throw FormatException('MonthKey must use yyyy-MM format.', value);
    }
    return MonthKey._(value);
  }

  final String value;

  int get year => int.parse(value.substring(0, 4));
  int get month => int.parse(value.substring(5, 7));

  @override
  bool operator ==(Object other) => other is MonthKey && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
