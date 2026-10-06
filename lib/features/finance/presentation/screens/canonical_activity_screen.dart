import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/financial_operation.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalActivityScreen extends ConsumerStatefulWidget {
  const CanonicalActivityScreen({super.key});

  @override
  ConsumerState<CanonicalActivityScreen> createState() => _CanonicalActivityScreenState();
}

class _CanonicalActivityScreenState extends ConsumerState<CanonicalActivityScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNearEnd);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreWhenNearEnd)
      ..dispose();
    super.dispose();
  }

  void _loadMoreWhenNearEnd() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 400) {
      final user = ref.read(authSessionProvider).value;
      if (user != null) ref.read(operationsPagerProvider(user.id).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).value;
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final pager = ref.watch(operationsPagerProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activity),
        actions: [
          IconButton(
            tooltip: l10n.retry,
            onPressed: () => ref.read(operationsPagerProvider(user.id).notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: pager.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton.tonal(
            onPressed: () => ref.read(operationsPagerProvider(user.id).notifier).refresh(),
            child: Text(l10n.retry),
          ),
        ),
        data: (page) => page.items.isEmpty
            ? Center(child: Text(l10n.noTransactions))
            : RefreshIndicator(
                onRefresh: () => ref.read(operationsPagerProvider(user.id).notifier).refresh(),
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: page.items.length + (page.hasMore || page.isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, index) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    if (index >= page.items.length) {
                      return page.errorMessage == null
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : TextButton(
                              onPressed: () =>
                                  ref.read(operationsPagerProvider(user.id).notifier).loadMore(),
                              child: Text(l10n.retry),
                            );
                    }
                    return _ActivityOperationTile(operation: page.items[index]);
                  },
                ),
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          if (index == 0) context.go('/home');
          if (index == 2) context.go('/budgets');
          if (index == 3) context.go('/accounts');
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: l10n.home),
          NavigationDestination(icon: const Icon(Icons.list_alt), label: l10n.activity),
          NavigationDestination(icon: const Icon(Icons.pie_chart_outline), label: l10n.budget),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: l10n.accounts,
          ),
        ],
      ),
    );
  }
}

class _ActivityOperationTile extends StatelessWidget {
  const _ActivityOperationTile({required this.operation});

  final FinancialOperation operation;

  @override
  Widget build(BuildContext context) {
    final isIncome = operation.type == OperationType.income;
    final isTransfer = operation.type == OperationType.transfer;
    final amount = NumberFormat.currency(
      name: operation.currency,
      decimalDigits: 0,
    ).format(operation.amountMinor);
    return Card(
      child: ListTile(
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
              : '-'}$amount',
          style: TextStyle(color: isIncome ? Colors.green.shade700 : null),
        ),
      ),
    );
  }
}
