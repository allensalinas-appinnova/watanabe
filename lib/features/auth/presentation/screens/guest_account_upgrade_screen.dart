import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/finance_input_validators.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/auth_providers.dart';

class GuestAccountUpgradeScreen extends ConsumerStatefulWidget {
  const GuestAccountUpgradeScreen({super.key});

  @override
  ConsumerState<GuestAccountUpgradeScreen> createState() => _GuestAccountUpgradeScreenState();
}

class _GuestAccountUpgradeScreenState extends ConsumerState<GuestAccountUpgradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _busy = false;
  bool _linked = false;
  bool _verificationSent = false;
  bool _verificationApplicable = false;
  String? _errorCode;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessionState = ref.watch(authSessionProvider);
    final session = sessionState.valueOrNull;
    final isGuest = session?.isAnonymous ?? false;

    return Scaffold(
      appBar: FinanceRouteHeader(
        title: l10n.guestUpgradeTitle,
        backLabel: l10n.back,
        onBack: () => popOrGo(context, '/settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Text(l10n.guestUpgradeSubtitle, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            if (sessionState.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (sessionState.hasError)
              Text(l10n.authActionFailed)
            else if (!isGuest)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_linked ? _successMessage(l10n) : l10n.guestUpgradeAlreadyProtected),
                ),
              )
            else if (_linked)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_successMessage(l10n)),
                      if (_verificationApplicable && !_verificationSent) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          key: const ValueKey('guest_resend_verification'),
                          onPressed: _busy ? null : _resendVerification,
                          child: Text(l10n.guestUpgradeResendVerification),
                        ),
                      ],
                      TextButton(
                        onPressed: () => context.go('/home'),
                        child: Text(l10n.guestUpgradeBackToApp),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (_errorCode != null) ...[
                _MessageCard(message: _localizedError(l10n, _errorCode!)),
                const SizedBox(height: 12),
              ],
              Text(l10n.guestUpgradeEmailTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      key: const ValueKey('guest_upgrade_email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(labelText: l10n.authEmailLabel),
                      validator: (value) =>
                          value != null && FinanceInputValidators.isValidEmail(value.trim())
                          ? null
                          : l10n.authEmailInvalid,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('guest_upgrade_password'),
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(labelText: l10n.authPasswordLabel),
                      validator: (value) =>
                          value != null && value.length >= 8 ? null : l10n.authPasswordTooShort,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('guest_upgrade_confirm_password'),
                      controller: _confirmPassword,
                      obscureText: true,
                      decoration: InputDecoration(labelText: l10n.guestUpgradeConfirmPassword),
                      validator: (value) =>
                          value == _password.text ? null : l10n.guestUpgradePasswordMismatch,
                      onFieldSubmitted: (_) => _linkEmail(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('guest_upgrade_email_submit'),
                        onPressed: _busy ? null : _linkEmail,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.guestSaveAccount),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(child: Text(l10n.authOrContinueWith)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('guest_upgrade_google'),
                onPressed: _busy ? null : _linkGoogle,
                icon: const Text('G'),
                label: Text(l10n.guestUpgradeGoogleButton),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _successMessage(AppLocalizations l10n) => _verificationApplicable
      ? (_verificationSent ? l10n.guestUpgradeEmailSent : l10n.guestUpgradeEmailNotSent)
      : l10n.guestUpgradeSuccess;

  Future<void> _linkEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    final result = await ref
        .read(authRepositoryProvider)
        .linkEmailPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _errorCode =
            failure.technicalCode ??
            (failure is NetworkFailure ? 'network-request-failed' : 'unknown');
        _busy = false;
      }),
      (linked) => setState(() {
        _linked = true;
        _verificationApplicable = true;
        _verificationSent = linked.emailVerificationSent ?? false;
        _busy = false;
      }),
    );
  }

  Future<void> _linkGoogle() async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    final result = await ref.read(authRepositoryProvider).linkGoogle();
    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _errorCode =
            failure.technicalCode ??
            (failure is NetworkFailure ? 'network-request-failed' : 'unknown');
        _busy = false;
      }),
      (_) => setState(() {
        _linked = true;
        _verificationApplicable = false;
        _busy = false;
      }),
    );
  }

  Future<void> _resendVerification() async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    final result = await ref.read(authRepositoryProvider).sendEmailVerification();
    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _errorCode = failure.technicalCode ?? 'unknown';
        _busy = false;
      }),
      (_) => setState(() {
        _verificationSent = true;
        _busy = false;
      }),
    );
  }

  String _localizedError(AppLocalizations l10n, String code) => switch (code) {
    'credential-already-in-use' ||
    'email-already-in-use' ||
    'account-exists-with-different-credential' => l10n.guestUpgradeConflict,
    'provider-already-linked' => l10n.guestUpgradeProviderLinked,
    'web-context-canceled' ||
    'popup-closed-by-user' ||
    'cancelled-popup-request' => l10n.guestUpgradeCancelled,
    'network-request-failed' || 'unavailable' || 'deadline-exceeded' => l10n.authNetworkError,
    'weak-password' => l10n.guestUpgradeWeakPassword,
    'operation-not-allowed' => l10n.guestUpgradeUnavailable,
    _ => l10n.authActionFailed,
  };
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    ),
  );
}
