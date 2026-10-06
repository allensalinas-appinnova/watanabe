import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalAccountsScreen extends ConsumerWidget {
  const CanonicalAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Inicia sesión')));
    final accounts = ref.watch(canonicalAccountsProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas')),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Crea tu primera cuenta.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final account = items[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet),
                      title: Text(account.name),
                      subtitle: Text('${account.type} · ${account.currency}'),
                      trailing: Text(
                        NumberFormat.currency(
                          name: account.currency,
                          decimalDigits: 2,
                        ).format(account.currentBalanceMinor / 100),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref, user.id),
        icon: const Icon(Icons.add),
        label: const Text('Cuenta'),
      ),
    );
  }

  Future<void> _showCreate(BuildContext context, WidgetRef ref, String userId) async {
    final name = TextEditingController();
    final initial = TextEditingController(text: '0');
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Nueva cuenta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: initial,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Saldo inicial'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(initial.text.replaceAll(',', '.'));
                if (name.text.trim().isEmpty || amount == null || amount < 0) return;
                await ref
                    .read(canonicalActionsProvider)
                    .createAccount(
                      userId,
                      name: name.text,
                      type: 'cash',
                      currency: 'COP',
                      openingBalanceMinor: (amount * 100).round(),
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
    } finally {
      name.dispose();
      initial.dispose();
    }
  }
}
