import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/category_budget.dart';
import '../../domain/entities/finance_transaction.dart';
import '../providers/finance_providers.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design_assets.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(authSessionProvider)
      .when(
        loading: () => const Scaffold(body: FinanceLoadingView()),
        error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
        data: (user) {
          if (user == null) return const Scaffold(body: FinanceLoadingView());
          return ref
              .watch(financeBudgetsProvider(user.id))
              .when(
                loading: () => const Scaffold(body: FinanceLoadingView()),
                error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
                data: (budgets) => ref
                    .watch(financeTransactionsProvider(user.id))
                    .when(
                      loading: () => const Scaffold(body: FinanceLoadingView()),
                      error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
                      data: (transactions) =>
                          _buildBudgets(context, ref, user.id, budgets, transactions),
                    ),
              );
        },
      );

  Widget _buildBudgets(
    BuildContext context,
    WidgetRef ref,
    String userId,
    List<CategoryBudget> budgets,
    List<FinanceTransaction> transactions,
  ) {
    final totalSpent = budgets.fold<double>(0, (sum, budget) => sum + budget.spent);
    final totalLimit = budgets.fold<double>(0, (sum, budget) => sum + budget.limit);
    final categoriesWithBudget = budgets.map((budget) => budget.category).toSet();
    final unbudgetedCount = transactions
        .where((item) => !item.isIncome && !categoriesWithBudget.contains(item.category))
        .map((item) => item.category)
        .toSet()
        .length;
    final now = DateTime.now();
    final period = DateFormatMonth.monthYear(now);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const ValueKey('budgets_screen'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            FinanceHeader(
              eyebrow: period,
              title: 'Budget planner',
              actionIcon: Icons.more_horiz,
              actionTooltip: 'Budget options',
              onAction: () => _showEditBudgetLimitsDialog(
                context,
                ref,
                userId,
                budgets,
              ),
            ),
            const SizedBox(height: 20),
            _BudgetHealthCard(spent: totalSpent, limit: totalLimit),
            const SizedBox(height: 26),
            FinanceSectionHeading(
              title: 'Category budgets',
              action: TextButton(
                key: const ValueKey('budget_edit_button'),
                onPressed: () => _showEditBudgetLimitsDialog(
                  context,
                  ref,
                  userId,
                  budgets,
                ),
                child: const Text('Edit'),
              ),
            ),
            const SizedBox(height: 8),
            if (budgets.isEmpty)
              const _EmptyBudgets()
            else
              for (final budget in budgets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _BudgetCategoryCard(budget: budget),
                ),
            if (unbudgetedCount > 0) ...[
              const SizedBox(height: 18),
              _UnbudgetedNotice(count: unbudgetedCount),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const FinanceBottomNavigation(selectedIndex: 2),
    );
  }

  Future<void> _showEditBudgetLimitsDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    List<CategoryBudget> budgets,
  ) async {
    if (budgets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a category budget before editing limits.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _EditBudgetLimitsDialog(
        budgets: budgets,
        onSave: (limits) async {
          final result = await ref.read(updateBudgetLimitsProvider).call(userId, limits);
          return result.match((failure) => failure.message, (_) => null);
        },
      ),
    );
  }
}

class _EditBudgetLimitsDialog extends StatefulWidget {
  const _EditBudgetLimitsDialog({required this.budgets, required this.onSave});

  final List<CategoryBudget> budgets;
  final Future<String?> Function(Map<String, double> limitsByBudgetId) onSave;

  @override
  State<_EditBudgetLimitsDialog> createState() => _EditBudgetLimitsDialogState();
}

class _EditBudgetLimitsDialogState extends State<_EditBudgetLimitsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final budget in widget.budgets)
        budget.id: TextEditingController(text: budget.limit.toStringAsFixed(0)),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit category budgets'),
    content: SizedBox(
      width: 360,
      height: 320,
      child: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView.separated(
                itemCount: widget.budgets.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final budget = widget.budgets[index];
                  return TextFormField(
                    key: ValueKey('budget_limit_field_${budget.id}'),
                    controller: _controllers[budget.id],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '${budget.category} monthly limit',
                      prefixText: r'$ ',
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      return parsed != null && parsed >= 0
                          ? null
                          : 'Enter a valid non-negative amount.';
                    },
                  );
                },
              ),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isSaving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('budget_save_button'),
        onPressed: _isSaving ? null : _save,
        child: _isSaving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save changes'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final limits = {
      for (final budget in widget.budgets) budget.id: double.parse(_controllers[budget.id]!.text),
    };
    final error = await widget.onSave(limits);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isSaving = false;
        _errorMessage = error;
      });
      return;
    }
    Navigator.pop(context);
  }
}

class DateFormatMonth {
  static String monthYear(DateTime date) => '${_months[date.month - 1].toUpperCase()} ${date.year}';

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}

class _BudgetHealthCard extends StatelessWidget {
  const _BudgetHealthCard({required this.spent, required this.limit});

  final double spent;
  final double limit;

  @override
  Widget build(BuildContext context) {
    final progress = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    return Container(
      key: const ValueKey('budget_health_card'),
      height: 116,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      decoration: BoxDecoration(color: AppColors.blueSoft, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MONTHLY SPENDING',
            style: TextStyle(color: AppColors.blueDark, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '${CurrencyFormatter.cop(spent)} / ${CurrencyFormatter.cop(limit)}',
            key: const ValueKey('budget_monthly_total'),
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: AppColors.blueDark,
              backgroundColor: Colors.white,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(progress * 100).round()}% used',
              style: const TextStyle(
                color: AppColors.blueDark,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCategoryCard extends StatelessWidget {
  const _BudgetCategoryCard({required this.budget});

  final CategoryBudget budget;

  @override
  Widget build(BuildContext context) {
    final color = Color(budget.colorValue);
    final progress = budget.limit <= 0 ? 0.0 : (budget.spent / budget.limit).clamp(0.0, 1.0);
    return Container(
      key: ValueKey('budget_category_${budget.id}'),
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          FinanceIconBadge(
            color: color.withValues(alpha: .14),
            icon: Icons.circle,
            size: 36,
            asset: FinanceDesignAssets.budget(budget.category),
            glyph: '●',
            glyphColor: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  budget.category,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${CurrencyFormatter.cop(budget.spent)} / ${CurrencyFormatter.cop(budget.limit)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 68,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                color: color,
                backgroundColor: AppColors.line,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnbudgetedNotice extends StatelessWidget {
  const _UnbudgetedNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF2D9),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.priority_high, color: AppColors.orange),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count categories are unbudgeted',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text('Review now', style: TextStyle(color: AppColors.orange, fontSize: 11)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 46),
    child: Column(
      children: [
        Icon(Icons.savings_outlined, size: 36, color: AppColors.muted),
        SizedBox(height: 12),
        Text(
          'No category budgets yet',
          style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 4),
        Text(
          'Your monthly spending plan will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
}
