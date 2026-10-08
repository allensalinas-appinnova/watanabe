import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/offline/sync_state.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/finance_components.dart';

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
  String? _idempotencyKey;
  bool saving = false;
  DateTime occurredAt = DateTime.now();

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
        padding: const EdgeInsets.all(24),
        children: [
          FinanceLabeledField(
            label: l10n.sourceAccount,
            child: DropdownButtonFormField<String>(
              initialValue: source,
              decoration: const InputDecoration(),
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
          ),
          const SizedBox(height: 12),
          FinanceLabeledField(
            label: l10n.destinationAccount,
            child: DropdownButtonFormField<String>(
              initialValue: destination,
              decoration: const InputDecoration(),
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
          ),
          const SizedBox(height: 12),
          FinanceLabeledField(
            label: l10n.amount,
            child: TextField(
              key: const ValueKey('transfer_amount'),
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(prefixText: _sourceCurrency(accounts)),
            ),
          ),
          const SizedBox(height: 12),
          FinanceLabeledField(
            label: l10n.date,
            child: Semantics(
              button: true,
              label:
                  '${l10n.date}, ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(occurredAt)}',
              child: InkWell(
                key: const ValueKey('transfer_date_selector'),
                borderRadius: BorderRadius.circular(14),
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    DateFormat.yMMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(occurredAt),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FinanceLabeledField(
            label: l10n.optionalNote,
            child: TextField(controller: note, decoration: const InputDecoration()),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('transfer_confirm'),
            onPressed: saving ? null : () => _reviewAndSave(user.id, accounts),
            child: saving ? const CircularProgressIndicator() : Text(l10n.reviewTransfer),
          ),
        ],
      ),
    );
  }

  String? _sourceCurrency(List<FinanceAccount> accounts) {
    for (final account in accounts) {
      if (account.id == source) return account.currency;
    }
    return null;
  }

  Future<void> _reviewAndSave(String userId, List<FinanceAccount> accounts) async {
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
    final transferAmountMinor = amountMinor;
    final sourceAccount = from;
    final destinationAccount = to;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context).confirmTransfer),
        content: Text(
          '${CurrencyFormatter.formatMinor(transferAmountMinor, sourceAccount.currency)}\n'
          '${sourceAccount.name} → ${destinationAccount.name}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(context).transfer),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => saving = true);
    try {
      final status = await ref
          .read(canonicalActionsProvider)
          .createTransfer(
            userId,
            TransferDraft(
              amountMinor: transferAmountMinor,
              currency: sourceAccount.currency,
              sourceAccountId: sourceAccount.id,
              destinationAccountId: destinationAccount.id,
              occurredAt: occurredAt.toUtc(),
              monthKey: _currentMonthKey(occurredAt),
              description: note.text,
              idempotencyKey: _idempotencyKey ??=
                  '${DateTime.now().microsecondsSinceEpoch}_transfer',
            ),
          );
      if (mounted && status == SyncState.confirmed) {
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == SyncState.rejected
                  ? AppLocalizations.of(context).offlineRejected
                  : AppLocalizations.of(context).savedPending,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).genericError)),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _currentMonthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() => occurredAt = DateTime(selected.year, selected.month, selected.day));
    }
  }
}
