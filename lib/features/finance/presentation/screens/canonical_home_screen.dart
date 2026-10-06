import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../../l10n/generated/app_localizations.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/monthly_summary.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalHomeScreen extends ConsumerWidget {
  const CanonicalHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pendingOperationAutoSyncProvider);
    final session = ref.watch(authSessionProvider);
    return session.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text(error.toString()))),
      data: (user) {
        final l10n = AppLocalizations.of(context);
        if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
        final accounts = ref.watch(canonicalAccountsProvider(user.id));
        final operations = ref.watch(canonicalOperationsProvider(user.id));
        final primaryCurrency = accounts.valueOrNull?.isNotEmpty == true
            ? accounts.valueOrNull!.first.currency
            : 'COP';
        final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
        final summary = ref.watch(
          canonicalMonthlySummaryProvider(
            (userId: user.id, monthKey: monthKey, currency: primaryCurrency),
          ),
        );
        final pending = ref.watch(pendingOperationsProvider).valueOrNull ?? const [];
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
                if (pending.isNotEmpty)
                  Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.sync_problem),
                      title: Text(l10n.offlinePending),
                      subtitle: Text('${pending.length}'),
                      trailing: TextButton(
                        onPressed: () => ref.read(canonicalActionsProvider).syncPending(user.id),
                        child: Text(l10n.retry),
                      ),
                    ),
                  ),
                accounts.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => _ErrorCard(message: error.toString()),
                  data: (items) => _BalanceCard(accounts: items),
                ),
                summary.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (value) =>
                      value == null ? const SizedBox.shrink() : _MonthlySummaryCard(summary: value),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        key: const ValueKey('home_add_income'),
                        label: l10n.income,
                        icon: Icons.add,
                        onTap: () => context.push('/operations/new?type=income'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        key: const ValueKey('home_add_expense'),
                        label: l10n.expense,
                        icon: Icons.remove,
                        onTap: () => context.push('/operations/new?type=expense'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        key: const ValueKey('home_transfer'),
                        label: l10n.transfer,
                        icon: Icons.swap_horiz,
                        onTap: () => context.push('/transfers/new'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.recentActivity,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                operations.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (error, _) => _ErrorCard(message: error.toString()),
                  data: (items) => items.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(l10n.noTransactions),
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
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: l10n.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.list_alt_outlined),
                selectedIcon: const Icon(Icons.list_alt),
                label: l10n.activity,
              ),
              NavigationDestination(
                icon: const Icon(Icons.pie_chart_outline),
                selectedIcon: const Icon(Icons.pie_chart),
                label: l10n.budget,
              ),
              NavigationDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: const Icon(Icons.account_balance_wallet),
                label: l10n.accounts,
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

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SummaryValue(
            label: AppLocalizations.of(context).income,
            value: _money(summary.incomeMinor, summary.currency),
          ),
          _SummaryValue(
            label: AppLocalizations.of(context).expense,
            value: _money(summary.expenseMinor, summary.currency),
          ),
        ],
      ),
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
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
  const _ActionButton({required this.label, required this.icon, required this.onTap, super.key});
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
