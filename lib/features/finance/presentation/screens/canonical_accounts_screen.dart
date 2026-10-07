import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalAccountsScreen extends ConsumerWidget {
  const CanonicalAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final accounts = ref.watch(canonicalAccountsProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accounts)),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.genericError)),
        data: (items) => items.isEmpty
            ? Center(child: Text(l10n.createFirstAccount))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final account = items[index];
                  return Card(
                    key: ValueKey('account_row_${account.id}'),
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet),
                      title: Text(account.name),
                      subtitle: Text('${account.type} · ${account.currency}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            CurrencyFormatter.formatMinor(
                              account.currentBalanceMinor,
                              account.currency,
                            ),
                            key: ValueKey('account_balance_${account.id}'),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'edit') {
                                _editAccount(context, ref, user.id, account);
                              }
                              if (action == 'archive') {
                                _archiveAccount(context, ref, user.id, account);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'edit', child: Text(l10n.editAccount)),
                              PopupMenuItem(value: 'archive', child: Text(l10n.archive)),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: false,
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('accounts_add_button'),
        onPressed: () => _showCreate(context, ref, user.id),
        icon: const Icon(Icons.add),
        label: const Text('Cuenta'),
      ),
    );
  }

  Future<void> _showCreate(BuildContext context, WidgetRef ref, String userId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CreateAccountDialog(userId: userId),
    );
  }

  Future<void> _editAccount(
    BuildContext context,
    WidgetRef ref,
    String userId,
    FinanceAccount account,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController(text: account.name);
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.editAccount),
          content: TextField(
            controller: name,
            decoration: InputDecoration(labelText: l10n.accountName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      );
      if (save == true && name.text.trim().isNotEmpty) {
        final result = await ref
            .read(canonicalFinanceRepositoryProvider)
            .updateAccount(
              userId,
              FinanceAccount(
                id: account.id,
                name: name.text.trim(),
                type: account.type,
                currency: account.currency,
                openingBalanceMinor: account.openingBalanceMinor,
                currentBalanceMinor: account.currentBalanceMinor,
                includeInDashboard: account.includeInDashboard,
                status: account.status,
                createdAt: account.createdAt,
                updatedAt: account.updatedAt,
                archivedAt: account.archivedAt,
              ),
            );
        result.match(
          (_) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.genericError)),
          ),
          (_) {},
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError)),
        );
      }
    } finally {
      name.dispose();
    }
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

class _CreateAccountDialog extends ConsumerStatefulWidget {
  const _CreateAccountDialog({required this.userId});

  final String userId;

  @override
  ConsumerState<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends ConsumerState<_CreateAccountDialog> {
  final _name = TextEditingController();
  final _initial = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(AppLocalizations.of(context).newAccount),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('account_name_field'),
          controller: _name,
          decoration: InputDecoration(labelText: AppLocalizations.of(context).accountName),
        ),
        TextField(
          key: const ValueKey('account_initial_balance_field'),
          controller: _initial,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: AppLocalizations.of(context).initialBalance),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('account_save'),
        onPressed: _saving ? null : _save,
        child: _saving
            ? const CircularProgressIndicator()
            : Text(AppLocalizations.of(context).save),
      ),
    ],
  );

  Future<void> _save() async {
    int openingBalanceMinor;
    try {
      openingBalanceMinor = _initial.text.trim() == '0'
          ? 0
          : MoneyParser.minorUnits(_initial.text, 'COP');
    } on FormatException {
      return;
    }
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(canonicalActionsProvider)
          .createAccount(
            widget.userId,
            name: _name.text,
            type: 'cash',
            currency: 'COP',
            openingBalanceMinor: openingBalanceMinor,
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
