import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../finance/domain/entities/category_budget.dart';
import '../../../finance/domain/entities/finance_account.dart';
import '../../../finance/domain/entities/finance_transaction.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../finance/presentation/widgets/finance_components.dart';
import '../../../finance/presentation/widgets/finance_design_assets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(authSessionProvider)
      .when(
        loading: () => const Scaffold(body: FinanceLoadingView()),
        error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
        data: (user) {
          if (user == null) return const Scaffold(body: FinanceLoadingView());
          final accounts = ref.watch(financeAccountsProvider(user.id));
          final transactions = ref.watch(financeTransactionsProvider(user.id));
          final budgets = ref.watch(financeBudgetsProvider(user.id));
          return accounts.when(
            loading: () => const Scaffold(body: FinanceLoadingView()),
            error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
            data: (accountData) => transactions.when(
              loading: () => const Scaffold(body: FinanceLoadingView()),
              error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
              data: (transactionData) => budgets.when(
                loading: () => const Scaffold(body: FinanceLoadingView()),
                error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
                data: (budgetData) => _buildDashboard(
                  context,
                  ref,
                  accountData,
                  transactionData,
                  budgetData,
                  user.displayName,
                ),
              ),
            ),
          );
        },
      );

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    List<FinanceAccount> accounts,
    List<FinanceTransaction> transactions,
    List<CategoryBudget> budgets,
    String? displayName,
  ) {
    final now = DateTime.now();
    final monthTransactions = transactions
        .where((item) => item.date.year == now.year && item.date.month == now.month)
        .toList();
    final income = monthTransactions
        .where((item) => item.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final spending = monthTransactions
        .where((item) => !item.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final totalBalance = accounts.fold<double>(0, (sum, account) => sum + account.balance);
    final firstName = displayName?.trim().split(' ').first;
    final greeting = firstName == null || firstName.isEmpty
        ? 'Good morning'
        : 'Good morning, $firstName';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const ValueKey('dashboard_screen'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            FinanceHeader(
              eyebrow: greeting,
              title: 'Your money, clearly.',
              actionIcon: Icons.more_horiz,
              actionTooltip: 'More options',
              onAction: () => _showSignOutMenu(context, ref),
            ),
            const SizedBox(height: 20),
            _BalanceSummary(
              totalBalance: totalBalance,
              income: income,
              spending: spending,
            ),
            const SizedBox(height: 26),
            FinanceSectionHeading(
              title: 'Spending overview',
              action: TextButton(
                onPressed: () => context.go('/budgets'),
                child: const Text('View report'),
              ),
            ),
            const SizedBox(height: 8),
            _SpendingOverview(budgets: budgets),
            const SizedBox(height: 26),
            FinanceSectionHeading(
              title: 'Recent activity',
              action: TextButton(
                onPressed: () => context.go('/activity'),
                child: const Text('See all'),
              ),
            ),
            const SizedBox(height: 8),
            _RecentActivity(items: transactions.take(3).toList()),
          ],
        ),
      ),
      bottomNavigationBar: const FinanceBottomNavigation(selectedIndex: 0),
    );
  }

  void _showSignOutMenu(BuildContext context, WidgetRef ref) {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(180, 75, 12, 0),
      items: const [
        PopupMenuItem(
          key: ValueKey('auth_sign_out_button'),
          value: 'sign-out',
          child: Text('Sign out'),
        ),
      ],
    ).then((action) {
      if (action == 'sign-out') {
        ref.read(authControllerProvider.notifier).signOut();
        if (context.mounted) context.go('/login');
      }
    });
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({
    required this.totalBalance,
    required this.income,
    required this.spending,
  });

  final double totalBalance;
  final double income;
  final double spending;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('dashboard_balance_card'),
    height: 172,
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 11),
    decoration: BoxDecoration(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'TOTAL BALANCE',
                style: TextStyle(
                  color: Color(0xFFA6C7E5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'THIS MONTH',
                style: TextStyle(color: AppColors.navy, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyFormatter.cop(totalBalance),
          key: const ValueKey('dashboard_total_balance'),
          style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 1),
        const Text(
          '↑ 8.4%  vs last month',
          style: TextStyle(color: Color(0xFFB8DED1), fontSize: 12),
        ),
        const Spacer(),
        Container(height: 1, color: const Color(0xFF2E4A66)),
        const SizedBox(height: 9),
        Row(
          children: [
            _SummaryValue(label: 'INCOME', value: income, keyName: 'dashboard_income'),
            const SizedBox(width: 30),
            _SummaryValue(label: 'SPENDING', value: spending, keyName: 'dashboard_spending'),
          ],
        ),
      ],
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value, required this.keyName});

  final String label;
  final double value;
  final String keyName;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFA6C7E5), fontSize: 10)),
        Text(
          CurrencyFormatter.cop(value),
          key: ValueKey(keyName),
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _SpendingOverview extends StatelessWidget {
  const _SpendingOverview({required this.budgets});

  final List<CategoryBudget> budgets;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This month by category',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (budgets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No budgets yet. Add one to track spending by category.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          for (final budget in budgets.take(4)) _SpendingBar(budget: budget),
      ],
    ),
  );
}

class _SpendingBar extends StatelessWidget {
  const _SpendingBar({required this.budget});

  final CategoryBudget budget;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            budget.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: budget.limit <= 0 ? 0 : (budget.spent / budget.limit).clamp(0, 1),
              backgroundColor: AppColors.blueSoft,
              color: Color(budget.colorValue),
            ),
          ),
        ),
      ],
    ),
  );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.items});

  final List<FinanceTransaction> items;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: Column(
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Your recent transactions will appear here.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          for (var index = 0; index < items.length; index++) ...[
            _RecentActivityRow(transaction: items[index]),
            if (index != items.length - 1) const Divider(height: 1, indent: 46),
          ],
      ],
    ),
  );
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({required this.transaction});

  final FinanceTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final color = transaction.isIncome ? AppColors.green : AppColors.orange;
    final icon = transaction.isIncome ? Icons.north_east : Icons.shopping_bag_outlined;
    return SizedBox(
      height: 57,
      child: Row(
        children: [
          FinanceIconBadge(
            color: color,
            icon: icon,
            size: 34,
            asset: FinanceDesignAssets.dashboardActivity(
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
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  transaction.category,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${transaction.isIncome ? '+' : '-'}${CurrencyFormatter.cop(transaction.amount)}',
            style: TextStyle(
              color: transaction.isIncome ? AppColors.green : AppColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
