import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'finance_category_icon.dart';

Future<String?> showCategoryIconPicker(BuildContext context, String? initialIcon) =>
    showDialog<String>(
      context: context,
      builder: (context) => _CategoryIconPicker(initialIcon: initialIcon),
    );

class _CategoryIconPicker extends StatefulWidget {
  const _CategoryIconPicker({required this.initialIcon});

  final String? initialIcon;

  @override
  State<_CategoryIconPicker> createState() => _CategoryIconPickerState();
}

class _CategoryIconPickerState extends State<_CategoryIconPicker> {
  late String _selected = FinanceCategoryIcons.canonicalId(widget.initialIcon) ?? 'other';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = <String, String>{
      'food': l10n.categoryIconFood,
      'housing': l10n.categoryIconHousing,
      'transport': l10n.categoryIconTransport,
      'health': l10n.categoryIconHealth,
      'education': l10n.categoryIconEducation,
      'salary': l10n.categoryIconSalary,
      'other': l10n.categoryIconOther,
    };
    return AlertDialog(
      title: Text(l10n.categoryIcon),
      content: SizedBox(
        width: 360,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: [
            for (final iconId in FinanceCategoryIcons.options)
              Semantics(
                button: true,
                selected: _selected == iconId,
                label: labels[iconId],
                child: OutlinedButton(
                  key: ValueKey('category_icon_option_$iconId'),
                  onPressed: () => setState(() => _selected = iconId),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    side: BorderSide(
                      color: _selected == iconId ? AppColors.blueDark : AppColors.line,
                      width: _selected == iconId ? 2 : 1,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Row(
                    children: [
                      FinanceCategoryIcon(iconId: iconId, size: 36),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(labels[iconId]!, maxLines: 2, textAlign: TextAlign.start),
                      ),
                      if (_selected == iconId)
                        const Icon(Icons.check_circle, color: AppColors.blueDark, size: 18),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('category_icon_cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('category_icon_use'),
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(l10n.useIcon),
        ),
      ],
    );
  }
}
