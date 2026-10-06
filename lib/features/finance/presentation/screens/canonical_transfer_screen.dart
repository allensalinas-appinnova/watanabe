import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalTransferScreen extends ConsumerStatefulWidget {
  const CanonicalTransferScreen({super.key});
  @override
  ConsumerState<CanonicalTransferScreen> createState() => _CanonicalTransferScreenState();
}

class _CanonicalTransferScreenState extends ConsumerState<CanonicalTransferScreen> {
  final amount = TextEditingController();
  final note = TextEditingController();
  String? source;
  String? destination;
  bool saving = false;

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final accounts =
        ref.watch(canonicalAccountsProvider(user.id)).valueOrNull ?? const <FinanceAccount>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.transferMoney)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            initialValue: source,
            decoration: InputDecoration(labelText: l10n.sourceAccount),
            items: accounts
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text('${item.name} (${item.currency})'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => source = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: destination,
            decoration: InputDecoration(labelText: l10n.destinationAccount),
            items: accounts
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text('${item.name} (${item.currency})'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => destination = value),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('transfer_amount'),
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.amount),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: InputDecoration(labelText: l10n.optionalNote),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('transfer_confirm'),
            onPressed: saving ? null : () => _save(user.id, accounts),
            child: saving ? const CircularProgressIndicator() : Text(l10n.confirmTransfer),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String userId, List<FinanceAccount> accounts) async {
    FinanceAccount? from;
    FinanceAccount? to;
    for (final account in accounts) {
      if (account.id == source) from = account;
      if (account.id == destination) to = account;
    }
    int? amountMinor;
    try {
      amountMinor = from == null ? null : MoneyParser.minorUnits(amount.text, from.currency);
    } on FormatException {
      amountMinor = null;
    }
    if (amountMinor == null ||
        from == null ||
        to == null ||
        source == destination ||
        from.currency != to.currency) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).invalidTransfer)),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final synced = await ref
          .read(canonicalActionsProvider)
          .createTransfer(
            userId,
            TransferDraft(
              amountMinor: amountMinor,
              currency: from.currency,
              sourceAccountId: source!,
              destinationAccountId: destination!,
              occurredAt: DateTime.now().toUtc(),
              monthKey: _currentMonthKey(),
              description: note.text,
              idempotencyKey: '${DateTime.now().microsecondsSinceEpoch}_transfer',
            ),
          );
      if (mounted && synced) {
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).offlineRejected)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }
}
