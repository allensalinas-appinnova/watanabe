import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_category.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalCategoriesScreen extends ConsumerWidget {
  const CanonicalCategoriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final categories = ref.watch(canonicalCategoriesProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.categories)),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.genericError)),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CategoryGroup(
              title: l10n.expenseCategories,
              type: CategoryType.expense,
              categories: items,
              onArchive: (category) => _archive(context, ref, user.id, category),
            ),
            _CategoryGroup(
              title: l10n.incomeCategories,
              type: CategoryType.income,
              categories: items,
              onArchive: (category) => _archive(context, ref, user.id, category),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref, user.id),
        icon: const Icon(Icons.add),
        label: Text(l10n.createCategory),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref, String userId) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController();
    var type = CategoryType.expense;
    try {
      final shouldCreate = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(l10n.newCategory),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: l10n.category),
                ),
                DropdownButtonFormField<CategoryType>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: l10n.categoryType),
                  items: [
                    DropdownMenuItem(value: CategoryType.expense, child: Text(l10n.expense)),
                    DropdownMenuItem(value: CategoryType.income, child: Text(l10n.income)),
                  ],
                  onChanged: (value) => setState(() => type = value ?? CategoryType.expense),
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
      if (shouldCreate != true || name.text.trim().isEmpty) return;
      final result = await ref
          .read(canonicalFinanceRepositoryProvider)
          .createCategory(
            userId,
            name: name.text.trim(),
            type: type,
            icon: 'category_outlined',
          );
      result.match(
        (_) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError)),
        ),
        (_) {},
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError)),
        );
      }
    } finally {
      name.dispose();
    }
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    String userId,
    FinanceCategory category,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.archive),
        content: Text(l10n.confirmArchiveCategory),
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
    if (confirmed != true) return;
    try {
      final result = await ref
          .read(canonicalFinanceRepositoryProvider)
          .archiveCategory(userId, category.id);
      result.match(
        (_) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError)),
        ),
        (_) {},
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError)),
        );
      }
    }
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.title,
    required this.type,
    required this.categories,
    required this.onArchive,
  });
  final String title;
  final CategoryType type;
  final List<FinanceCategory> categories;
  final ValueChanged<FinanceCategory> onArchive;
  @override
  Widget build(BuildContext context) {
    final filtered = categories.where((item) => item.type == type && !item.isArchived).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        ...filtered.map(
          (item) => ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(item.customName ?? item.id),
            subtitle: Text(
              item.isSystem
                  ? AppLocalizations.of(context).systemCategory
                  : AppLocalizations.of(context).customCategory,
            ),
            trailing: IconButton(
              tooltip: AppLocalizations.of(context).archive,
              onPressed: () => onArchive(item),
              icon: const Icon(Icons.archive_outlined),
            ),
          ),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(AppLocalizations.of(context).noCategories),
          ),
      ],
    );
  }
}
