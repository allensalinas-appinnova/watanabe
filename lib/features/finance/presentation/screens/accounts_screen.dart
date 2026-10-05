import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/repositories/finance_repository.dart';
import '../providers/finance_providers.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design_assets.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
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
                data: (accounts) => _buildAccounts(context, ref, user.id, accounts),
              );
        },
      );

  Widget _buildAccounts(
    BuildContext context,
    WidgetRef ref,
    String userId,
    List<FinanceAccount> accounts,
  ) {
    final total = accounts.fold<double>(0, (sum, account) => sum + account.balance);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const ValueKey('accounts_screen'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            FinanceHeader(
              eyebrow: 'Your money',
              title: 'Accounts',
              actionIcon: Icons.add,
              actionTooltip: 'Add account',
              onAction: () => _showAddAccountDialog(context, ref, userId),
            ),
            const SizedBox(height: 20),
            _AccountsTotalCard(total: total, count: accounts.length),
            const SizedBox(height: 26),
            const FinanceSectionHeading(title: 'All accounts'),
            const SizedBox(height: 10),
            if (accounts.isEmpty)
              const _EmptyAccounts()
            else
              for (var index = 0; index < accounts.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _AccountCard(account: accounts[index], index: index),
                ),
            const SizedBox(height: 28),
            OutlinedButton(
              key: const ValueKey('accounts_manage_button'),
              onPressed: () => _showAccountManagement(context, ref, userId, accounts),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: AppColors.blueDark,
                side: const BorderSide(color: AppColors.line),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Manage account settings'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const FinanceBottomNavigation(selectedIndex: 3),
    );
  }

  Future<void> _showAccountManagement(
    BuildContext context,
    WidgetRef ref,
    String userId,
    List<FinanceAccount> accounts,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Manage accounts', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('Add an account first to manage it.'),
                )
              else
                ...accounts.map(
                  (account) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(account.name),
                    subtitle: Text(account.type),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          key: ValueKey('account_edit_${account.id}'),
                          tooltip: 'Edit account',
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            await _showEditAccountDialog(context, ref, userId, account);
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          key: ValueKey('account_delete_${account.id}'),
                          tooltip: 'Delete account',
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Delete account?'),
                                content: Text(
                                  'Deleting “${account.name}” also permanently deletes its transactions and receipt photos. This cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    key: ValueKey('account_confirm_delete_${account.id}'),
                                    onPressed: () => Navigator.pop(dialogContext, true),
                                    child: const Text('Delete account'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !context.mounted) return;
                            try {
                              await ref.read(manageAccountsProvider).delete(userId, account.id);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditAccountDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    FinanceAccount account,
  ) => showDialog<void>(
    context: context,
    builder: (_) => _EditAccountDialog(userId: userId, account: account),
  );

  Future<void> _showAddAccountDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0');
    var accountType = 'Checking';
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add account'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('account_name_field'),
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Account name'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Enter an account name.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: accountType,
                  decoration: const InputDecoration(labelText: 'Account type'),
                  items: const [
                    DropdownMenuItem(value: 'Checking', child: Text('Checking')),
                    DropdownMenuItem(value: 'Savings', child: Text('Savings')),
                    DropdownMenuItem(value: 'Wallet', child: Text('Wallet')),
                    DropdownMenuItem(value: 'Credit card', child: Text('Credit card')),
                  ],
                  onChanged: (value) {
                    if (value != null) accountType = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('account_initial_balance_field'),
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Current balance'),
                  validator: (value) =>
                      double.tryParse(value ?? '') == null ? 'Enter a valid balance.' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              key: const ValueKey('account_save_button'),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await ref
                            .read(createAccountProvider)
                            .call(
                              userId,
                              AccountDraft(
                                name: nameController.text.trim(),
                                type: accountType,
                                balance: double.parse(balanceController.text),
                              ),
                            );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (error) {
                        setDialogState(() => isSaving = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(
                            dialogContext,
                          ).showSnackBar(SnackBar(content: Text(error.toString())));
                        }
                      }
                    },
              child: const Text('Save account'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    balanceController.dispose();
  }
}

class _EditAccountDialog extends ConsumerStatefulWidget {
  const _EditAccountDialog({required this.userId, required this.account});

  final String userId;
  final FinanceAccount account;

  @override
  ConsumerState<_EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends ConsumerState<_EditAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _accountType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.name);
    _accountType = widget.account.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Edit account'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            key: const ValueKey('account_edit_name_field'),
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Account name'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Enter an account name.' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _accountType,
            decoration: const InputDecoration(labelText: 'Account type'),
            items: const [
              DropdownMenuItem(value: 'Checking', child: Text('Checking')),
              DropdownMenuItem(value: 'Savings', child: Text('Savings')),
              DropdownMenuItem(value: 'Wallet', child: Text('Wallet')),
              DropdownMenuItem(value: 'Credit card', child: Text('Credit card')),
              DropdownMenuItem(value: 'Revolving credit', child: Text('Revolving credit')),
              DropdownMenuItem(value: 'Loan', child: Text('Loan')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _accountType = value);
            },
          ),
          const SizedBox(height: 8),
          Text('Balance: ${CurrencyFormatter.cop(widget.account.balance)}'),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        key: const ValueKey('account_update_button'),
        onPressed: _save,
        child: const Text('Save changes'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(manageAccountsProvider)
          .update(
            widget.userId,
            FinanceAccount(
              id: widget.account.id,
              name: _nameController.text.trim(),
              type: _accountType,
              balance: widget.account.balance,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _AccountsTotalCard extends StatelessWidget {
  const _AccountsTotalCard({required this.total, required this.count});

  final double total;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    height: 90,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
    decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(20)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TOTAL ACROSS ACCOUNTS',
          style: TextStyle(color: Color(0xFFA6C7E5), fontSize: 11, fontWeight: FontWeight.w600),
        ),
        Text(
          CurrencyFormatter.cop(total),
          key: const ValueKey('accounts_total_balance'),
          style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w700),
        ),
        Text(
          '$count active accounts',
          style: const TextStyle(color: Color(0xFFB8DED1), fontSize: 11),
        ),
      ],
    ),
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.index});

  final FinanceAccount account;
  final int index;

  static const _colors = [AppColors.blueDark, AppColors.green, AppColors.orange, Color(0xFF6646C2)];

  @override
  Widget build(BuildContext context) {
    final color = account.balance < 0 ? const Color(0xFF6646C2) : _colors[index % _colors.length];
    return Container(
      key: ValueKey('account_${account.id}'),
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          FinanceIconBadge(
            color: color,
            icon: Icons.circle,
            size: 36,
            asset: FinanceDesignAssets.account(account.type),
            glyph: '●',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(account.type, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.cop(account.balance),
            style: TextStyle(
              color: account.balance < 0 ? const Color(0xFFE53935) : AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 42),
    child: Column(
      children: [
        Icon(Icons.account_balance_wallet_outlined, size: 36, color: AppColors.muted),
        SizedBox(height: 12),
        Text(
          'No accounts yet',
          style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 4),
        Text(
          'Create an account to start tracking your money.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
}
