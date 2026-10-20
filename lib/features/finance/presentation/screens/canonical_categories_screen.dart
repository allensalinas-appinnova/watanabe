import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_category.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/category_icon_picker.dart';
import '../widgets/finance_category_icon.dart';

enum _CategoryEditAction { saved, archive }

class CanonicalCategoriesScreen extends ConsumerStatefulWidget {
  const CanonicalCategoriesScreen({super.key});

  @override
  ConsumerState<CanonicalCategoriesScreen> createState() => _CanonicalCategoriesScreenState();
}

class _CanonicalCategoriesScreenState extends ConsumerState<CanonicalCategoriesScreen> {
  CategoryType _selectedType = CategoryType.expense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));

    final categories = ref.watch(canonicalCategoriesProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.categories)),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _CategoriesError(
          message: l10n.genericError,
          retryLabel: l10n.retry,
          onRetry: () => ref.invalidate(canonicalCategoriesProvider(user.id)),
        ),
        data: (items) {
          final active =
              items.where((item) => item.type == _selectedType && !item.isArchived).toList()
                ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return ListView(
            key: const ValueKey('categories_list'),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 104),
            children: [
              Text(
                l10n.categoriesSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              SegmentedButton<CategoryType>(
                key: const ValueKey('categories_type_filter'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: CategoryType.expense, label: Text(l10n.expenseCategories)),
                  ButtonSegment(value: CategoryType.income, label: Text(l10n.incomeCategories)),
                ],
                selected: {_selectedType},
                onSelectionChanged: (selection) => setState(() => _selectedType = selection.first),
              ),
              const SizedBox(height: 12),
              if (active.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    l10n.noCategories,
                    key: const ValueKey('categories_empty'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                )
              else
                ...active.map(
                  (category) => Card(
                    key: ValueKey('category_row_${category.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          FinanceCategoryIcon(
                            iconId: category.icon,
                            semanticLabel: category.customName ?? category.id,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.customName ?? category.id,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  category.isSystem ? l10n.systemCategory : l10n.customCategory,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            key: ValueKey('category_edit_${category.id}'),
                            onPressed: () => _edit(user.id, category),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(l10n.edit),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  key: const ValueKey('categories_create'),
                  onPressed: () => _create(user.id),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.createCategory),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _create(String userId) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController();
    var type = _selectedType;
    var icon = 'other';
    var isSaving = false;
    var errorMessage = '';
    try {
      final dialogRoute = DialogRoute<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: null,
            contentPadding: EdgeInsets.zero,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            content: Container(
              key: const ValueKey('category_create_dialog_surface'),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 394),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.newCategory,
                        key: const ValueKey('category_create_title'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.navy,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.categorySavedDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _EditCategoryFieldLabel(label: l10n.categoryName),
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('category_create_name'),
                        controller: name,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setDialogState(() => errorMessage = ''),
                        decoration: InputDecoration(
                          errorText: errorMessage == l10n.categoryNameRequired
                              ? errorMessage
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _EditCategoryFieldLabel(label: l10n.categoryType),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CategoryType>(
                            key: const ValueKey('category_create_type'),
                            value: type,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(
                                value: CategoryType.expense,
                                child: Text(l10n.expense),
                              ),
                              DropdownMenuItem(
                                value: CategoryType.income,
                                child: Text(l10n.income),
                              ),
                            ],
                            onChanged: isSaving
                                ? null
                                : (value) => setDialogState(() => type = value ?? type),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _EditCategoryFieldLabel(label: l10n.categoryIconLabel),
                      const SizedBox(height: 8),
                      _EditCategoryIconPreview(
                        iconId: icon,
                        iconLabel: _categoryIconLabel(icon, l10n),
                        changeLabel: l10n.changeIcon,
                        onChange: () async {
                          final selected = await showCategoryIconPicker(dialogContext, icon);
                          if (selected != null && dialogContext.mounted) {
                            setDialogState(() => icon = selected);
                          }
                        },
                      ),
                      if (errorMessage == l10n.genericError) ...[
                        const SizedBox(height: 8),
                        Semantics(liveRegion: true, child: Text(errorMessage)),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                key: const ValueKey('category_create_cancel'),
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.pop(dialogContext, false),
                                child: Text(l10n.cancel, textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: FilledButton(
                                key: const ValueKey('category_create_save'),
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        if (name.text.trim().isEmpty) {
                                          setDialogState(
                                            () => errorMessage = l10n.categoryNameRequired,
                                          );
                                          return;
                                        }
                                        setDialogState(() {
                                          isSaving = true;
                                          errorMessage = '';
                                        });
                                        try {
                                          final result = await ref
                                              .read(canonicalFinanceRepositoryProvider)
                                              .createCategory(
                                                userId,
                                                name: name.text.trim(),
                                                type: type,
                                                icon: icon,
                                              );
                                          result.match(
                                            (_) {
                                              if (dialogContext.mounted) {
                                                setDialogState(() {
                                                  isSaving = false;
                                                  errorMessage = l10n.genericError;
                                                });
                                              }
                                            },
                                            (_) {
                                              ref.invalidate(
                                                canonicalCategoriesProvider(userId),
                                              );
                                              if (dialogContext.mounted) {
                                                Navigator.pop(dialogContext, true);
                                              }
                                            },
                                          );
                                        } catch (_) {
                                          if (dialogContext.mounted) {
                                            setDialogState(() {
                                              isSaving = false;
                                              errorMessage = l10n.genericError;
                                            });
                                          }
                                        }
                                      },
                                child: isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(l10n.save, textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final shouldCreate = await Navigator.of(context, rootNavigator: true).push(dialogRoute);
      await dialogRoute.completed;
      if (shouldCreate == true && mounted) _showMessage(l10n.categorySaved);
    } catch (_) {
      if (mounted) _showMessage(l10n.genericError);
    } finally {
      name.dispose();
    }
  }

  Future<void> _edit(String userId, FinanceCategory category) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController(text: category.customName ?? category.id);
    var icon = category.icon;
    var isSaving = false;
    var errorMessage = '';
    try {
      final dialogRoute = DialogRoute<_CategoryEditAction>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: null,
            contentPadding: EdgeInsets.zero,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            content: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 394),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.editCategory,
                        key: const ValueKey('category_edit_title'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.navy,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.categorySavedDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _EditCategoryFieldLabel(label: l10n.categoryName),
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('category_edit_name'),
                        controller: name,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          errorText: errorMessage == l10n.categoryNameRequired
                              ? errorMessage
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onChanged: (_) {
                          if (errorMessage.isNotEmpty) setDialogState(() => errorMessage = '');
                        },
                      ),
                      const SizedBox(height: 16),
                      _EditCategoryFieldLabel(label: l10n.categoryIconLabel),
                      const SizedBox(height: 8),
                      _EditCategoryIconPreview(
                        iconId: icon,
                        iconLabel: _categoryIconLabel(icon, l10n),
                        changeLabel: l10n.changeIcon,
                        onChange: () async {
                          final selected = await showCategoryIconPicker(dialogContext, icon);
                          if (selected != null && dialogContext.mounted) {
                            setDialogState(() => icon = selected);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _EditCategoryFieldLabel(label: l10n.categoryTypeReadOnly),
                      const SizedBox(height: 8),
                      Container(
                        key: const ValueKey('category_edit_type_read_only'),
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(_categoryTypeLabel(category.type, l10n)),
                      ),
                      if (errorMessage == l10n.genericError) ...[
                        const SizedBox(height: 8),
                        Semantics(liveRegion: true, child: Text(errorMessage)),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: TextButton(
                          key: const ValueKey('category_edit_archive'),
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(dialogContext, _CategoryEditAction.archive),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                            alignment: AlignmentDirectional.centerStart,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(l10n.archive),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                key: const ValueKey('category_edit_cancel'),
                                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                                child: Text(l10n.cancel, textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: FilledButton(
                                key: const ValueKey('category_edit_save'),
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        if (name.text.trim().isEmpty) {
                                          setDialogState(
                                            () => errorMessage = l10n.categoryNameRequired,
                                          );
                                          return;
                                        }
                                        setDialogState(() {
                                          isSaving = true;
                                          errorMessage = '';
                                        });
                                        final edited = FinanceCategory(
                                          id: category.id,
                                          type: category.type,
                                          icon: icon,
                                          sortOrder: category.sortOrder,
                                          isSystem: category.isSystem,
                                          isArchived: category.isArchived,
                                          catalogId: category.catalogId,
                                          customName: name.text.trim(),
                                          colorValue: category.colorValue,
                                        );
                                        try {
                                          final result = await ref
                                              .read(canonicalFinanceRepositoryProvider)
                                              .updateCategory(userId, edited);
                                          result.match(
                                            (_) {
                                              if (dialogContext.mounted) {
                                                setDialogState(() {
                                                  isSaving = false;
                                                  errorMessage = l10n.genericError;
                                                });
                                              }
                                            },
                                            (_) {
                                              ref.invalidate(canonicalCategoriesProvider(userId));
                                              if (dialogContext.mounted) {
                                                Navigator.pop(
                                                  dialogContext,
                                                  _CategoryEditAction.saved,
                                                );
                                              }
                                            },
                                          );
                                        } catch (_) {
                                          if (dialogContext.mounted) {
                                            setDialogState(() {
                                              isSaving = false;
                                              errorMessage = l10n.genericError;
                                            });
                                          }
                                        }
                                      },
                                child: isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(
                                        l10n.saveCategoryChanges,
                                        textAlign: TextAlign.center,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final action = await Navigator.of(context, rootNavigator: true).push(dialogRoute);
      await dialogRoute.completed;
      if (!mounted) return;
      switch (action) {
        case _CategoryEditAction.saved:
          _showMessage(l10n.categorySaved);
        case _CategoryEditAction.archive:
          await _archive(userId, category);
        case null:
          break;
      }
    } finally {
      name.dispose();
    }
  }

  Future<void> _archive(String userId, FinanceCategory category) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmArchiveCategoryTitle),
        content: Text(l10n.archiveCategoryDetails),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.archive),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await ref
          .read(canonicalFinanceRepositoryProvider)
          .archiveCategory(userId, category.id);
      result.match(
        (_) => _showMessage(l10n.genericError),
        (_) => ref.invalidate(canonicalCategoriesProvider(userId)),
      );
    } catch (_) {
      if (mounted) _showMessage(l10n.genericError);
    }
  }

  String _categoryTypeLabel(CategoryType type, AppLocalizations l10n) =>
      type == CategoryType.expense ? l10n.expense : l10n.income;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EditCategoryFieldLabel extends StatelessWidget {
  const _EditCategoryFieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.muted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
  );
}

class _EditCategoryIconPreview extends StatelessWidget {
  const _EditCategoryIconPreview({
    required this.iconId,
    required this.iconLabel,
    required this.changeLabel,
    required this.onChange,
  });

  final String? iconId;
  final String iconLabel;
  final String changeLabel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        FinanceCategoryIcon(
          key: const ValueKey('category_icon_preview'),
          iconId: iconId,
          size: 32,
          iconSize: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            iconLabel,
            key: const ValueKey('category_edit_icon_label'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('category_icon_change'),
          onPressed: onChange,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          child: Text(changeLabel, textAlign: TextAlign.end),
        ),
      ],
    ),
  );
}

String _categoryIconLabel(String? iconId, AppLocalizations l10n) =>
    switch (FinanceCategoryIcons.canonicalId(iconId)) {
      'food' => l10n.categoryIconUtensils,
      'housing' => l10n.categoryIconHouse,
      'transport' => l10n.categoryIconCar,
      'health' => l10n.categoryIconHeart,
      'education' => l10n.categoryIconBook,
      'salary' => l10n.categoryIconBriefcase,
      _ => l10n.categoryIconTag,
    };

class _CategoriesError extends StatelessWidget {
  const _CategoriesError({required this.message, required this.retryLabel, required this.onRetry});

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    ),
  );
}
