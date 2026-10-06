import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/financial_operation.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalHomeScreen extends ConsumerWidget {
  const CanonicalHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    return session.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text(error.toString()))),
      data: (user) {
        if (user == null) return const Scaffold(body: Center(child: Text('Sesión expirada')));
        final accounts = ref.watch(canonicalAccountsProvider(user.id));
        final operations = ref.watch(canonicalOperationsProvider(user.id));
        return Scaffold(
          appBar: AppBar(
            title: const Text('ClearBudget'),
            actions: [
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref
                ..invalidate(canonicalAccountsProvider(user.id))
                ..invalidate(canonicalOperationsProvider(user.id));
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                accounts.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => _ErrorCard(message: error.toString()),
                  data: (items) => _BalanceCard(accounts: items),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Ingreso',
                        icon: Icons.add,
                        onTap: () => context.push('/operations/new?type=income'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        label: 'Gasto',
                        icon: Icons.remove,
                        onTap: () => context.push('/operations/new?type=expense'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        label: 'Transferir',
                        icon: Icons.swap_horiz,
                        onTap: () => context.push('/transfers/new'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Actividad reciente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                operations.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (error, _) => _ErrorCard(message: error.toString()),
                  data: (items) => items.isEmpty
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('Aún no tienes movimientos.'),
                          ),
                        )
                      : Column(
                          children: items
                              .take(10)
                              .map((item) => _OperationTile(operation: item))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              if (index == 1) context.go('/activity');
              if (index == 2) context.go('/budgets');
              if (index == 3) context.go('/accounts');
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt),
                label: 'Actividad',
              ),
              NavigationDestination(
                icon: Icon(Icons.pie_chart_outline),
                selectedIcon: Icon(Icons.pie_chart),
                label: 'Presupuesto',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: 'Cuentas',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.accounts});
  final List<FinanceAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final byCurrency = <String, int>{};
    for (final account in accounts) {
      byCurrency[account.currency] =
          (byCurrency[account.currency] ?? 0) + account.currentBalanceMinor;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Balance actual'),
            const SizedBox(height: 8),
            ...byCurrency.entries.map(
              (entry) => Text(
                _money(entry.value, entry.key),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({required this.operation});
  final FinancialOperation operation;

  @override
  Widget build(BuildContext context) {
    final isIncome = operation.type == OperationType.income;
    final isTransfer = operation.type == OperationType.transfer;
    return ListTile(
      leading: CircleAvatar(
        child: Icon(
          isTransfer
              ? Icons.swap_horiz
              : isIncome
              ? Icons.add
              : Icons.remove,
        ),
      ),
      title: Text(operation.description.isEmpty ? operation.type.name : operation.description),
      subtitle: Text(DateFormat.yMMMd().format(operation.occurredAt.toLocal())),
      trailing: Text(
        '${isIncome
            ? '+'
            : isTransfer
            ? ''
            : '-'}${_money(operation.amountMinor, operation.currency)}',
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      FilledButton.tonalIcon(onPressed: onTap, icon: Icon(icon), label: Text(label));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text('No se pudo cargar: $message')),
  );
}

String _money(int minor, String currency) =>
    NumberFormat.currency(name: currency, decimalDigits: 2).format(minor / 100);
