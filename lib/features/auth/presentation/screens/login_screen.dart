import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/finance_input_validators.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isCreatingAccount = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(authControllerProvider, (previous, next) {
      if (next.status == AuthActionStatus.success && next.navigateToHome) {
        context.go('/home');
      }
      if (next.status == AuthActionStatus.success && next.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authPasswordResetSent)),
        );
      }
      if (next.status == AuthActionStatus.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.failure is NetworkFailure ? l10n.authNetworkError : l10n.authActionFailed,
            ),
          ),
        );
      }
    });

    final state = ref.watch(authControllerProvider);
    final isLoading = state.status == AuthActionStatus.loading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: 31),
                    _AuthTabs(
                      isCreatingAccount: _isCreatingAccount,
                      onSelectionChanged: (value) => setState(() => _isCreatingAccount = value),
                      loginLabel: l10n.authLoginTab,
                      createLabel: l10n.createAccount,
                    ),
                    const SizedBox(height: 27),
                    _FieldLabel(l10n.authEmailLabel.toUpperCase()),
                    const SizedBox(height: 7),
                    TextFormField(
                      key: const ValueKey('auth_email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        hintText: l10n.authEmailHint,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value != null && FinanceInputValidators.isValidEmail(value)
                          ? null
                          : l10n.authEmailInvalid,
                    ),
                    const SizedBox(height: 17),
                    _FieldLabel(l10n.authPasswordLabel.toUpperCase()),
                    const SizedBox(height: 7),
                    TextFormField(
                      key: const ValueKey('auth_password_field'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: [
                        _isCreatingAccount ? AutofillHints.newPassword : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          key: const ValueKey('auth_password_visibility'),
                          tooltip: _obscurePassword ? l10n.authShowPassword : l10n.authHidePassword,
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value != null && value.length >= 8 ? null : l10n.authPasswordTooShort,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (!_isCreatingAccount)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const ValueKey('auth_forgot_password_button'),
                          onPressed: isLoading ? null : _requestPasswordReset,
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(
                            l10n.authForgotPassword,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 8),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        key: const ValueKey('auth_submit_button'),
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _isCreatingAccount ? l10n.createAccount : l10n.authLoginTab,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _OrDivider(),
                    const SizedBox(height: 17),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        key: const ValueKey('auth_google_button'),
                        onPressed: isLoading
                            ? null
                            : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
                        icon: Text(
                          'G',
                          style: TextStyle(
                            color: context.appColors.warning,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        label: Text(
                          l10n.authContinueWithGoogle,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('auth_guest_button'),
                      onPressed: isLoading ? null : _continueAsGuest,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                      child: Text(
                        l10n.continueAsGuest,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      l10n.authPrivacyNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
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
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_isCreatingAccount) {
      controller.createAccount(email: email, password: password);
    } else {
      controller.signIn(email: email, password: password);
    }
  }

  void _continueAsGuest() {
    ref.read(authControllerProvider.notifier).signInAnonymously();
  }

  void _requestPasswordReset() {
    final email = _emailController.text.trim();
    final l10n = AppLocalizations.of(context);
    if (!FinanceInputValidators.isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authResetEmailInvalid)),
      );
      return;
    }
    ref.read(authControllerProvider.notifier).sendPasswordResetEmail(email: email);
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Semantics(
          label: AppLocalizations.of(context).appTitle,
          child: Image.asset(
            'assets/images/lumiomoney_logo.png',
            width: 88,
            height: 88,
            fit: BoxFit.cover,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        AppLocalizations.of(context).appTitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        AppLocalizations.of(context).authTagline,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({
    required this.isCreatingAccount,
    required this.onSelectionChanged,
    required this.loginLabel,
    required this.createLabel,
  });

  final bool isCreatingAccount;
  final ValueChanged<bool> onSelectionChanged;
  final String loginLabel;
  final String createLabel;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('auth_tabs_surface'),
    height: 46,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      children: [
        Expanded(
          child: _AuthTab(
            key: const ValueKey('auth_login_tab'),
            label: loginLabel,
            selected: !isCreatingAccount,
            onTap: () => onSelectionChanged(false),
          ),
        ),
        Expanded(
          child: _AuthTab(
            key: const ValueKey('auth_signup_tab'),
            label: createLabel,
            selected: isCreatingAccount,
            onTap: () => onSelectionChanged(true),
          ),
        ),
      ],
    ),
  );
}

class _AuthTab extends StatelessWidget {
  const _AuthTab({required this.label, required this.selected, required this.onTap, super.key});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: .2,
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          AppLocalizations.of(context).authOrContinueWith,
          style:
              Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
        ),
      ),
      Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
    ],
  );
}
