import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_category.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalCategoriesScreen extends ConsumerWidget {
  const CanonicalCategoriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Inicia sesión')));
    final categories = ref.watch(canonicalCategoriesProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CategoryGroup(title: 'Gastos', type: CategoryType.expense, categories: items),
            _CategoryGroup(title: 'Ingresos', type: CategoryType.income, categories: items),
          ],
        ),
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({required this.title, required this.type, required this.categories});
  final String title;
  final CategoryType type;
  final List<FinanceCategory> categories;
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
            subtitle: Text(item.isSystem ? 'Predeterminada' : 'Personalizada'),
          ),
        ),
        if (filtered.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('Sin categorías activas.')),
      ],
    );
  }
}
