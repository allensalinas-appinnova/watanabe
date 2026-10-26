import 'package:flutter/material.dart';

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
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = _iconLabels(l10n);
    final query = _query.trim().toLowerCase();
    final height = (MediaQuery.sizeOf(context).height * 0.58).clamp(280.0, 520.0);
    return AlertDialog(
      title: Text(l10n.categoryIcon),
      content: SizedBox(
        width: 420,
        height: height,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('category_icon_search'),
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.categoryIconSearchHint,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.cancel,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Builder(
                builder: (context) {
                  final groups = <String, List<String>>{};
                  for (final entry in FinanceCategoryIcons.groups.entries) {
                    final matching = entry.value.where((iconId) {
                      final label = labels[iconId]!.toLowerCase();
                      return query.isEmpty || label.contains(query) || iconId.contains(query);
                    }).toList();
                    if (matching.isNotEmpty) groups[entry.key] = matching;
                  }
                  if (groups.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.categoryIconNoResults,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView(
                    key: const ValueKey('category_icon_options'),
                    children: [
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: 8, bottom: 6),
                          child: Text(
                            _groupLabel(entry.key, l10n),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.05,
                          children: [
                            for (final iconId in entry.value)
                              _IconOption(
                                iconId: iconId,
                                label: labels[iconId]!,
                                selected: _selected == iconId,
                                onPressed: () => setState(() => _selected = iconId),
                              ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
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

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.iconId,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String iconId;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: OutlinedButton(
      key: ValueKey('category_icon_option_$iconId'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 56),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Row(
        children: [
          FinanceCategoryIcon(iconId: iconId, size: 32, iconSize: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          if (selected)
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 18),
        ],
      ),
    ),
  );
}

Map<String, String> _iconLabels(AppLocalizations l10n) => {
  'food': l10n.categoryIconFood,
  'groceries': l10n.categoryIconGroceries,
  'housing': l10n.categoryIconHousing,
  'transport': l10n.categoryIconTransport,
  'car_maintenance': l10n.categoryIconCarMaintenance,
  'phone': l10n.categoryIconPhone,
  'utilities': l10n.categoryIconUtilities,
  'health': l10n.categoryIconHealth,
  'insurance': l10n.categoryIconInsurance,
  'education': l10n.categoryIconEducation,
  'family': l10n.categoryIconFamily,
  'children': l10n.categoryIconChildren,
  'parents': l10n.categoryIconParents,
  'pets': l10n.categoryIconPets,
  'sports': l10n.categoryIconSports,
  'hobbies': l10n.categoryIconHobbies,
  'subscriptions': l10n.categoryIconSubscriptions,
  'entertainment': l10n.categoryIconEntertainment,
  'travel': l10n.categoryIconTravel,
  'shopping': l10n.categoryIconShopping,
  'clothing': l10n.categoryIconClothing,
  'personal_care': l10n.categoryIconPersonalCare,
  'gift': l10n.categoryIconGift,
  'interest': l10n.categoryIconInterest,
  'salary': l10n.categoryIconSalary,
  'freelance': l10n.categoryIconFreelance,
  'business': l10n.categoryIconBusiness,
  'investment': l10n.categoryIconInvestment,
  'savings': l10n.categoryIconSavings,
  'other': l10n.categoryIconOther,
};

String _groupLabel(String group, AppLocalizations l10n) => switch (group) {
  'daily' => l10n.categoryIconGroupDaily,
  'wellbeing' => l10n.categoryIconGroupWellbeing,
  'lifestyle' => l10n.categoryIconGroupLifestyle,
  _ => l10n.categoryIconGroupMoney,
};
