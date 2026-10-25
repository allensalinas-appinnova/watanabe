import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/offline/pending_operation_queue.dart';
import '../../../../core/routing/authenticated_route_resolver.dart';
import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/request_id.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/coach/domain/services/coach_notification_service.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/datasources/user_data_reset_service.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/canonical_finance_providers.dart';

class UserDataResetScreen extends ConsumerStatefulWidget {
  const UserDataResetScreen({this.resumeOnly = false, super.key});

  final bool resumeOnly;

  @override
  ConsumerState<UserDataResetScreen> createState() => _UserDataResetScreenState();
}

class _UserDataResetScreenState extends ConsumerState<UserDataResetScreen> {
  final _confirmationController = TextEditingController();
  String? _requestId;
  int? _expectedGeneration;
  bool _busy = false;
  bool _failed = false;
  bool _finishing = false;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    final profile = user == null
        ? null
        : ref.watch(canonicalUserProfileProvider(user.id)).valueOrNull;
    if (user != null) {
      ref.listen(canonicalUserProfileProvider(user.id), (previous, next) {
        final latest = next.valueOrNull;
        if (widget.resumeOnly &&
            !_busy &&
            latest?.resetStatus == 'ready' &&
            latest?.onboardingStatus == 'not_started' &&
            latest?.resetRequestId != null) {
          _finishLocally(user.id);
        }
      });
    }
    final inProgress = profile?.resetStatus == 'resetting';
    final resume = widget.resumeOnly || inProgress;
    final active = user == null
        ? Future<List<PendingOperation>>.value(const [])
        : getIt<PendingOperationDatabase>().activeForUser(user.id);

    return Scaffold(
      appBar: FinanceRouteHeader(
        title: resume ? l10n.resetProgressTitle : l10n.resetTitle,
        backLabel: l10n.back,
        onBack: () => context.go('/settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            resume ? Icons.sync : Icons.warning_amber_rounded,
            size: 48,
            color: resume
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 20),
          Text(
            resume ? l10n.resetProgressTitle : l10n.resetTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(resume ? l10n.resetProgressMessage : l10n.resetDescription),
          if (!resume) ...[
            const SizedBox(height: 12),
            Text(l10n.resetPreserveAccess),
          ],
          if (_failed) ...[
            const SizedBox(height: 20),
            Text(l10n.resetFailure, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FutureBuilder<List<PendingOperation>>(
            future: active,
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <PendingOperation>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!resume && rows.isNotEmpty) ...[
                    Text(
                      l10n.resetPendingWarning(rows.length),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!resume && snapshot.hasError) ...[
                    Text(
                      l10n.resetPendingCheckFailure,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton.icon(
                    key: const ValueKey('reset_user_data_button'),
                    onPressed:
                        _busy ||
                            user == null ||
                            profile == null ||
                            snapshot.connectionState == ConnectionState.waiting ||
                            snapshot.hasError ||
                            (!resume && rows.isNotEmpty)
                        ? null
                        : () => resume
                              ? _execute(user.id, profile)
                              : _confirmAndExecute(user.id, profile),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(resume ? Icons.refresh : Icons.delete_forever_outlined),
                    label: Text(
                      _busy
                          ? l10n.resetWorking
                          : resume
                          ? l10n.resetResume
                          : l10n.resetAction,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndExecute(String userId, UserProfile profile) async {
    final l10n = AppLocalizations.of(context);
    _confirmationController.clear();
    final typed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.resetConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.resetConfirmMessage),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmationController,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.resetTypePrompt),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: _confirmationController.text.trim().toUpperCase() == l10n.resetConfirmWord
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: Text(l10n.continueAction),
            ),
          ],
        ),
      ),
    );
    if (typed != true || !mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.resetFinalTitle),
        content: Text(l10n.resetFinalMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.resetAction),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;
    _requestId ??= newRequestId();
    _expectedGeneration ??= profile.dataGeneration;
    await _execute(userId, profile);
  }

  Future<void> _execute(String userId, UserProfile profile) async {
    final requestId = _requestId ??= profile.resetRequestId ?? newRequestId();
    final generation = _expectedGeneration ??=
        profile.resetPreviousGeneration ?? profile.dataGeneration;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await getIt<UserDataResetService>().reset(
        userId: userId,
        requestId: requestId,
        expectedGeneration: generation,
      );
      await _finishLocally(userId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _finishLocally(String userId) async {
    if (_finishing) return;
    _finishing = true;
    try {
      await getIt<PendingOperationDatabase>().clearUserData(userId);
      await getIt<CoachNotificationService>().clearUserData(userId);
      invalidateCachedUserProfile(userId);
      ref.invalidate(canonicalUserProfileProvider(userId));
      if (mounted) context.go('/onboarding');
    } catch (_) {
      _finishing = false;
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }
}
