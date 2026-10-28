import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/offline/pending_operation_queue.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/account_balance_adjustment_sheet.dart';

class CanonicalAccountsScreen extends ConsumerStatefulWidget {
  const CanonicalAccountsScreen({this.initialSection, super.key});
  final String? initialSection;

  @override
  ConsumerState<CanonicalAccountsScreen> createState() => _CanonicalAccountsScreenState();
}

class _CanonicalAccountsScreenState extends ConsumerState<CanonicalAccountsScreen> {
  late String _section = _validSection(widget.initialSection);

  @override
  void didUpdateWidget(CanonicalAccountsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection && widget.initialSection != null) {
      _section = _validSection(widget.initialSection);
    }
  }

  String _validSection(String? value) =>
      const {'overview', 'money', 'cards', 'loans'}.contains(value) ? value! : 'overview';

  List<FinanceAccount> _visibleAccounts(List<FinanceAccount> items) => switch (_section) {
    'money' => items.where((item) => !item.isDebt).toList(),
    'cards' => items.where((item) => item.isCreditCard).toList(),
    'loans' => items.where((item) => item.isDebt && !item.isCreditCard).toList(),
    _ => items,
  };

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final user = ref.watch(authSessionProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final accounts = ref.watch(canonicalAccountsProvider(user.id));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.accountsTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.accountsSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _sectionChip(l10n.accountsSectionOverview, 'overview'),
                    _sectionChip(l10n.accountsSectionMoney, 'money'),
                    _sectionChip(l10n.accountsSectionCards, 'cards'),
                    _sectionChip(l10n.accountsSectionLoans, 'loans'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              accounts.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => _AccountsError(
                  message: l10n.genericError,
                  retryLabel: l10n.retry,
                  onRetry: () => ref.invalidate(canonicalAccountsProvider(user.id)),
                ),
                data: (allItems) {
                  final items = _visibleAccounts(allItems);
                  return allItems.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            l10n.createFirstAccount,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            l10n.accountsSectionEmpty,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (var index = 0; index < items.length; index++) ...[
                              if (index > 0) const SizedBox(height: 18),
                              if (index == 0 ||
                                  items[index].isDebt != items[index - 1].isDebt ||
                                  items[index].isCreditCard != items[index - 1].isCreditCard)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      items[index].isCreditCard
                                          ? l10n.debtCards
                                          : items[index].isDebt
                                          ? l10n.debtLoans
                                          : l10n.debtMoney,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                ),
                              _AccountCard(
                                account: items[index],
                                subtitle: _accountSubtitle(l10n, items[index]),
                                balance: CurrencyFormatter.formatMinor(
                                  items[index].isDebt
                                      ? (items[index].creditBalanceMinor > 0
                                            ? items[index].creditBalanceMinor
                                            : items[index].debtMinor)
                                      : items[index].currentBalanceMinor,
                                  items[index].currency,
                                ),
                                editLabel: items[index].isDebt ? l10n.debtTitle : l10n.editAccount,
                                archiveLabel: l10n.archive,
                                adjustBalanceLabel: l10n.adjustAccountBalance,
                                onEdit: () => _editAccount(context, items[index]),
                                onOpen: () => _openAccount(context, items[index]),
                                onAdjustBalance:
                                    items[index].status == 'active' && !items[index].isDebt
                                    ? () => _adjustBalance(
                                        context,
                                        ref,
                                        user.id,
                                        items[index],
                                        items,
                                      )
                                    : null,
                                onArchive: () => items[index].isDebt
                                    ? context.push('/debts/${items[index].id}/actions/archive')
                                    : _archiveAccount(context, ref, user.id, items[index]),
                              ),
                            ],
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildAddAction(context, l10n),
    );
  }

  Widget _buildAddAction(BuildContext context, AppLocalizations l10n) {
    final (label, icon) = switch (_section) {
      'cards' => (l10n.addCreditCard, Icons.credit_card_outlined),
      'loans' => (l10n.addLoan, Icons.account_balance_outlined),
      'overview' => (l10n.accountsAddEntry, Icons.add),
      _ => (l10n.addAccount, Icons.add),
    };
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 8),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('accounts_add_button'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => _openCreateAction(context),
            icon: Icon(icon),
            label: Text(label),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateAction(BuildContext context) async {
    switch (_section) {
      case 'money':
        _showCreate(context);
      case 'cards':
        await context.push('/debts/new?product=creditCard');
      case 'loans':
        await context.push('/debts/new?product=bankLoan');
      default:
        final type = await showModalBottomSheet<String>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          builder: (sheetContext) {
            final l10n = AppLocalizations.of(sheetContext);
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.addMovementChoiceTitle, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _CreateChoice(
                    key: const ValueKey('accounts_create_money'),
                    icon: Icons.account_balance_wallet_outlined,
                    label: l10n.addAccount,
                    onTap: () => Navigator.of(sheetContext).pop('money'),
                  ),
                  _CreateChoice(
                    key: const ValueKey('accounts_create_card'),
                    icon: Icons.credit_card_outlined,
                    label: l10n.debtCreditCard,
                    onTap: () => Navigator.of(sheetContext).pop('card'),
                  ),
                  _CreateChoice(
                    key: const ValueKey('accounts_create_loan'),
                    icon: Icons.account_balance_outlined,
                    label: l10n.debtLoans,
                    onTap: () => Navigator.of(sheetContext).pop('loan'),
                  ),
                ],
              ),
            );
          },
        );
        if (!context.mounted || type == null) return;
        if (type == 'money') {
          _showCreate(context);
        } else if (type == 'card') {
          await context.push('/debts/new?product=creditCard');
        } else {
          await context.push('/debts/new?product=bankLoan');
        }
    }
  }

  Widget _sectionChip(String label, String section) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _section == section,
      onSelected: (_) => setState(() => _section = section),
    ),
  );

  String _accountSubtitle(AppLocalizations l10n, FinanceAccount account) {
    final typeLabel = switch (account.type.toLowerCase()) {
      'cash' || 'wallet' => l10n.cashAccountType,
      'checking' => l10n.checkingAccountType,
      'savings' => l10n.savingsAccountType,
      'creditcard' => l10n.debtCreditCard,
      'bankloan' => l10n.debtBankLoan,
      'personalloan' => l10n.debtPersonalLoan,
      _ => account.type,
    };
    return '${account.currency} · $typeLabel${account.creditBalanceMinor > 0 ? ' · ${l10n.debtCreditBalance}' : ''}';
  }

  void _showCreate(BuildContext context) {
    unawaited(context.pushNamed<void>('new-account'));
  }

  void _editAccount(
    BuildContext context,
    FinanceAccount account,
  ) async {
    if (account.isDebt) {
      await context.push('/accounts/${account.id}/debt');
      return;
    }
    await context.pushNamed<void>(
      'edit-account',
      pathParameters: {'id': account.id},
      extra: account,
    );
  }

  void _openAccount(BuildContext context, FinanceAccount account) {
    if (account.isDebt) {
      context.push('/accounts/${account.id}/debt');
    } else {
      context.push('/accounts/${account.id}');
    }
  }

  Future<void> _adjustBalance(
    BuildContext context,
    WidgetRef ref,
    String userId,
    FinanceAccount account,
    List<FinanceAccount> accounts,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AccountBalanceAdjustmentSheet(
        userId: userId,
        initialAccount: account,
        accounts: accounts
            .where((item) => item.status == 'active' && !item.isDebt)
            .toList(growable: false),
        repository: ref.read(canonicalFinanceRepositoryProvider),
        loadActiveOperations: () => getIt<PendingOperationDatabase>().watchActive().first,
      ),
    );
    if (changed == true) ref.invalidate(canonicalAccountsProvider(userId));
  }

  Future<void> _archiveAccount(
    BuildContext context,
    WidgetRef ref,
    String userId,
    FinanceAccount account,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.archive),
        content: Text(l10n.confirmArchiveAccount),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.archive),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await ref
          .read(canonicalFinanceRepositoryProvider)
          .archiveAccount(userId, account.id);
      result.match(
        (_) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError)),
        ),
        (_) {},
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError)),
        );
      }
    }
  }
}

