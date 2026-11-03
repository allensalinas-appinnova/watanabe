import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/auth_access_method.dart';
import '../../domain/entities/auth_account_link_result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/use_cases/link_registered_access_method.dart';
import '../providers/auth_providers.dart';

String accessMethodLabel(AppLocalizations l, AuthAccessMethod method) => switch (method) {
  AuthAccessMethod.password => l.accessPassword,
  AuthAccessMethod.google => 'Google',
  AuthAccessMethod.apple => 'Apple',
};
IconData accessMethodIcon(AuthAccessMethod method) => switch (method) {
  AuthAccessMethod.password => Icons.mail_outline,
  AuthAccessMethod.google => Icons.account_circle_outlined,
  AuthAccessMethod.apple => Icons.apple,
};

bool accessMethodAvailable(AuthAccessMethod method) => switch (method) {
  AuthAccessMethod.password => true,
  AuthAccessMethod.google =>
    kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS,
  AuthAccessMethod.apple =>
    const bool.fromEnvironment('AUTH_APPLE_ENABLED') &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS),
};

bool _canReauthenticate(AuthAccessMethod method) =>
    method == AuthAccessMethod.password ||
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

String accessFailureMessage(AppLocalizations l, Failure failure) => switch (failure.technicalCode) {
  'credential-already-in-use' ||
  'email-already-in-use' ||
  'account-exists-with-different-credential' => l.accessConflict,
  'user-mismatch' || 'user-not-found' || 'user-disabled' => l.accessSessionChanged,
  'invalid-credential' ||
  'wrong-password' ||
  'requires-recent-login' ||
  'provider-not-linked' => l.accessCredentialError,
  'access-details-changed' => l.accessRefreshError,
  'weak-password' => l.accessPasswordInvalid,
  'apple-consent-required' => l.accessConsentRequired,
  'password-email-unavailable' => l.accessPrivateEmail,
  _ => failure is NetworkFailure ? l.accessNetworkError : l.accessGenericError,
};
bool _cancelled(Failure failure) => [
  'web-context-canceled',
  'canceled',
  'cancelled',
  'user-cancelled',
  'popup-closed-by-user',
].contains(failure.technicalCode);

class AccessMethodsScreen extends ConsumerStatefulWidget {
  const AccessMethodsScreen({super.key});
  @override
  ConsumerState<AccessMethodsScreen> createState() => _AccessMethodsScreenState();
}

