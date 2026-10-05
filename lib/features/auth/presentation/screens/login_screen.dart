import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
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
    ref.listen(authControllerProvider, (previous, next) {
      if (next.status == AuthActionStatus.success && next.navigateToHome) {
        context.go('/home');
      }
      if (next.status == AuthActionStatus.success && next.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message!)),
        );
      }
      if (next.status == AuthActionStatus.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.failure?.message ?? 'We could not sign you in.')),
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
                    ),
                    const SizedBox(height: 27),
                    const _FieldLabel('EMAIL'),
                    const SizedBox(height: 7),
                    TextFormField(
                      key: const ValueKey('auth_email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        hintText: 'you@example.com',
                        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFFDFE8F1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFFDFE8F1)),
                        ),
                      ),
                      validator: (value) => value != null && value.contains('@')
                          ? null
                          : 'Enter a valid email address.',
                    ),
                    const SizedBox(height: 17),
                    const _FieldLabel('PASSWORD'),
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
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFFDFE8F1)),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFFDFE8F1)),
                        ),
                        suffixIcon: IconButton(
                          key: const ValueKey('auth_password_visibility'),
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppColors.blueDark,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value != null && value.length >= 8 ? null : 'Use at least 8 characters.',
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (!_isCreatingAccount)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const ValueKey('auth_forgot_password_button'),
                          onPressed: isLoading ? null : _requestPasswordReset,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.blueDark,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Forgot password?', style: TextStyle(fontSize: 12)),
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
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blueDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: isLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _isCreatingAccount ? 'Create account' : 'Log in',
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.navy,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFDFE8F1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        icon: const Text(
                          'G',
                          style: TextStyle(
                            color: AppColors.orange,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        label: const Text(
                          'Continue with Google',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('auth_guest_button'),
                      onPressed: isLoading ? null : _continueAsGuest,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.blueDark,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                      child: const Text(
                        'Continue as guest',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 13),
                    const Text(
                      'Your data is private and encrypted.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
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
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address to reset your password.')),
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
      Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(24)),
        child: const Center(
          child: Text('◆', style: TextStyle(color: AppColors.blue, fontSize: 28)),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'ClearBudget',
        style: TextStyle(color: AppColors.navy, fontSize: 26, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      const Text(
        'Clarity for every peso.',
        style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ],
  );
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({required this.isCreatingAccount, required this.onSelectionChanged});

  final bool isCreatingAccount;
  final ValueChanged<bool> onSelectionChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
    child: Row(
      children: [
        Expanded(
          child: _AuthTab(
            key: const ValueKey('auth_login_tab'),
            label: 'Log in',
            selected: !isCreatingAccount,
            onTap: () => onSelectionChanged(false),
          ),
        ),
        Expanded(
          child: _AuthTab(
            key: const ValueKey('auth_signup_tab'),
            label: 'Create account',
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
    color: selected ? AppColors.blueSoft : Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.blueDark : AppColors.muted,
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
    style: const TextStyle(
      color: AppColors.muted,
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
      const Expanded(child: Divider(color: Color(0xFFDFE8F1))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'or continue with',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontSize: 12),
        ),
      ),
      const Expanded(child: Divider(color: Color(0xFFDFE8F1))),
    ],
  );
}
