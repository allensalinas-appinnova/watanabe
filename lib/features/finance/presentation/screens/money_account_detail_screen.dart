import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/financial_operation.dart';
import '../providers/canonical_finance_providers.dart';

class MoneyAccountDetailScreen extends ConsumerStatefulWidget {
  const MoneyAccountDetailScreen({required this.accountId, super.key});
  final String accountId;

  @override
  ConsumerState<MoneyAccountDetailScreen> createState() => _MoneyAccountDetailScreenState();
}

class _MoneyAccountDetailScreenState extends ConsumerState<MoneyAccountDetailScreen> {
  late final List<String> _accountIds = [widget.accountId];

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final accountId = widget.accountId;
    final key = (userId: uid, accountId: accountId);
    final account = ref.watch(canonicalAccountProvider(key));
    final pageKey = (
      userId: uid,
      cursor: null,
      monthKey: null,
      currency: null,
      type: null,
      accountIds: _accountIds,
      pageSize: 10,
    );
    final operations = ref.watch(canonicalOperationsPageProvider(pageKey));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: FinanceRouteHeader(
        title: l10n.accountDetailTitle,
        backLabel: l10n.back,
        onBack: () => popOrGo(context, '/accounts'),
      ),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _loadError(context, l10n.genericError, l10n.retry, () {
          ref.invalidate(canonicalAccountProvider(key));
        }),
        data: (value) {
          if (value == null) return Center(child: Text(l10n.genericError));
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Text(
                value.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${value.currency} · ${_accountTypeLabel(l10n, value.type)}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.currentBalance, style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 8),
                      Text(
                        CurrencyFormatter.formatMinor(value.currentBalanceMinor, value.currency),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        context.push('/operations/new?type=expense&accountId=$accountId'),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: Text(l10n.addExpense),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        context.push('/operations/new?type=income&accountId=$accountId'),
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(l10n.addIncome),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/transfers/new?sourceAccountId=$accountId'),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(l10n.moveMoney),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.pushNamed<void>(
                      'edit-account',
                      pathParameters: {'id': accountId},
                      extra: value,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.editAccount),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                l10n.recentActivity,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              operations.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => _loadError(context, l10n.genericError, l10n.retry, () {
                  ref.invalidate(canonicalOperationsPageProvider(pageKey));
                }),
                data: (page) => page.items.isEmpty
                    ? Text(l10n.noTransactions, style: const TextStyle(color: AppColors.muted))
                    : Column(
                        children: [
                          for (final item in page.items)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                item.type == OperationType.income
                                    ? Icons.south_west
                                    : item.type == OperationType.transfer
                                    ? Icons.swap_horiz
                                    : Icons.north_east,
                                color: item.type == OperationType.income
                                    ? AppColors.green
                                    : AppColors.blueDark,
                              ),
                              title: Text(
                                item.description.isEmpty
                                    ? _typeLabel(l10n, item)
                                    : item.description,
                              ),
                              subtitle: Text(
                                '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hm().format(item.occurredAt.toLocal())} · ${_typeLabel(l10n, item)}',
                              ),
                              trailing: Text(_signedAmount(item)),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n, FinancialOperation operation) =>
      switch (operation.type) {
        OperationType.income => l10n.income,
        OperationType.expense => l10n.expense,
        OperationType.transfer => l10n.transferOperationLabel,
        OperationType.expenseRefund => l10n.debtRefund,
        OperationType.debtAdjustment => l10n.debtAdjust,
      };

  String _accountTypeLabel(AppLocalizations l10n, String type) => switch (type.toLowerCase()) {
    'cash' || 'wallet' => l10n.cashAccountType,
    'checking' => l10n.checkingAccountType,
    'savings' => l10n.savingsAccountType,
    _ => type,
  };

  String _signedAmount(FinancialOperation operation) {
    final sign = switch (operation.type) {
      OperationType.income || OperationType.expenseRefund => '+',
      OperationType.expense || OperationType.debtAdjustment => '−',
      OperationType.transfer => operation.sourceAccountId == widget.accountId ? '−' : '+',
    };
    return '$sign${CurrencyFormatter.formatMinor(operation.amountMinor, operation.currency)}';
  }

  Widget _loadError(BuildContext context, String message, String retry, VoidCallback onRetry) =>
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            TextButton(onPressed: onRetry, child: Text(retry)),
          ],
        ),
      );
}