class _AccessMethodsScreenState extends ConsumerState<AccessMethodsScreen>
    with WidgetsBindingObserver {
  AuthUser? _snapshot;
  bool _fresh = false, _loading = false, _busy = false;
  String? _notice;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted || _busy) return;
    final user = ref.read(authSessionProvider).valueOrNull;
    if (user == null || user.isAnonymous) return;
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _fresh = false;
    });
    final result = await ref
        .read(authRepositoryProvider)
        .refreshAccessMethods(expectedUid: user.id);
    if (!mounted ||
        revision != _revision ||
        ref.read(authSessionProvider).valueOrNull?.id != user.id) {
      return;
    }
    setState(() {
      _loading = false;
      result.match(
        (_) {
          _fresh = false;
        },
        (u) {
          _snapshot = u;
          _fresh = u.providerIds != null;
        },
      );
    });
  }

  Future<void> _link(AuthUser user, AuthAccessMethod method) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    final result = await showDialog<AuthAccountLinkResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LinkAccessDialog(
        user: user,
        method: method,
        repository: ref.read(authRepositoryProvider),
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result != null && ref.read(authSessionProvider).valueOrNull?.id == user.id) {
        final l = AppLocalizations.of(context);
        _snapshot = result.user;
        final passwordReplaced =
            user.providerIds?.contains('password') == true &&
            result.user.providerIds?.contains('password') == false;
        _notice = result.emailVerificationSent == false
            ? l.accessVerificationFailed
            : result.emailVerificationSent == true
            ? '${l.accessSuccess} ${l.accessVerificationSent}'
            : l.accessSuccess;
        if (passwordReplaced) _notice = '${l.accessSuccess} ${l.accessPasswordReplaced}';
      }
    });
    await _refresh();
  }

  Future<void> _sendVerification(AuthUser user) async {
    setState(() {
      _busy = true;
    });
    final repository = ref.read(authRepositoryProvider);
    if (repository.currentUser?.id != user.id) {
      setState(() {
        _busy = false;
      });
      return;
    }
    final result = await repository.sendEmailVerification();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ref.read(authSessionProvider).valueOrNull?.id == user.id) {
        final l = AppLocalizations.of(context);
        _notice = result.match((f) => accessFailureMessage(l, f), (_) => l.accessVerificationSent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider).valueOrNull;
    ref.listen(authSessionProvider, (previous, next) {
      if (previous?.valueOrNull?.id != next.valueOrNull?.id) {
        _revision++;
        _snapshot = null;
        _fresh = false;
        _notice = null;
        _loading = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refresh();
        });
      }
    });
    final user = _snapshot?.id == session?.id ? _snapshot : session;
    final linked = AuthAccessMethod.values
        .where((m) => user?.providerIds?.contains(m.providerId) == true)
        .toList();
    final privateEmail = isApplePrivateEmail(user?.email);
    return Scaffold(
      appBar: FinanceRouteHeader(
        title: l.accessMethodsTitle,
        backLabel: l.back,
        onBack: () => popOrGo(context, '/settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l.accessMethodsIntro),
          const SizedBox(height: 16),
          if (user?.isAnonymous == true) ...[
            Text(l.guestAccountHint),
            FilledButton(
              onPressed: () => context.push('/settings/secure-account'),
              child: Text(l.guestSaveAccount),
            ),
          ] else if (user != null) ...[
            if (user.email != null) SelectableText(user.email!),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(key: ValueKey('access_methods_loading')),
            if (!_loading && !_fresh) ...[
              Text(
                _snapshot == null && user.providerIds == null
                    ? l.accessUnknown
                    : l.accessRefreshError,
                key: const ValueKey('access_methods_error'),
              ),
              TextButton(onPressed: _busy ? null : _refresh, child: Text(l.accessRetry)),
            ],
            for (final method in linked)
              Card(
                child: ListTile(
                  key: ValueKey('access_linked_${method.name}'),
                  leading: ExcludeSemantics(child: Icon(accessMethodIcon(method))),
                  title: Text(accessMethodLabel(l, method)),
                  subtitle: Text(
                    method == AuthAccessMethod.password && user.emailVerified != true
                        ? user.emailVerified == false
                              ? l.accessEmailUnverified
                              : l.accessEmailUnknown
                        : l.accessLinked,
                  ),
                ),
              ),
            if (linked.contains(AuthAccessMethod.password) && user.emailVerified == false)
              TextButton(
                onPressed: !_fresh || _busy ? null : () => _sendVerification(user),
                child: Text(l.accessSendVerification),
              ),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_notice!, key: const ValueKey('access_methods_notice')),
              ),
            const SizedBox(height: 16),
            Text(l.accessAdd, style: Theme.of(context).textTheme.titleMedium),
            for (final method in AuthAccessMethod.values.where(
              (m) => !linked.contains(m) && accessMethodAvailable(m),
            )) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: ValueKey('access_add_${method.name}'),
                onPressed:
                    !_fresh ||
                        _busy ||
                        !linked.any(_canReauthenticate) ||
                        (method == AuthAccessMethod.password &&
                            (privateEmail || user.email?.trim().isNotEmpty != true))
                    ? null
                    : () => _link(user, method),
                icon: ExcludeSemantics(child: Icon(accessMethodIcon(method))),
                label: Text(accessMethodLabel(l, method)),
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ],
            if (!linked.contains(AuthAccessMethod.password) &&
                (privateEmail || user.email?.trim().isNotEmpty != true)) ...[
              const SizedBox(height: 12),
              Text(l.accessPrivateEmail),
            ],
          ],
        ],
      ),
    );
  }
}

class _LinkAccessDialog extends ConsumerStatefulWidget {
  const _LinkAccessDialog({required this.user, required this.method, required this.repository});
  final AuthUser user;
  final AuthAccessMethod method;
  final AuthRepository repository;
  @override
  ConsumerState<_LinkAccessDialog> createState() => _LinkAccessDialogState();
}

