import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_transaction.dart';
import '../providers/finance_providers.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design_assets.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String _typeFilter = 'all';
  String? _selectedAccountId;
  bool _thisMonth = true;

  @override
  Widget build(BuildContext context) => ref
      .watch(authSessionProvider)
      .when(
        loading: () => const Scaffold(body: FinanceLoadingView()),
        error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
        data: (user) {
          if (user == null) return const Scaffold(body: FinanceLoadingView());
          return ref
              .watch(financeAccountsProvider(user.id))
              .when(
                loading: () => const Scaffold(body: FinanceLoadingView()),
                error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
                data: (accounts) => ref
                    .watch(financeTransactionsProvider(user.id))
                    .when(
                      loading: () => const Scaffold(body: FinanceLoadingView()),
                      error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
                      data: (transactions) => _buildActivity(context, accounts, transactions),
                    ),
              );
        },
      );

  Widget _buildActivity(
    BuildContext context,
    List<FinanceAccount> accounts,
    List<FinanceTransaction> transactions,
  ) {
    final now = DateTime.now();
    final filtered = transactions.where((transaction) {
      final accountMatches =
          _selectedAccountId == null || transaction.accountId == _selectedAccountId;
      final typeMatches =
          _typeFilter == 'all' ||
          (_typeFilter == 'income' && transaction.isIncome) ||
          (_typeFilter == 'expense' && !transaction.isIncome);
      final monthMatches =
          !_thisMonth || (transaction.date.year == now.year && transaction.date.month == now.month);
      return accountMatches && typeMatches && monthMatches;
    }).toList();
    final matchingAccounts = accounts.where(
      (account) => account.id == _selectedAccountId,
    );
    final selectedAccount = matchingAccounts.isEmpty ? null : matchingAccounts.first;
    final locale = Localizations.localeOf(context).toString();
    final period = DateFormat('MMMM yyyy', locale).format(now);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('activity_screen'),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                children: [
                  FinanceHeader(
                    eyebrow: 'Transactions',
                    title: 'Activity',
                    actionIcon: Icons.add,
                    actionTooltip: 'Add expense',
                    onAction: () => context.push('/expense/new'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FinancePill(
                          key: const ValueKey('activity_account_filter'),
                          label: selectedAccount?.name ?? 'All accounts',
                          onPressed: () => _selectAccount(accounts),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FinancePill(
                          label: _thisMonth ? 'This month' : 'All time',
                          selected: true,
                          onPressed: () => setState(() => _thisMonth = !_thisMonth),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PopupMenuButton<String>(
                          key: const ValueKey('activity_type_filter'),
                          onSelected: (value) => setState(() => _typeFilter = value),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'all', child: Text('All types')),
                            PopupMenuItem(value: 'income', child: Text('Income')),
                            PopupMenuItem(value: 'expense', child: Text('Expenses')),
                          ],
                          child: FinancePill(
                            label: switch (_typeFilter) {
                              'income' => 'Income',
                              'expense' => 'Expenses',
                              _ => 'All types',
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  FinanceSectionHeading(
                    title: period[0].toUpperCase() + period.substring(1),
                    action: Text(
                      '${filtered.length} transactions',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const _EmptyActivity()
                  else
                    for (final transaction in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _TransactionCard(transaction: transaction),
                      ),
                  const SizedBox(height: 78),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  key: const ValueKey('activity_add_expense_button'),
                  onPressed: () => context.push('/expense/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add transaction'),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const FinanceBottomNavigation(selectedIndex: 1),
    );
  }

  Future<void> _selectAccount(List<FinanceAccount> accounts) async {
    final accountId = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const ListTile(
              title: Text('Filter by account'),
              titleTextStyle: TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            ListTile(
              key: const ValueKey('activity_account_all'),
              title: const Text('All accounts'),
              trailing: _selectedAccountId == null
                  ? const Icon(Icons.check, color: AppColors.blueDark)
                  : null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final account in accounts)
              ListTile(
                key: ValueKey('activity_account_${account.id}'),
                title: Text(account.name),
                subtitle: Text(account.type),
                trailing: _selectedAccountId == account.id
                    ? const Icon(Icons.check, color: AppColors.blueDark)
                    : null,
                onTap: () => Navigator.pop(context, account.id),
              ),
          ],
        ),
      ),
    );
    if (!mounted || accountId == null) return;
    setState(() => _selectedAccountId = accountId.isEmpty ? null : accountId);
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});

  final FinanceTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final color = transaction.isIncome ? AppColors.green : AppColors.orange;
    final date = transaction.date;
    final today = DateTime.now();
    final label = DateUtils.isSameDay(date, today)
        ? 'Today'
        : DateUtils.isSameDay(date, today.subtract(const Duration(days: 1)))
        ? 'Yesterday'
        : DateFormat('MMM d').format(date);

    return Container(
      key: ValueKey('activity_transaction_${transaction.id}'),
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          FinanceIconBadge(
            color: transaction.isIncome ? AppColors.green : color,
            icon: transaction.isIncome ? Icons.north_east : Icons.coffee_outlined,
            asset: FinanceDesignAssets.activity(
              category: transaction.category,
              isIncome: transaction.isIncome,
            ),
            glyph: FinanceDesignAssets.glyph(
              transaction.category,
              isIncome: transaction.isIncome,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.category,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.isIncome ? '+' : '-'}${CurrencyFormatter.cop(transaction.amount)}',
                style: TextStyle(
                  color: transaction.isIncome ? AppColors.green : AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 42),
    child: Column(
      children: [
        Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.muted),
        SizedBox(height: 12),
        Text(
          'No transactions yet',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy),
        ),
        SizedBox(height: 4),
        Text(
          'Add your first transaction to see it here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
}