class _CreateChoice extends StatelessWidget {
  const _CreateChoice({required this.icon, required this.label, required this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(label),
    minTileHeight: 56,
    onTap: onTap,
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.subtitle,
    required this.balance,
    required this.editLabel,
    required this.archiveLabel,
    required this.adjustBalanceLabel,
    required this.onEdit,
    required this.onOpen,
    required this.onAdjustBalance,
    required this.onArchive,
  });

  final FinanceAccount account;
  final String subtitle;
  final String balance;
  final String editLabel;
  final String archiveLabel;
  final String adjustBalanceLabel;
  final VoidCallback onEdit;
  final VoidCallback onOpen;
  final VoidCallback? onAdjustBalance;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('account_row_${account.id}'),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 82,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 17, end: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                balance,
                key: ValueKey('account_balance_${account.id}'),
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('account_menu_${account.id}'),
                tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                iconSize: 19,
                icon: Icon(
                  Icons.more_vert,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onSelected: (action) {
                  if (action == 'edit') onEdit();
                  if (action == 'adjust') onAdjustBalance?.call();
                  if (action == 'archive') onArchive();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    key: const ValueKey('account_adjust_balance_action'),
                    value: 'adjust',
                    enabled: onAdjustBalance != null,
                    child: Text(adjustBalanceLabel),
                  ),
                  PopupMenuItem(
                    key: const ValueKey('account_edit_action'),
                    value: 'edit',
                    child: Text(editLabel),
                  ),
                  PopupMenuItem(
                    key: const ValueKey('account_archive_action'),
                    value: 'archive',
                    child: Text(archiveLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AccountsError extends StatelessWidget {
  const _AccountsError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    ),
  );
}
