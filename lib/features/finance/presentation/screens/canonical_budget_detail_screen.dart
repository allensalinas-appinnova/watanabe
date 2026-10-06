import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/budget_item.dart';
import '../../domain/repositories/canonical_finance_repository.dart';

class CanonicalBudgetDetailScreen extends ConsumerWidget {
  const CanonicalBudgetDetailScreen({super.key, required this.budgetId});
  final String budgetId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Inicia sesión')));
    final items = ref.watch(canonicalFinanceRepositoryItemsProvider((user.id, budgetId)));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del presupuesto')),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (values) => values.isEmpty
            ? const Center(child: Text('Este presupuesto no tiene items.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: values
                    .map(
                      (item) => Card(
                        child: ListTile(
                          title: Text(item.description),
                          subtitle: Text('Día ${item.dayOfMonth}'),
                          trailing: Text(
                            NumberFormat.currency(
                              name: 'COP',
                              decimalDigits: 2,
                            ).format(item.amountMinor / 100),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}

final canonicalFinanceRepositoryItemsProvider =
    StreamProvider.family<List<BudgetItem>, (String, String)>(
      (ref, input) => ref.watch(canonicalRepositoryProvider).watchBudgetItems(input.$1, input.$2),
    );

final canonicalRepositoryProvider = Provider((ref) => getIt<CanonicalFinanceRepository>());
