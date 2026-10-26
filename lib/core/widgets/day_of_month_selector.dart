import 'package:flutter/material.dart';

/// A localized selector for nominal or month-constrained days of the month.
class DayOfMonthSelector extends StatelessWidget {
  const DayOfMonthSelector({
    required this.fieldId,
    required this.selectedDay,
    required this.onChanged,
    required this.dayLabel,
    this.label,
    this.unsetLabel,
    this.minDay = 1,
    this.maxDay = 31,
    this.enabled = true,
    super.key,
  }) : assert(minDay >= 1),
       assert(maxDay <= 31),
       assert(minDay <= maxDay),
       assert(selectedDay == null || (selectedDay >= minDay && selectedDay <= maxDay));

  final String fieldId;
  final int? selectedDay;
  final ValueChanged<int?> onChanged;
  final String dayLabel;
  final String? label;
  final String? unsetLabel;
  final int minDay;
  final int maxDay;
  final bool enabled;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    key: ValueKey('day_of_month_${fieldId}_${minDay}_${maxDay}_${selectedDay ?? 'unset'}'),
    initialValue: selectedDay ?? 0,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      if (unsetLabel != null) DropdownMenuItem(value: 0, child: Text(unsetLabel!)),
      for (var day = minDay; day <= maxDay; day++)
        DropdownMenuItem(value: day, child: Text('$dayLabel $day')),
    ],
    onChanged: enabled ? (day) => onChanged(day == 0 ? null : day) : null,
  );
}
