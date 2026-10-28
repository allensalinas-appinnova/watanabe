import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/authenticated_route_resolver.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/finance_input_validators.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../core/utils/request_id.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalOnboardingScreen extends ConsumerStatefulWidget {
  const CanonicalOnboardingScreen({super.key});

  @override
  ConsumerState<CanonicalOnboardingScreen> createState() => _CanonicalOnboardingScreenState();
}

class _CanonicalOnboardingScreenState extends ConsumerState<CanonicalOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final account = TextEditingController();
  final balance = TextEditingController(text: '0');
  final _accountId = newRequestId();
  String locale = 'es';
  String country = 'CO';
  String currency = 'COP';
  String timeZone = 'America/Bogota';
  String accountType = 'cash';
  bool _accountNameEdited = false;
  bool _initializedAccountName = false;
  bool saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    account.dispose();
    balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      locale: Locale(locale),
      child: Builder(
        builder: (localizedContext) {
          final l10n = AppLocalizations.of(localizedContext);
          if (!_initializedAccountName) {
            account.text = _suggestedAccountName(l10n);
            _initializedAccountName = true;
          }
          return Scaffold(
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      l10n.appTitle,
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      l10n.personalizeExperience,
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.onboardingSubtitle,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    _sectionTitle(context, l10n.onboardingPreferencesSection),
                                    const SizedBox(height: 14),
                                    _preferenceField<String>(
                                      key: const ValueKey('onboarding_language'),
                                      label: l10n.language,
                                      value: locale,
                                      items: const [
                                        DropdownMenuItem(value: 'es', child: Text('Español')),
                                        DropdownMenuItem(value: 'pt', child: Text('Português')),
                                        DropdownMenuItem(value: 'en', child: Text('English')),
                                      ],
                                      onChanged: (value) {
                                        final selectedLocale = value ?? 'es';
                                        setState(() => locale = selectedLocale);
                                        AppLocalizations.delegate.load(Locale(selectedLocale)).then(
                                          (localized) {
                                            if (!mounted || _accountNameEdited) return;
                                            setState(() {
                                              account.text = _suggestedAccountName(localized);
                                            });
                                          },
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _preferenceField<String>(
                                      key: const ValueKey('onboarding_country'),
                                      label: l10n.country,
                                      value: country,
                                      items: const [
                                        DropdownMenuItem(value: 'CO', child: Text('Colombia')),
                                        DropdownMenuItem(value: 'MX', child: Text('México')),
                                        DropdownMenuItem(value: 'BR', child: Text('Brasil')),
                                      ],
                                      onChanged: (value) => setState(() {
                                        country = value ?? 'CO';
                                        timeZone = switch (country) {
                                          'MX' => 'America/Mexico_City',
                                          'BR' => 'America/Sao_Paulo',
                                          _ => 'America/Bogota',
                                        };
                                        currency = switch (country) {
                                          'MX' => 'MXN',
                                          'BR' => 'BRL',
                                          _ => 'COP',
                                        };
                                      }),
                                    ),
                                    const SizedBox(height: 12),
                                    _preferenceField<String>(
                                      key: const ValueKey('onboarding_currency'),
                                      label: l10n.baseCurrency,
                                      value: currency,
                                      items: const [
                                        DropdownMenuItem(value: 'COP', child: Text('COP')),
                                        DropdownMenuItem(value: 'MXN', child: Text('MXN')),
                                        DropdownMenuItem(value: 'BRL', child: Text('BRL')),
                                      ],
                                      onChanged: (value) =>
                                          setState(() => currency = value ?? 'COP'),
                                    ),
                                    const SizedBox(height: 12),
                                    _preferenceField<String>(
                                      key: const ValueKey('onboarding_timezone'),
                                      label: l10n.timeZone,
                                      value: timeZone,
                                      items: [
                                        DropdownMenuItem(
                                          value: 'America/Bogota',
                                          child: Text(l10n.timeZoneBogota),
                                        ),
                                        DropdownMenuItem(
                                          value: 'America/Mexico_City',
                                          child: Text(l10n.timeZoneMexicoCity),
                                        ),
                                        DropdownMenuItem(
                                          value: 'America/Sao_Paulo',
                                          child: Text(l10n.timeZoneSaoPaulo),
                                        ),
                                      ],
                                      onChanged: (value) =>
                                          setState(() => timeZone = value ?? 'America/Bogota'),
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(),
                                    const SizedBox(height: 12),
                                    _sectionTitle(context, l10n.onboardingAccountSection),
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.onboardingAccountExplanation,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                      key: const ValueKey('onboarding_account_type'),
                                      initialValue: accountType,
                                      isExpanded: true,
                                      decoration: _inputDecoration().copyWith(
                                        labelText: l10n.accountType,
                                      ),
                                      items: [
                                        _accountTypeItem('cash', l10n.cashAccountType),
                                        _accountTypeItem('checking', l10n.checkingAccountType),
                                        _accountTypeItem('savings', l10n.savingsAccountType),
                                      ],
                                      onChanged: saving
                                          ? null
                                          : (value) => setState(() {
                                              accountType = value ?? 'cash';
                                              _refreshSuggestedName(l10n);
                                            }),
                                    ),
                                    const SizedBox(height: 12),
                                    Semantics(
                                      label: l10n.onboardingAccountNameLabel,
                                      textField: true,
                                      child: TextFormField(
                                        key: const ValueKey('onboarding_account_name'),
                                        controller: account,
                                        textCapitalization: TextCapitalization.sentences,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                                        onChanged: (_) => _accountNameEdited = true,
                                        decoration: _inputDecoration().copyWith(
                                          labelText: l10n.onboardingAccountNameLabel,
                                          helperText: l10n.onboardingAccountNameHelper,
                                        ),
                                        validator: (value) => FinanceInputValidators.requiredText(
                                          value,
                                          l10n.onboardingAccountRequired,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      key: const ValueKey('onboarding_current_balance'),
                                      controller: balance,
                                      keyboardType: TextInputType.numberWithOptions(
                                        decimal: CurrencyFormatter.decimalDigits(currency) > 0,
                                      ),
                                      textInputAction: TextInputAction.done,
                                      decoration: _inputDecoration().copyWith(
                                        labelText: l10n.onboardingCurrentBalance,
                                        prefixText: '$currency ',
                                        helperText: l10n.onboardingCurrentBalanceHelper,
                                      ),
                                      validator: (value) => value?.trim().isEmpty ?? true
                                          ? null
                                          : FinanceInputValidators.amount(
                                              value,
                                              currency,
                                              l10n,
                                              allowZero: true,
                                            ),
                                    ),
                                    if (_error != null) ...[
                                      const SizedBox(height: 12),
                                      Semantics(
                                        key: const ValueKey('onboarding_save_error'),
                                        liveRegion: true,
                                        child: Text(
                                          _error!,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                key: const ValueKey('onboarding_continue'),
                                onPressed: saving ? null : _complete,
                                child: saving
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(l10n.onboardingCreateAccount),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _preferenceField<T>({
    required Key key,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, label),
        DropdownButtonFormField<T>(
          key: key,
          initialValue: value,
          isExpanded: true,
          decoration: _inputDecoration(),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Text(
    title,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  );

  DropdownMenuItem<String> _accountTypeItem(String value, String label) => DropdownMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(_accountTypeIcon(value), size: 22),
        const SizedBox(width: 12),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );

  IconData _accountTypeIcon(String type) => switch (type) {
    'checking' => Icons.account_balance_outlined,
    'savings' => Icons.savings_outlined,
    _ => Icons.account_balance_wallet_outlined,
  };

  String _suggestedAccountName(AppLocalizations l10n) => switch (accountType) {
    'checking' => l10n.onboardingCheckingAccountName,
    'savings' => l10n.onboardingSavingsAccountName,
    _ => l10n.onboardingWalletAccountName,
  };

  void _refreshSuggestedName(AppLocalizations l10n) {
    if (!_accountNameEdited) account.text = _suggestedAccountName(l10n);
  }

  Widget _fieldLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: .7,
      ),
    ),
  );

  InputDecoration _inputDecoration() => InputDecoration(
    filled: true,
    fillColor: Theme.of(context).colorScheme.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
    ),
  );

  Future<void> _complete() async {
    if (!_formKey.currentState!.validate()) return;
    final user =
        ref.read(authSessionProvider).valueOrNull ?? ref.read(authRepositoryProvider).currentUser;
    if (user == null || account.text.trim().isEmpty) return;
    setState(() {
      saving = true;
      _error = null;
    });
    try {
      await ref.read(bootstrapCategoriesProvider)(
        user.id,
        locale: locale,
        countryCode: country,
        timeZone: timeZone,
        defaultCurrency: currency,
      );
      await ref
          .read(canonicalActionsProvider)
          .createAccount(
            user.id,
            accountId: _accountId,
            name: account.text,
            type: accountType,
            currency: currency,
            openingBalanceMinor: balance.text.trim().isEmpty
                ? 0
                : MoneyParser.minorUnits(balance.text, currency, allowZero: true),
          );
      invalidateCachedUserProfile(user.id);
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).genericError);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
