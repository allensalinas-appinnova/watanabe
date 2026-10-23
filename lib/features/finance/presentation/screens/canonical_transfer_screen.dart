import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/offline/sync_state.dart';
import '../../../../core/routing/discard_changes_scope.dart';
import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/finance_input_validators.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../models/movement_save_result.dart';
import '../models/picker_usage_order.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/finance_account_option.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_popup_selector.dart';

class CanonicalTransferScreen extends ConsumerStatefulWidget {
  const CanonicalTransferScreen({super.key, this.initialSourceAccountId, this.initialOccurredAt});

  final String? initialSourceAccountId;
  final DateTime? initialOccurredAt;
  @override
  ConsumerState<CanonicalTransferScreen> createState() => _CanonicalTransferScreenState();
}

class _CanonicalTransferScreenState extends ConsumerState<CanonicalTransferScreen> {
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController();
  final note = TextEditingController();
  String? source;
  String? destination;
  String? _idempotencyKey;
  bool saving = false;
  bool _hasUnsavedChanges = false;
  DateTime occurredAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    source = widget.initialSourceAccountId;
    occurredAt = widget.initialOccurredAt ?? occurredAt;
    amount.addListener(_markChanged);
    note.addListener(_markChanged);
  }

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
        (ref.watch(canonicalAccountsProvider(user.id)).valueOrNull ?? const <FinanceAccount>[])
            .where((a) => !a.isDebt)
            .toList();
    final recentOperations =
        ref.watch(canonicalRecentOperationsProvider(user.id)).valueOrNull ??
        const <FinancialOperation>[];
    final accountUsageOrder = orderPickerOptionsByUsage(
      options: accounts,
      recentOperations: recentOperations,
      idOf: (account) => account.id,
      usageIdsOf: accountUsageIds,
      compareAlphabetically: (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    return DiscardChangesScope(
      isDirty: _hasUnsavedChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.back,
            onPressed: () => popOrGo(context, '/accounts'),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(l10n.transferMoney),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FinanceLabeledField(
                    label: l10n.sourceAccount,
                    child: FinancePopupSelector<String>(
                      key: ValueKey('transfer_source_selector_${source ?? 'none'}'),
                      controlKey: ValueKey('transfer_source_selector_${source ?? 'none'}_tap'),
                      title: l10n.sourceAccount,
                      placeholder: l10n.selectionChoosePrompt,
                      initialValue: source,
                      options: accountUsageOrder.ordered
                          .map((account) => account.id)
                          .toList(growable: false),
                      frequentOptions: accountUsageOrder.frequent
                          .map((account) => account.id)
                          .toList(growable: false),
                      optionLabel: (id) => financeAccountSelectionLabel(
                        accounts.firstWhere((account) => account.id == id),
                        l10n,
                      ),
                      searchText: (id) => financeAccountSelectionLabel(
                        accounts.firstWhere((account) => account.id == id),
                        l10n,
                      ),
                      optionBuilder: (context, id) => FinanceAccountOption(
                        account: accounts.firstWhere((account) => account.id == id),
                      ),
                      validator: (value) => value == null ? l10n.transferSourceRequired : null,
                      onSelected: (value) => setState(() {
                        source = value;
                        _hasUnsavedChanges = true;
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FinanceLabeledField(
                    label: l10n.destinationAccount,
                    child: FinancePopupSelector<String>(
                      key: ValueKey('transfer_destination_selector_${destination ?? 'none'}'),
                      controlKey: ValueKey(
                        'transfer_destination_selector_${destination ?? 'none'}_tap',
                      ),
                      title: l10n.destinationAccount,
                      placeholder: l10n.selectionChoosePrompt,
                      initialValue: destination,
                      options: accountUsageOrder.ordered
                          .map((account) => account.id)
                          .toList(growable: false),
                      frequentOptions: accountUsageOrder.frequent
                          .map((account) => account.id)
                          .toList(growable: false),
                      optionLabel: (id) => financeAccountSelectionLabel(
                        accounts.firstWhere((account) => account.id == id),
                        l10n,
                      ),
                      searchText: (id) => financeAccountSelectionLabel(
                        accounts.firstWhere((account) => account.id == id),
                        l10n,
                      ),
                      optionBuilder: (context, id) => FinanceAccountOption(
                        account: accounts.firstWhere((account) => account.id == id),
                      ),
                      validator: (value) {
                        if (value == null) return l10n.transferDestinationRequired;
                        FinanceAccount? sourceAccount;
                        FinanceAccount? destinationAccount;
                        for (final account in accounts) {
                          if (account.id == source) sourceAccount = account;
                          if (account.id == value) destinationAccount = account;
                        }
                        if (value == source ||
                            sourceAccount == null ||
                            destinationAccount == null ||
                            sourceAccount.currency != destinationAccount.currency) {
                          return l10n.transferAccountsDifferent;
                        }
                        return null;
                      },
                      onSelected: (value) => setState(() {
                        destination = value;
                        _hasUnsavedChanges = true;
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FinanceLabeledField(
                    label: l10n.amount,
                    child: TextFormField(
                      key: const ValueKey('transfer_amount'),
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: _sourceCurrency(accounts) == null
                            ? null
                            : CurrencyFormatter.inputPrefix(_sourceCurrency(accounts)!),
                      ),
                      validator: (value) {
                        final currency = _sourceCurrency(accounts);
                        return currency == null
                            ? l10n.transferSourceRequired
                            : FinanceInputValidators.amount(value, currency, l10n);
                      },
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
                    label: l10n.time,
                    child: Semantics(
                      button: true,
                      label: '${l10n.time}, ${TimeOfDay.fromDateTime(occurredAt).format(context)}',
                      child: InkWell(
                        key: const ValueKey('transfer_time_selector'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: _selectTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            suffixIcon: Icon(Icons.schedule_outlined),
                          ),
                          child: Text(TimeOfDay.fromDateTime(occurredAt).format(context)),
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
            ),
          ],
        ),
      ),
    );
  }

  void _markChanged() {
    if (!_hasUnsavedChanges && mounted) setState(() => _hasUnsavedChanges = true);
  }

  Future<void> _popAfterSave(Object result) async {
    if (!mounted) return;
    setState(() => _hasUnsavedChanges = false);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) context.pop(result);
  }

  String? _sourceCurrency(List<FinanceAccount> accounts) {
    for (final account in accounts) {
      if (account.id == source) return account.currency;
    }
    return null;
  }

  Future<void> _reviewAndSave(String userId, List<FinanceAccount> accounts) async {
    if (!formKey.currentState!.validate()) return;
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
    if (amountMinor == null || from == null || to == null) return;
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
      if (mounted && (status == SyncState.confirmed || status == SyncState.pending)) {
        await _popAfterSave(
          MovementSaveResult(
            type: OperationType.transfer,
            status: status == SyncState.confirmed
                ? MovementSaveStatus.confirmed
                : MovementSaveStatus.pending,
            amountMinor: transferAmountMinor,
            currency: sourceAccount.currency,
            idempotencyKey: _idempotencyKey!,
            occurredAt: occurredAt,
            description: note.text,
            sourceAccountName: sourceAccount.name,
            destinationAccountName: destinationAccount.name,
          ),
        );
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
      setState(
        () => occurredAt = DateTime(
          selected.year,
          selected.month,
          selected.day,
          occurredAt.hour,
          occurredAt.minute,
        ),
      );
    }
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(occurredAt),
    );
    if (selected != null && mounted) {
      setState(
        () => occurredAt = DateTime(
          occurredAt.year,
          occurredAt.month,
          occurredAt.day,
          selected.hour,
          selected.minute,
        ),
      );
    }
  }
}
