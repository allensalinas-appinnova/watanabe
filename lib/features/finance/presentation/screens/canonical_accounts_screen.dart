import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalAccountsScreen extends ConsumerWidget {
  const CanonicalAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Inicia sesión')));
    final l10n = AppLocalizations.of(context);
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
                    key: ValueKey('account_row_${account.id}'),
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet),
                      title: Text(account.name),
                      subtitle: Text('${account.type} · ${account.currency}'),
                      trailing: Text(
                        CurrencyFormatter.formatMinor(
                          account.currentBalanceMinor,
                          account.currency,
                        ),
                        key: ValueKey('account_balance_${account.id}'),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('accounts_add_button'),
        onPressed: () => _showCreate(context, ref, user.id),
        icon: const Icon(Icons.add),
        label: const Text('Cuenta'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        onDestinationSelected: (index) {
          if (index == 0) context.go('/home');
          if (index == 1) context.go('/activity');
          if (index == 2) context.go('/budgets');
        },
        destinations: [
          NavigationDestination(
            key: const ValueKey('accounts_home_nav'),
            icon: const Icon(Icons.home_outlined),
            label: l10n.home,
          ),
          NavigationDestination(
            key: const ValueKey('accounts_activity_nav'),
            icon: const Icon(Icons.list_alt_outlined),
            label: l10n.activity,
          ),
          NavigationDestination(
            key: const ValueKey('accounts_budget_nav'),
            icon: const Icon(Icons.pie_chart_outline),
            label: l10n.budget,
          ),
          NavigationDestination(
            key: const ValueKey('accounts_accounts_nav'),
            icon: const Icon(Icons.account_balance_wallet),
            label: l10n.accounts,
          ),
        ],
      ),
    );
  }

  Future<void> _showCreate(BuildContext context, WidgetRef ref, String userId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CreateAccountDialog(userId: userId),
    );
  }
}

class _CreateAccountDialog extends ConsumerStatefulWidget {
  const _CreateAccountDialog({required this.userId});

  final String userId;

  @override
  ConsumerState<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends ConsumerState<_CreateAccountDialog> {
  final _name = TextEditingController();
  final _initial = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nueva cuenta'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('account_name_field'),
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        TextField(
          key: const ValueKey('account_initial_balance_field'),
          controller: _initial,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Saldo inicial'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('account_save'),
        onPressed: _saving ? null : _save,
        child: _saving ? const CircularProgressIndicator() : const Text('Guardar'),
      ),
    ],
  );

  Future<void> _save() async {
    final amount = double.tryParse(_initial.text.replaceAll(',', '.'));
    if (_name.text.trim().isEmpty || amount == null || amount < 0) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(canonicalActionsProvider)
          .createAccount(
            widget.userId,
            name: _name.text,
            type: 'cash',
            currency: 'COP',
            openingBalanceMinor: (amount * 100).round(),
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