class _LinkAccessDialogState extends ConsumerState<_LinkAccessDialog> {
  final _current = TextEditingController(),
      _password = TextEditingController(),
      _repeat = TextEditingController();
  late AuthAccessMethod _reauth;
  bool _busy = false, _consent = false, _sessionChanged = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _reauth = AuthAccessMethod.values.firstWhere(
      (m) => widget.user.providerIds!.contains(m.providerId) && _canReauthenticate(m),
    );
  }

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (widget.repository.currentUser?.id != widget.user.id) {
      setState(() {
        _error = l.accessSessionChanged;
      });
      return;
    }
    if (_reauth == AuthAccessMethod.password && _current.text.isEmpty) {
      setState(() {
        _error = l.accessCurrentRequired;
      });
      return;
    }
    if (widget.method == AuthAccessMethod.password &&
        (_password.text.length < 8 || _password.text != _repeat.text)) {
      setState(() {
        _error = l.accessPasswordInvalid;
      });
      return;
    }
    if ((isApplePrivateEmail(widget.user.email) || widget.method == AuthAccessMethod.apple) &&
        !_consent) {
      setState(() {
        _error = l.accessConsentRequired;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await LinkRegisteredAccessMethod(widget.repository)(
        expectedUser: widget.user,
        reauthenticateWith: _reauth,
        currentPassword: _reauth == AuthAccessMethod.password ? _current.text : null,
        command: LinkAccessMethodCommand(
          expectedUid: widget.user.id,
          method: widget.method,
          password: widget.method == AuthAccessMethod.password ? _password.text : null,
          applePrivateEmailConsent: _consent,
        ),
      );
      if (!mounted) return;
      result.match(_fail, (value) => Navigator.pop(context, value));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _fail(Failure failure) {
    if (!mounted) return;
    setState(() {
      _error = _cancelled(failure)
          ? null
          : accessFailureMessage(AppLocalizations.of(context), failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final session = ref.watch(authSessionProvider);
    ref.listen(authSessionProvider, (_, next) {
      if (next.hasValue && next.valueOrNull?.id != widget.user.id) {
        _current.clear();
        _password.clear();
        _repeat.clear();
        setState(() {
          _sessionChanged = true;
        });
      }
    });
    if (_sessionChanged || (session.hasValue && session.valueOrNull?.id != widget.user.id)) {
      return AlertDialog(
        content: Text(l.accessSessionChanged),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.accessCancel))],
      );
    }
    final methods = AuthAccessMethod.values
        .where((m) => widget.user.providerIds!.contains(m.providerId) && _canReauthenticate(m))
        .toList();
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text('${l.accessAdd}: ${accessMethodLabel(l, widget.method)}'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.accessLinkIntro),
            if (widget.user.providerIds?.contains('password') == true &&
                widget.user.emailVerified != true &&
                widget.method != AuthAccessMethod.password) ...[
              const SizedBox(height: 12),
              Text(l.accessUnverifiedPasswordWarning),
            ],
            const SizedBox(height: 16),
            if (widget.user.email != null) Text(widget.user.email!),
            const SizedBox(height: 16),
            DropdownButtonFormField<AuthAccessMethod>(
              key: const ValueKey('access_reauth_method'),
              initialValue: _reauth,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.accessReauthMethod),
              items: methods
                  .map((m) => DropdownMenuItem(value: m, child: Text(accessMethodLabel(l, m))))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (m) => setState(() {
                      _reauth = m!;
                      _error = null;
                    }),
            ),
            if (_reauth == AuthAccessMethod.password) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('access_current_password'),
                controller: _current,
                obscureText: true,
                enabled: !_busy,
                decoration: InputDecoration(labelText: l.accessCurrentPassword),
              ),
            ],
            if (widget.method == AuthAccessMethod.password) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('access_new_password'),
                controller: _password,
                obscureText: true,
                enabled: !_busy,
                decoration: InputDecoration(labelText: l.accessNewPassword),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('access_repeat_password'),
                controller: _repeat,
                obscureText: true,
                enabled: !_busy,
                decoration: InputDecoration(labelText: l.accessRepeatPassword),
              ),
            ],
            if (isApplePrivateEmail(widget.user.email) || widget.method == AuthAccessMethod.apple)
              CheckboxListTile(
                key: const ValueKey('access_apple_consent'),
                contentPadding: EdgeInsets.zero,
                value: _consent,
                title: Text(l.accessConsent),
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _consent = v!;
                      }),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  key: const ValueKey('access_link_error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_busy)
              const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l.accessCancel),
          ),
          FilledButton(
            key: const ValueKey('access_link_submit'),
            onPressed: _busy ? null : _submit,
            child: Text(l.accessConfirm),
          ),
        ],
      ),
    );
  }
}
