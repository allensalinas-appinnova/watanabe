import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/auth/presentation/widgets/account_identity_card.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalMoreScreen extends ConsumerWidget {
  const CanonicalMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    final isGuest = user?.isAnonymous ?? false;
    final pending = ref.watch(pendingOperationsProvider).valueOrNull ?? const [];
    final pendingCount = pending
        .where((operation) => operation.status == 'pending' || operation.status == 'syncing')
        .length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: FinanceRouteHeader(
        title: l10n.settingsTitle,
        backLabel: l10n.back,
        onBack: () => popOrGo(context, '/home'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          if (const bool.fromEnvironment('PUBLIC_HELP_ENABLED', defaultValue: true)) ...[
            TextButton(
              onPressed: () => launchUrl(Uri.parse('https://lumiomoney-support.web.app/privacy')),
              child: Text(l10n.privacyTitle),
            ),
            TextButton(
              onPressed: () => launchUrl(Uri.parse('https://lumiomoney-support.web.app/support')),
              child: Text(l10n.supportTitle),
            ),
          ],
          if (user != null) ...[
            AccountIdentityCard(
              user: user,
              onSaveAccount: () => context.push('/settings/secure-account'),
              onAccessMethods: () => context.push('/settings/access-methods'),
            ),
            const SizedBox(height: 16),
          ],
          OutlinedButton.icon(
            key: const ValueKey('settings_resource_usage'),
            onPressed: () => context.push('/settings/usage'),
            icon: const Icon(Icons.storage_outlined),
            label: Text(l10n.resourceUsageTitle),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('settings_appearance'),
            onPressed: () => context.push('/settings/appearance'),
            icon: const Icon(Icons.palette_outlined),
            label: Text(l10n.appearanceTitle),
          ),
          if (user != null && !isGuest) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('settings_my_devices'),
              onPressed: () => context.push('/settings/devices'),
              icon: const Icon(Icons.devices_outlined),
              label: Text(l10n.myDevicesTitle),
            ),
          ],
          const SizedBox(height: 32),
          Text(
            l10n.moreManagement,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('more_manage_categories'),
            onPressed: () => context.push('/categories'),
            child: Text(l10n.manageCategories),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('more_customize_home'),
            onPressed: () => context.push('/home-preferences'),
            child: Text(l10n.homeCustomizeTitle),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('more_coach'),
            onPressed: () => context.go('/coach'),
            child: Text(l10n.coachTab),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('settings_coach_reminders'),
            onPressed: () => context.push('/coach/settings'),
            child: Text(l10n.coachTitle),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.moreSession,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('more_sign_out'),
            onPressed: user == null
                ? null
                : () => _confirmSignOut(context, ref, pendingCount, isGuest),
            child: Text(l10n.signOut),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.resetSectionTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (const bool.fromEnvironment('ACCOUNT_DELETION_ENABLED')) ...[
            OutlinedButton.icon(
              key: const ValueKey('settings_delete_account'),
              onPressed: () => context.push('/settings/delete-account'),
              icon: const Icon(Icons.person_remove_outlined),
              label: Text(l10n.deletionTitle),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            key: const ValueKey('settings_reset_user_data'),
            onPressed: () => context.push('/settings/reset-data'),
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(l10n.resetTitle),
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    int pendingCount,
    bool isGuest,
  ) async {
    final l10n = AppLocalizations.of(context);
    final session = ref.read(authSessionProvider).valueOrNull;
    if (session == null) return;
    final decision = await showDialog<_SignOutDecision>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        scrollable: true,
        content: Consumer(
          builder: (context, dialogRef, _) {
            final current = dialogRef.watch(authSessionProvider).valueOrNull;
            final email = current?.id == session.id && !isGuest ? current?.email?.trim() : null;
            return Text(
              [
                if (email != null && email.isNotEmpty) l10n.settingsSignOutAccount(email),
                _signOutMessage(l10n, pendingCount, isGuest),
              ].join('\n\n'),
            );
          },
        ),
        actions: [
          TextButton(
            key: const ValueKey('settings_sign_out_cancel'),
            onPressed: () => Navigator.pop(dialogContext, _SignOutDecision.cancel),
            child: Text(l10n.cancel),
          ),
          if (isGuest)
            TextButton(
              key: const ValueKey('guest_sign_out_save_account'),
              onPressed: () => Navigator.pop(dialogContext, _SignOutDecision.secureAccount),
              child: Text(l10n.guestSaveAccount),
            ),
          FilledButton(
            key: const ValueKey('settings_sign_out_confirm'),
            onPressed: () => Navigator.pop(dialogContext, _SignOutDecision.signOut),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (decision == null || decision == _SignOutDecision.cancel || !context.mounted) return;
    if (ref.read(authSessionProvider).valueOrNull?.id != session.id) return;
    if (decision == _SignOutDecision.secureAccount) {
      unawaited(context.push('/settings/secure-account'));
      return;
    }

    await ref.read(authControllerProvider.notifier).signOut();
    if (!context.mounted) return;
    if (ref.read(authControllerProvider).status == AuthActionStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.genericError)));
    }
  }

  String _signOutMessage(AppLocalizations l10n, int pendingCount, bool isGuest) {
    final messages = <String>[
      if (isGuest) l10n.guestSignOutWarning,
      if (pendingCount > 0) l10n.signOutPendingWarning(pendingCount),
      if (!isGuest && pendingCount == 0) l10n.signOutConfirmMessage,
    ];
    return messages.join('\n\n');
  }
}

enum _SignOutDecision { cancel, signOut, secureAccount }
