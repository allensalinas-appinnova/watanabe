import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_category.dart';
import '../providers/canonical_finance_providers.dart';

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
                          const Icon(Icons.category_outlined, color: AppColors.blueDark),
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
    try {
      final dialogRoute = DialogRoute<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(l10n.newCategory),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('category_create_name'),
                  controller: name,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(labelText: l10n.categoryName),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CategoryType>(
                  key: const ValueKey('category_create_type'),
                  initialValue: type,
                  decoration: InputDecoration(labelText: l10n.categoryType),
                  items: [
                    DropdownMenuItem(value: CategoryType.expense, child: Text(l10n.expense)),
                    DropdownMenuItem(value: CategoryType.income, child: Text(l10n.income)),
                  ],
                  onChanged: (value) => setDialogState(() => type = value ?? type),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: name.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      );
      final shouldCreate = await Navigator.of(context, rootNavigator: true).push(dialogRoute);
      await dialogRoute.completed;
      if (shouldCreate != true || name.text.trim().isEmpty || !mounted) return;
      final result = await ref
          .read(canonicalFinanceRepositoryProvider)
          .createCategory(
            userId,
            name: name.text.trim(),
            type: type,
            icon: 'category_outlined',
          );
      result.match(
        (_) => _showMessage(l10n.genericError),
        (_) => ref.invalidate(canonicalCategoriesProvider(userId)),
      );
    } catch (_) {
      if (mounted) _showMessage(l10n.genericError);
    } finally {
      name.dispose();
    }
  }

  Future<void> _edit(String userId, FinanceCategory category) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController(text: category.customName ?? category.id);
    var isSaving = false;
    var errorMessage = '';
    try {
      final dialogRoute = DialogRoute<_CategoryEditAction>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(l10n.editCategory),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.categorySavedDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('category_edit_name'),
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.categoryName,
                    errorText: errorMessage == l10n.categoryNameRequired ? errorMessage : null,
                  ),
                  onChanged: (_) {
                    if (errorMessage.isNotEmpty) setDialogState(() => errorMessage = '');
                  },
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: InputDecoration(labelText: l10n.categoryTypeReadOnly),
                  child: Text(_categoryTypeLabel(category.type, l10n)),
                ),
                if (errorMessage == l10n.genericError) ...[
                  const SizedBox(height: 8),
                  Semantics(liveRegion: true, child: Text(errorMessage)),
                ],
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('category_edit_archive'),
                    onPressed: isSaving
                        ? null
                        : () => Navigator.pop(dialogContext, _CategoryEditAction.archive),
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(l10n.archive),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const ValueKey('category_edit_save'),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (name.text.trim().isEmpty) {
                          setDialogState(() => errorMessage = l10n.categoryNameRequired);
                          return;
                        }
                        setDialogState(() {
                          isSaving = true;
                          errorMessage = '';
                        });
                        final edited = FinanceCategory(
                          id: category.id,
                          type: category.type,
                          icon: category.icon,
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
                                Navigator.pop(dialogContext, _CategoryEditAction.saved);
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
                    : Text(l10n.saveCategoryChanges),
              ),
            ],
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
