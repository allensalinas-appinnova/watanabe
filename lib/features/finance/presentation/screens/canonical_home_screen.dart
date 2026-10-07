import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
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
      error: (_, _) => Scaffold(
        body: Center(child: Text(AppLocalizations.of(context).genericError)),
      ),
      data: (user) {
        final l10n = AppLocalizations.of(context);
        if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
        final accounts = ref.watch(canonicalAccountsProvider(user.id));
        final operations = ref.watch(
          canonicalOperationsPageProvider((
            userId: user.id,
            cursor: null,
            monthKey: null,
            currency: null,
            pageSize: 10,
          )),
        );
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
                ..invalidate(
                  canonicalOperationsPageProvider((
                    userId: user.id,
                    cursor: null,
                    monthKey: null,
                    currency: null,
                    pageSize: 10,
                  )),
                );
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (pending.isNotEmpty)
                  Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.sync_problem),
                        title: Text(
                          pending.any((item) => item.status == 'rejected')
                              ? l10n.offlineRejected
                              : l10n.offlinePending,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final operation in pending.take(3))
                              Text(
                                _pendingDescription(
                                  operation.operationType,
                                  operation.payload,
                                  l10n,
                                ),
                              ),
                            if (pending.length > 3) Text('+${pending.length - 3}'),
                          ],
                        ),
                        trailing: TextButton(
                          onPressed: () => ref.read(canonicalActionsProvider).syncPending(user.id),
                          child: Text(l10n.retry),
                        ),
                      ),
                    ),
                  ),
                accounts.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => _ErrorCard(message: l10n.genericError),
                  data: (items) => _BalanceCard(accounts: items),
                ),
                summary.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (value) =>
                      value == null ? const SizedBox.shrink() : _MonthlySummaryCard(summary: value),
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 24),
                Text(
                  l10n.recentActivity,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                operations.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (_, _) => _ErrorCard(message: l10n.genericError),
                  data: (page) => page.items.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(l10n.noTransactions),
                          ),
                        )
                      : Column(
                          children: page.items
                              .take(10)
                              .map((item) => _OperationTile(operation: item))
                              .toList(),
                        ),
                ),
              ],
            ),
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
      onTap: isTransfer
          ? null
          : () => context.push('/operations/${operation.id}/edit', extra: operation),
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
  );
}

String _money(int minor, String currency) => CurrencyFormatter.formatMinor(minor, currency);

String _pendingDescription(String operationType, String payload, AppLocalizations l10n) {
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final rawType = operationType == 'transfer' ? 'transfer' : data['type'] as String?;
    final typeLabel = switch (rawType) {
      'income' => l10n.income,
      'expense' => l10n.expense,
      'transfer' => l10n.transfer,
      _ => l10n.activity,
    };
    final description = (data['description'] as String?)?.trim();
    return description == null || description.isEmpty ? typeLabel : '$typeLabel · $description';
  } on FormatException {
    return l10n.genericError;
  } on TypeError {
    return l10n.genericError;
  }
}
