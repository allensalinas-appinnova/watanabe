import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/offline/pending_operation_queue.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../core/utils/request_id.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/balance_adjustment.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/repositories/canonical_finance_repository.dart';

class AccountBalanceAdjustmentSheet extends StatefulWidget {
  const AccountBalanceAdjustmentSheet({
    required this.userId,
    required this.initialAccount,
    required this.accounts,
    required this.repository,
    required this.loadActiveOperations,
    super.key,
  });

  final String userId;
  final FinanceAccount initialAccount;
  final List<FinanceAccount> accounts;
  final CanonicalFinanceRepository repository;
  final Future<List<PendingOperation>> Function() loadActiveOperations;

  @override
  State<AccountBalanceAdjustmentSheet> createState() => _AccountBalanceAdjustmentSheetState();
}

class _AccountBalanceAdjustmentSheetState extends State<AccountBalanceAdjustmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final Map<String, TextEditingController> _balanceControllers = {};
  final Set<String> _selectedIds = {};
  String? _requestId;
  bool _saving = false;
  bool _blockedByPending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedIds.add(widget.initialAccount.id);
    for (final account in widget.accounts) {
      _balanceControllers[account.id] = TextEditingController(
        text: _amountInput(account.currentBalanceMinor, account.currency),
      );
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    for (final controller in _balanceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _amountInput(int minor, String currency) {
    final digits = CurrencyFormatter.decimalDigits(currency);
    if (digits == 0) return minor.toString();
    final divisor = digits == 2 ? 100 : 1;
    final sign = minor < 0 ? '-' : '';
    final value = minor.abs();
    return '$sign${value ~/ divisor}.${(value % divisor).toString().padLeft(digits, '0')}';
  }

  int? _parseTarget(FinanceAccount account) {
    final text = _balanceControllers[account.id]?.text.trim() ?? '';
    final negative = text.startsWith('-');
    final raw = negative ? text.substring(1) : text;
    if (raw.isEmpty || raw.startsWith('+')) return null;
    try {
      final amount = MoneyParser.minorUnits(raw, account.currency, allowZero: true);
      return negative && amount != 0 ? -amount : amount;
    } on FormatException {
      return null;
    }
  }

  Future<bool> _hasPendingForSelectedAccounts() async {
    final rows = await widget.loadActiveOperations();
    for (final row in rows) {
      try {
        final payload = jsonDecode(row.payload) as Map<String, dynamic>;
        final ownerId = payload['ownerUserId'];
        if (ownerId is String && ownerId != widget.userId) continue;
        // A legacy row without owner metadata is ambiguous; conservatively block.
        if (ownerId != widget.userId) return true;
        final affected = <Object?>[
          payload['accountId'],
          payload['sourceAccountId'],
          payload['destinationAccountId'],
        ];
        if (affected.any((id) => id is String && _selectedIds.contains(id))) return true;
      } on Object {
        // An unreadable active queue row cannot be proven unrelated.
        return true;
      }
    }
    return false;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      _blockedByPending = false;
    });
    try {
      if (await _hasPendingForSelectedAccounts()) {
        setState(() {
          _blockedByPending = true;
          _saving = false;
        });
        return;
      }
      final adjustments = widget.accounts
          .where((account) => _selectedIds.contains(account.id))
          .map(
            (account) => BalanceAdjustmentDraft(
              accountId: account.id,
              currency: account.currency,
              targetBalanceMinor: _parseTarget(account)!,
            ),
          )
          .toList(growable: false);
      if (adjustments.every(
        (adjustment) =>
            adjustment.targetBalanceMinor ==
            widget.accounts
                .firstWhere((account) => account.id == adjustment.accountId)
                .currentBalanceMinor,
      )) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).balanceAdjustmentNoop)),
          );
        }
        return;
      }
      _requestId ??= newRequestId();
      final result = await widget.repository.adjustAccountBalances(
        widget.userId,
        requestId: _requestId!,
        adjustments: adjustments,
        reason: _reasonController.text,
      );
      var succeeded = false;
      result.match(
        (_) => _error = AppLocalizations.of(context).genericError,
        (_) => succeeded = true,
      );
      if (!mounted) return;
      if (succeeded) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _saving = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).genericError;
          _saving = false;
        });
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .92),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.balanceAdjustmentTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.balanceAdjustmentSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  _Hint(icon: Icons.devices, text: l10n.balanceAdjustmentOtherDevicesHint),
                  const SizedBox(height: 16),
                  for (final account in widget.accounts) ...[
                    if (account.id != widget.initialAccount.id)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selectedIds.contains(account.id),
                        title: Text(account.name),
                        subtitle: Text(account.currency),
                        onChanged: _saving
                            ? null
                            : (value) => setState(
                                () => value == true
                                    ? _selectedIds.add(account.id)
                                    : _selectedIds.remove(account.id),
                              ),
                      ),
                    if (_selectedIds.contains(account.id)) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${account.name} · ${account.currency}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        l10n.balanceAdjustmentCurrent(
                          CurrencyFormatter.formatMinor(
                            account.currentBalanceMinor,
                            account.currency,
                            locale: Localizations.localeOf(context).toString(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: ValueKey('balance_adjustment_target_${account.id}'),
                        controller: _balanceControllers[account.id],
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))],
                        decoration: InputDecoration(
                          labelText: l10n.balanceAdjustmentTarget,
                          prefixText: '${account.currency} ',
                        ),
                        validator: (_) => _parseTarget(account) == null
                            ? l10n.balanceAdjustmentInvalidAmount
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                      Builder(
                        builder: (context) {
                          final target = _parseTarget(account);
                          if (target == null) return const SizedBox.shrink();
                          final difference = target - account.currentBalanceMinor;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              l10n.balanceAdjustmentDifference(
                                CurrencyFormatter.formatMinor(
                                  difference,
                                  account.currency,
                                  locale: Localizations.localeOf(context).toString(),
                                ),
                              ),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: difference == 0 ? AppColors.muted : AppColors.blueDark,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                  TextFormField(
                    controller: _reasonController,
                    enabled: !_saving,
                    maxLength: 240,
                    decoration: InputDecoration(labelText: l10n.balanceAdjustmentReason),
                  ),
                  if (_blockedByPending) ...[
                    const SizedBox(height: 8),
                    _Hint(
                      icon: Icons.sync_problem,
                      text: l10n.balanceAdjustmentPendingHint,
                      error: true,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    _Hint(icon: Icons.error_outline, text: _error!, error: true),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.balanceAdjustmentSave),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      child: Text(l10n.cancel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, this.error = false});
  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFF0F0) : AppColors.blueSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: error ? const Color(0xFFB3261E) : AppColors.blueDark),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ],
    ),
  );
}
