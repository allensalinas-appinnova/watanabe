import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../../../core/offline/pending_operation_queue.dart';
import '../../../../core/offline/pending_operation_sync_service.dart';
import '../../../../core/routing/authenticated_route_resolver.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/request_id.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../coach/domain/services/coach_notification_service.dart';
import '../../../document_imports/domain/document_import.dart';
import '../../../finance/presentation/providers/canonical_finance_providers.dart';
import '../../domain/services/account_deletion_repository.dart';
import '../providers/auth_providers.dart';

class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});
  @override
  ConsumerState<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final _password = TextEditingController();
  String _requestId = newRequestId();
  bool _attempted = false, _loadedCommand = false, _generationConflict = false;
  String? _uid;
  int? _generation;
  bool _confirmed = false, _busy = false, _failed = false, _accepted = false;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), user = ref.watch(authSessionProvider).valueOrNull;
    final profileReady = user != null && ref.watch(canonicalUserProfileProvider(user.id)).hasValue;
    final providers = getIt<FirebaseAuth>().currentUser?.providerData ?? const <UserInfo>[];
    final passwordRequired =
        providers.any((p) => p.providerId == 'password') &&
        !providers.any((p) => p.providerId == 'apple.com');
    return Scaffold(
      appBar: AppBar(title: Text(l.deletionTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(_accepted ? l.deletionAccepted : l.deletionExplanation),
            const SizedBox(height: 16),
            if (!_accepted) ...[
              if (user?.email != null) SelectableText(user!.email!),
              if (passwordRequired)
                TextField(
                  controller: _password,
                  onChanged: (_) => setState(() {}),
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(labelText: l.deletionPassword),
                ),
              CheckboxListTile(
                value: _confirmed,
                onChanged: _busy ? null : (v) => setState(() => _confirmed = v ?? false),
                title: Text(l.deletionConfirmation),
              ),
              if (_failed)
                Text(
                  _generationConflict ? l.deletionChanged : l.deletionFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_generationConflict)
                TextButton(
                  onPressed: () async {
                    if (getIt.isRegistered<SharedPreferences>()) {
                      await getIt<SharedPreferences>().remove(
                        FirebaseBootstrap.lifecyclePreferenceKey('deletion_command'),
                      );
                    }
                    if (!mounted) return;
                    setState(() {
                      _generation = null;
                      _requestId = newRequestId();
                      _attempted = false;
                      _generationConflict = false;
                      _failed = false;
                    });
                    if (user != null) ref.invalidate(canonicalUserProfileProvider(user.id));
                  },
                  child: Text(l.deletionReload),
                ),
              FilledButton(
                onPressed:
                    !_confirmed ||
                        _busy ||
                        user == null ||
                        !profileReady ||
                        (passwordRequired && _password.text.isEmpty)
                    ? null
                    : _delete,
                child: _busy ? const CircularProgressIndicator() : Text(l.deletionSubmit),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final user = ref.read(authSessionProvider).valueOrNull;
    if (user == null || (_uid != null && _uid != user.id)) return;
    _uid ??= user.id;
    if (!_loadedCommand && getIt.isRegistered<SharedPreferences>()) {
      _loadedCommand = true;
      try {
        final stored = getIt<SharedPreferences>().getString(
          FirebaseBootstrap.lifecyclePreferenceKey('deletion_command'),
        );
        if (stored != null) {
          final command = jsonDecode(stored) as Map<String, dynamic>;
          if (command['uid'] == user.id &&
              command['requestId'] is String &&
              command['generation'] is int) {
            _requestId = command['requestId'] as String;
            _generation = command['generation'] as int;
            _attempted = true;
          }
        }
      } catch (_) {
        /* Keep a new isolated command if local metadata is malformed. */
      }
    }
    _generation ??= ref.read(canonicalUserProfileProvider(user.id)).valueOrNull?.dataGeneration;
    if (_generation == null) {
      setState(() => _failed = true);
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      Future<void> reauthenticate() async {
        final reauth = await auth.reauthenticateForDeletion(
          password: _password.text.isEmpty ? null : _password.text,
        );
        reauth.match((f) => throw StateError(f.message), (_) {});
      }

      if (!_attempted) await reauthenticate();
      if (ref.read(authSessionProvider).valueOrNull?.id != user.id) {
        throw StateError('session-changed');
      }
      if (getIt.isRegistered<SharedPreferences>()) {
        await getIt<SharedPreferences>().setString(
          FirebaseBootstrap.lifecyclePreferenceKey('deletion_command'),
          jsonEncode({'uid': user.id, 'requestId': _requestId, 'generation': _generation}),
        );
      }
      _attempted = true;
      var result = await getIt<AccountDeletionRepository>().request(
        userId: user.id,
        requestId: _requestId,
        expectedGeneration: _generation!,
      );
      final requiresRecentLogin = result.match(
        (f) => f.technicalCode == 'requires-recent-login',
        (_) => false,
      );
      if (requiresRecentLogin) {
        await reauthenticate();
        result = await getIt<AccountDeletionRepository>().request(
          userId: user.id,
          requestId: _requestId,
          expectedGeneration: _generation!,
        );
      }
      result.match((f) {
        _generationConflict = f.technicalCode == 'account-deletion-generation-conflict';
        throw StateError(f.message);
      }, (_) {});
      if (mounted) setState(() => _accepted = true);
      // Acceptance is durable; never send pending records after this point.
      getIt<PendingOperationSyncService>().setSession(null);
      await getIt<SharedPreferences>().setBool(
        FirebaseBootstrap.lifecyclePreferenceKey('deletion_accepted'),
        true,
      );
      await getIt<SharedPreferences>().setString(
        FirebaseBootstrap.lifecyclePreferenceKey('deleting_local_uid'),
        user.id,
      );
      await getIt<SharedPreferences>().setBool(
        FirebaseBootstrap.lifecyclePreferenceKey('clear_firestore_cache_on_start'),
        true,
      );
      await getIt<PendingOperationDatabase>().clearUserData(user.id);
      if (getIt.isRegistered<DocumentImportRepository>()) {
        await getIt<DocumentImportRepository>().clearDraft(user.id);
      }
      if (getIt.isRegistered<CoachNotificationService>()) {
        await getIt<CoachNotificationService>().clearUserData(user.id);
      }
      invalidateCachedUserProfile(user.id);
      await getIt<SharedPreferences>().remove(
        FirebaseBootstrap.lifecyclePreferenceKey('deleting_local_uid'),
      );
      await getIt<SharedPreferences>().remove(
        FirebaseBootstrap.lifecyclePreferenceKey('deletion_command'),
      );
      final sameUser = getIt<FirebaseAuth>().currentUser?.uid == user.id;
      if (sameUser) await auth.signOut();
      if (mounted && sameUser) context.go('/login');
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
