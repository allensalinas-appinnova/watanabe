import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Either;
import '../../../core/di/injection.dart';
import '../../../core/error/failure.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../finance/domain/entities/user_profile.dart';
import '../../finance/presentation/providers/canonical_finance_providers.dart';
import '../domain/shared_receipt.dart';
import 'document_import_providers.dart';
import 'document_import_screen.dart';

final sharedReceiptInboxProvider = Provider<SharedReceiptInbox>((ref) => getIt());

class SharedReceiptLifecycle extends ConsumerStatefulWidget {
  const SharedReceiptLifecycle({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<SharedReceiptLifecycle> createState() => _SharedReceiptLifecycleState();
}

class _SharedReceiptLifecycleState extends ConsumerState<SharedReceiptLifecycle>
    with WidgetsBindingObserver {
  StreamSubscription<Either<Failure, SharedReceipt?>>? _subscription;
  SharedReceipt? _pending;
  AuthUser? _user;
  UserProfile? _profile;
  String? _prompted;
  bool _showing = false;
  bool _sessionReady = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appRouter.routerDelegate.addListener(_schedule);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _subscription = ref.read(sharedReceiptInboxProvider).watch().listen((result) {
        result.match(
          (f) {
            final c = appRouter.routerDelegate.navigatorKey.currentContext;
            if (c == null || !mounted) return;
            final l = AppLocalizations.of(c);
            final message = f.message == 'shared-receipt-one-file'
                ? l.sharedReceiptOneFile
                : f.message == 'shared-receipt-busy'
                ? l.sharedReceiptBusy
                : documentError(l, f.message);
            ScaffoldMessenger.maybeOf(c)?.showSnackBar(SnackBar(content: Text(message)));
          },
          (receipt) {
            _pending = receipt;
            _schedule();
          },
        );
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouter.routerDelegate.removeListener(_schedule);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_user != null && !_user!.isAnonymous && !_showing) {
        _prompted = null;
      }
      unawaited(ref.read(sharedReceiptInboxProvider).refresh());
      _schedule();
    }
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<bool?> _confirm(BuildContext c, String title, String body, String action) {
    final l = AppLocalizations.of(c);
    return showDialog<bool>(
      context: c,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(action)),
        ],
      ),
    );
  }

  Future<void> _open() async {
    final receipt = _pending, user = _user, profile = _profile;
    final c = appRouter.routerDelegate.navigatorKey.currentContext;
    final promptKey =
        '${receipt?.id}:${user?.id}:${profile?.dataGeneration}:${user?.isAnonymous}:${profile?.onboardingStatus}:${profile?.resetStatus}';
    if (!_sessionReady ||
        receipt == null ||
        _showing ||
        _prompted == promptKey ||
        c == null ||
        !mounted) {
      return;
    }
    if (profile?.resetStatus == 'resetting' || (user != null && profile == null)) return;
    final path = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (user != null &&
        !user.isAnonymous &&
        const {'/login', '/onboarding', '/settings/secure-account'}.contains(path)) {
      return;
    }
    _showing = true;
    _prompted = promptKey;
    try {
      final inbox = ref.read(sharedReceiptInboxProvider), l = AppLocalizations.of(c);
      if (user == null || user.isAnonymous) {
        final yes = await _confirm(
          c,
          l.sharedReceiptTitle,
          l.sharedReceiptSignIn,
          user == null ? l.loginTitle : l.guestSaveAccount,
        );
        if (!mounted) return;
        if (yes == true) {
          final destination = user == null ? '/login' : '/settings/secure-account';
          if (appRouter.routerDelegate.currentConfiguration.uri.path != destination) {
            unawaited(appRouter.push(destination));
          }
        } else if (yes == false) {
          await inbox.dismiss(receipt.id);
        }
        return;
      }
      if (profile!.onboardingStatus != 'complete') return;
      if (!receipt.matches(user.id, profile.dataGeneration) || receipt.isExpired(DateTime.now())) {
        await inbox.dismiss(receipt.id);
        return;
      }
      if (receipt.ownerId == null) {
        final yes = await _confirm(
          c,
          l.sharedReceiptTitle,
          l.sharedReceiptConfirmAccount(user.email ?? user.displayName ?? ''),
          l.sharedReceiptContinue,
        );
        if (yes != true) {
          if (yes == false) await inbox.dismiss(receipt.id);
          return;
        }
      }
      if (!mounted || _user?.id != user.id || _profile?.dataGeneration != profile.dataGeneration) {
        return;
      }
      final adopt = AdoptSharedReceipt(
        ref.read(documentImportRepositoryProvider),
        now: DateTime.now,
      );
      var result = await adopt(receipt, uid: user.id, generation: profile.dataGeneration);
      if (result.getLeft().toNullable()?.message == 'shared-receipt-conflict' && c.mounted) {
        final replace = await showDialog<bool>(
          context: c,
          builder: (dialog) => AlertDialog(
            scrollable: true,
            title: Text(l.sharedReceiptConflictTitle),
            content: Text(l.sharedReceiptConflictBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(l.sharedReceiptKeep),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(l.sharedReceiptReplace),
              ),
            ],
          ),
        );
        if (replace != true) {
          if (replace == false) await inbox.dismiss(receipt.id);
          return;
        }
        if (!c.mounted) return;
        final confirmed = await _confirm(
          c,
          l.documentDiscard,
          l.documentDiscardExplanation,
          l.sharedReceiptReplace,
        );
        if (confirmed != true) return;
        if (_user?.id != user.id || _profile?.dataGeneration != profile.dataGeneration) return;
        result = await adopt(
          receipt,
          uid: user.id,
          generation: profile.dataGeneration,
          replace: true,
        );
      }
      if (result.isLeft()) {
        if (!c.mounted) return;
        final retry = await _confirm(c, l.sharedReceiptTitle, l.sharedReceiptRetry, l.retry);
        if (retry == true) {
          _prompted = null;
          _schedule();
        }
        return;
      }
      if (!mounted || _user?.id != user.id || _profile?.dataGeneration != profile.dataGeneration) {
        return;
      }
      await inbox.dismiss(receipt.id);
      await ref
          .read(documentImportControllerProvider.notifier)
          .reload(user.id, profile.dataGeneration);
      if (mounted) {
        final path = appRouter.routerDelegate.currentConfiguration.uri.path;
        if (path.startsWith('/document-imports/')) {
          unawaited(appRouter.replace<void>('/document-imports/new?returnTo=home'));
        } else if (path != '/document-imports/new') {
          unawaited(appRouter.push('/document-imports/new?returnTo=home'));
        }
      }
    } finally {
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    _sessionReady = session.hasValue;
    _user = session.valueOrNull;
    _profile = _user == null
        ? null
        : ref.watch(canonicalUserProfileProvider(_user!.id)).valueOrNull;
    final user = _user, profile = _profile;
    if (_sessionReady && (user == null || profile != null)) {
      unawaited(
        ref
            .read(sharedReceiptInboxProvider)
            .setSession(
              user?.id,
              profile?.dataGeneration,
              resetting: profile?.resetStatus == 'resetting',
            ),
      );
    }
    _schedule();
    return widget.child;
  }
}
