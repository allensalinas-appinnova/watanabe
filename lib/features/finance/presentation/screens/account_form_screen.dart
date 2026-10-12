import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../providers/canonical_finance_providers.dart';

const _availableCurrencies = ['COP', 'MXN', 'BRL'];

class AccountFormScreen extends ConsumerWidget {
  const AccountFormScreen({super.key, this.accountId, this.initialAccount});

  final String? accountId;
  final FinanceAccount? initialAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));

    final profileAsync = ref.watch(canonicalUserProfileProvider(user.id));
    if (profileAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profileAsync.hasError) {
      return Scaffold(body: Center(child: Text(l10n.genericError)));
    }
    final profile = profileAsync.valueOrNull;
    final profileCurrency = _availableCurrencies.contains(profile?.defaultCurrency)
        ? profile!.defaultCurrency
        : 'COP';
    if (accountId == null) {
      return _AccountForm(
        key: const ValueKey('create_account_form'),
        userId: user.id,
        defaultCurrency: profileCurrency,
      );
    }

    final accounts = ref.watch(canonicalAccountsProvider(user.id));
    FinanceAccount? account = initialAccount;
    for (final item in accounts.asData?.value ?? const <FinanceAccount>[]) {
      if (item.id == accountId) account ??= item;
    }
    if (account == null) {
      final accounts = ref.watch(canonicalAccountsProvider(user.id));
      return Scaffold(
        body: Center(
          child: accounts.when(
            loading: () => const CircularProgressIndicator(),
            error: (_, _) => Text(l10n.genericError),
            data: (_) => Text(l10n.genericError),
          ),
        ),
      );
    }
    return _AccountForm(
      key: ValueKey('edit_account_form_${account.id}'),
      userId: user.id,
      defaultCurrency: profileCurrency,
      account: account,
    );
  }
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({
    super.key,
    required this.userId,
    required this.defaultCurrency,
    this.account,
  });

  final String userId;
  final String defaultCurrency;
  final FinanceAccount? account;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late String _type;
  late String _currency;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _balanceController = TextEditingController(text: '0');
    _type = widget.account?.type ?? 'cash';
    _currency = widget.account?.currency ?? widget.defaultCurrency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const ValueKey('account_cancel'),
                        tooltip: l10n.cancel,
                        onPressed: _saving ? null : _back,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.appTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.blueDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.accounts.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.muted,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isEditing ? l10n.editAccount : l10n.newAccount,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isEditing ? l10n.accountFormEditSubtitle : l10n.accountFormCreateSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          key: const ValueKey('account_name_field'),
                          controller: _nameController,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: _isEditing ? TextInputAction.done : TextInputAction.next,
                          onFieldSubmitted: _isEditing ? (_) => _save() : null,
                          decoration: InputDecoration(
                            labelText: l10n.accountName,
                            hintText: l10n.accountNameHint,
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? l10n.accountNameRequired
                              : null,
                        ),
                        const SizedBox(height: 18),
                        if (_isEditing) ...[
                          _ReadOnlyField(
                            key: const ValueKey('account_type_read_only'),
                            label: l10n.accountType,
                            value: _typeLabel(l10n, widget.account!.type),
                          ),
                          const SizedBox(height: 18),
                          _ReadOnlyField(
                            key: const ValueKey('account_currency_read_only'),
                            label: l10n.accountCurrency,
                            value: widget.account!.currency,
                          ),
                          const SizedBox(height: 18),
                          _ReadOnlyField(
                            key: const ValueKey('account_balance_read_only'),
                            label: l10n.currentBalance,
                            value: CurrencyFormatter.formatMinor(
                              widget.account!.currentBalanceMinor,
                              widget.account!.currency,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.accountBalanceReadOnlyHelper,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            key: const ValueKey('account_type_selector'),
                            initialValue: _type,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: l10n.accountType),
                            items: [
                              DropdownMenuItem(
                                key: const ValueKey('account_type_option_cash'),
                                value: 'cash',
                                child: Text(l10n.cashAccountType),
                              ),
                              DropdownMenuItem(
                                key: const ValueKey('account_type_option_checking'),
                                value: 'checking',
                                child: Text(l10n.checkingAccountType),
                              ),
                              DropdownMenuItem(
                                key: const ValueKey('account_type_option_savings'),
                                value: 'savings',
                                child: Text(l10n.savingsAccountType),
                              ),
                            ],
                            onChanged: _saving ? null : (value) => setState(() => _type = value!),
                          ),
                          const SizedBox(height: 18),
                          DropdownButtonFormField<String>(
                            key: const ValueKey('account_currency_selector'),
                            initialValue: _currency,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l10n.accountCurrency,
                              helperText: l10n.profileCurrencyHint(widget.defaultCurrency),
                            ),
                            items: [
                              for (final currency in _availableCurrencies)
                                DropdownMenuItem(
                                  key: ValueKey('account_currency_option_$currency'),
                                  value: currency,
                                  child: Text(currency),
                                ),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _currency = value!),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const ValueKey('account_initial_balance_field'),
                            controller: _balanceController,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: CurrencyFormatter.decimalDigits(_currency) > 0,
                              signed: false,
                            ),
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: l10n.initialBalance,
                              prefixText: '$_currency ',
                              helperText: l10n.openingBalanceHelper,
                            ),
                            validator: (value) => _validateBalance(value, l10n),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            key: const ValueKey('account_save_error'),
                            liveRegion: true,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.orange.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(_error!, style: const TextStyle(color: AppColors.navy)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottomInset),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('account_save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? l10n.save : l10n.addAccount),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateBalance(String? value, AppLocalizations l10n) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty || raw.startsWith('-')) return l10n.invalidInitialBalance;
    try {
      _parseBalance(raw, _currency);
      return null;
    } on FormatException {
      return l10n.invalidInitialBalance;
    }
  }

  int _parseBalance(String raw, String currency) {
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'^0+(?:[.,]0{1,2})?$').hasMatch(normalized)) return 0;
    if (normalized.startsWith('-')) throw const FormatException('Negative balance.');
    return MoneyParser.minorUnits(normalized, currency);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final name = _nameController.text.trim();
      if (_isEditing) {
        await ref
            .read(canonicalActionsProvider)
            .updateAccount(
              widget.userId,
              widget.account!,
              name: name,
            );
      } else {
        await ref
            .read(canonicalActionsProvider)
            .createAccount(
              widget.userId,
              name: name,
              type: _type,
              currency: _currency,
              openingBalanceMinor: _parseBalance(_balanceController.text, _currency),
            );
      }
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.accountSaveFailed;
        });
      }
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/accounts');
    }
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label, enabled: false),
    child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
  );
}

String _typeLabel(AppLocalizations l10n, String type) => switch (type.toLowerCase()) {
  'cash' || 'wallet' => l10n.cashAccountType,
  'checking' => l10n.checkingAccountType,
  'savings' => l10n.savingsAccountType,
  _ => type,
};
