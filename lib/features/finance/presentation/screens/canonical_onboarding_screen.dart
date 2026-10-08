import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalOnboardingScreen extends ConsumerStatefulWidget {
  const CanonicalOnboardingScreen({super.key});

  @override
  ConsumerState<CanonicalOnboardingScreen> createState() => _CanonicalOnboardingScreenState();
}

class _CanonicalOnboardingScreenState extends ConsumerState<CanonicalOnboardingScreen> {
  final account = TextEditingController();
  String locale = 'es';
  String country = 'CO';
  String currency = 'COP';
  String timeZone = 'America/Bogota';
  bool saving = false;

  bool get _canContinue => account.text.trim().isNotEmpty && !saving;

  @override
  void initState() {
    super.initState();
    account.addListener(_onAccountChanged);
  }

  @override
  void dispose() {
    account.removeListener(_onAccountChanged);
    account.dispose();
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    l10n.appTitle,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AppColors.blueDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    l10n.personalizeExperience,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    l10n.onboardingSubtitle,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  _preferenceField<String>(
                                    key: const ValueKey('onboarding_language'),
                                    label: l10n.language,
                                    value: locale,
                                    items: const [
                                      DropdownMenuItem(value: 'es', child: Text('Español')),
                                      DropdownMenuItem(value: 'pt', child: Text('Português')),
                                      DropdownMenuItem(value: 'en', child: Text('English')),
                                    ],
                                    onChanged: (value) => setState(() => locale = value ?? 'es'),
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
                                    onChanged: (value) => setState(() => currency = value ?? 'COP'),
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
                                  const SizedBox(height: 12),
                                  _fieldLabel(context, l10n.firstAccountName),
                                  Semantics(
                                    label: l10n.firstAccountName,
                                    textField: true,
                                    child: TextField(
                                      key: const ValueKey('onboarding_account_name'),
                                      controller: account,
                                      textCapitalization: TextCapitalization.sentences,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                                      decoration: _inputDecoration(),
                                    ),
                                  ),
                                ],
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
                                onPressed: _canContinue ? _complete : null,
                                child: saving
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(l10n.continueAction),
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

  Widget _fieldLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.muted,
        fontWeight: FontWeight.w600,
        letterSpacing: .7,
      ),
    ),
  );

  InputDecoration _inputDecoration() => InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.blueDark, width: 1.5),
    ),
  );

  void _onAccountChanged() => setState(() {});

  Future<void> _complete() async {
    final user =
        ref.read(authSessionProvider).valueOrNull ?? ref.read(authRepositoryProvider).currentUser;
    if (user == null || account.text.trim().isEmpty) return;
    setState(() => saving = true);
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
            name: account.text,
            type: 'cash',
            currency: currency,
            openingBalanceMinor: 0,
          );
      if (mounted) context.go('/home');
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
}
