import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Searchable modal picker used by financial forms instead of native dropdowns.
class FinancePopupSelector<T> extends FormField<T> {
  FinancePopupSelector({
    required String title,
    required List<T> options,
    required String Function(T) optionLabel,
    required String Function(T) searchText,
    required Widget Function(BuildContext, T) optionBuilder,
    required ValueChanged<T>? onSelected,
    String? placeholder,
    super.validator,
    Key? controlKey,
    super.initialValue,
    super.key,
  }) : onSelected = onSelected,
       super(
         builder: (field) {
           final context = field.context;
           final l10n = AppLocalizations.of(context);
           final value = field.value;
           final enabled = onSelected != null;
           final selectedLabel = value == null ? null : optionLabel(value);
           return Semantics(
             button: enabled,
             enabled: enabled,
             label: '$title${selectedLabel == null ? '' : ', $selectedLabel'}',
             child: InkWell(
               key: controlKey ?? ValueKey('${field.widget.key ?? title}_tap'),
               borderRadius: BorderRadius.circular(12),
               onTap: enabled
                   ? () async {
                       final selected = await showModalBottomSheet<T>(
                         context: context,
                         isScrollControlled: true,
                         useSafeArea: true,
                         builder: (_) => _FinanceSelectionSheet<T>(
                           title: title,
                           options: options,
                           selectedValue: value,
                           searchText: searchText,
                           optionBuilder: optionBuilder,
                         ),
                       );
                       if (selected != null && field.mounted) {
                         field.didChange(selected);
                         onSelected(selected);
                       }
                     }
                   : null,
               child: InputDecorator(
                 isFocused: false,
                 isEmpty: value == null,
                 decoration: InputDecoration(
                   errorText: field.errorText,
                   enabled: enabled,
                   suffixIcon: const Icon(Icons.arrow_drop_down),
                 ),
                 child: value == null
                     ? Text(placeholder ?? l10n.selectionChoosePrompt)
                     : optionBuilder(context, value),
               ),
             ),
           );
         },
       );

  final ValueChanged<T>? onSelected;
}

class _FinanceSelectionSheet<T> extends StatefulWidget {
  const _FinanceSelectionSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.searchText,
    required this.optionBuilder,
  });

  final String title;
  final List<T> options;
  final T? selectedValue;
  final String Function(T) searchText;
  final Widget Function(BuildContext, T) optionBuilder;

  @override
  State<_FinanceSelectionSheet<T>> createState() => _FinanceSelectionSheetState<T>();
}

class _FinanceSelectionSheetState<T> extends State<_FinanceSelectionSheet<T>> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.options
        .where((option) => widget.searchText(option).toLowerCase().contains(query))
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              key: const ValueKey('finance_selection_search'),
              controller: _searchController,
              autofocus: false,
              decoration: InputDecoration(
                hintText: l10n.selectionSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.selectionClearSearch,
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(l10n.selectionNoResults))
                : ListView.builder(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final option = filtered[index];
                      final selected = option == widget.selectedValue;
                      return ListTile(
                        key: ValueKey('finance_popup_option_$index'),
                        selected: selected,
                        title: widget.optionBuilder(context, option),
                        trailing: selected ? const Icon(Icons.check) : null,
                        onTap: () => Navigator.of(context).pop(option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
