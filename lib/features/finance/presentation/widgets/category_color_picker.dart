import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'finance_category_icon.dart';

class CategoryColorChoice {
  const CategoryColorChoice(this.colorValue);

  final int? colorValue;
}

Future<CategoryColorChoice?> showCategoryColorPicker(
  BuildContext context,
  int? initialColor,
) => showDialog<CategoryColorChoice>(
  context: context,
  builder: (context) => _CategoryColorPicker(initialColor: initialColor),
);

class _CategoryColorPicker extends StatefulWidget {
  const _CategoryColorPicker({required this.initialColor});

  final int? initialColor;

  @override
  State<_CategoryColorPicker> createState() => _CategoryColorPickerState();
}

class _CategoryColorPickerState extends State<_CategoryColorPicker> {
  late int? _selected = FinanceCategoryColors.options.contains(widget.initialColor)
      ? widget.initialColor
      : null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String labelFor(int? colorValue) {
      if (colorValue == null) return l10n.categoryColorDefault;
      final hex = colorValue.toRadixString(16).substring(2).toUpperCase();
      final hueLabel = switch (FinanceCategoryColors.palette.entries
          .where((entry) => entry.value.contains(colorValue))
          .firstOrNull
          ?.key) {
        'blue' => l10n.categoryColorBlue,
        'green' => l10n.categoryColorGreen,
        'orange' => l10n.categoryColorOrange,
        'purple' => l10n.categoryColorPurple,
        'red' => l10n.categoryColorRed,
        'teal' => l10n.categoryColorTeal,
        _ => l10n.categoryColor,
      };
      return l10n.categoryColorOption(hueLabel, '#$hex');
    }

    return AlertDialog(
      title: Text(l10n.categoryColor),
      content: SizedBox(
        width: 360,
        height: (MediaQuery.sizeOf(context).height * .5).clamp(220.0, 380.0),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: [
            for (final colorValue in FinanceCategoryColors.options)
              Semantics(
                button: true,
                selected: _selected == colorValue,
                label: labelFor(colorValue),
                child: OutlinedButton(
                  key: ValueKey(
                    'category_color_option_${colorValue?.toRadixString(16) ?? 'default'}',
                  ),
                  onPressed: () => setState(() => _selected = colorValue),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    side: BorderSide(
                      color: _selected == colorValue
                          ? FinanceCategoryColors.resolve(colorValue)
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: _selected == colorValue ? 2 : 1,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: FinanceCategoryColors.background(colorValue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          colorValue == null ? Icons.palette_outlined : Icons.circle,
                          size: 18,
                          color: FinanceCategoryColors.resolve(colorValue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(labelFor(colorValue), maxLines: 2, textAlign: TextAlign.start),
                      ),
                      if (_selected == colorValue)
                        Icon(
                          Icons.check_circle,
                          color: FinanceCategoryColors.resolve(colorValue),
                          size: 18,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('category_color_cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('category_color_use'),
          onPressed: () => Navigator.pop(context, CategoryColorChoice(_selected)),
          child: Text(l10n.useColor),
        ),
      ],
    );
  }
}
