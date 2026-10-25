import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalMoreScreen extends ConsumerWidget {
  const CanonicalMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
          Text(
            l10n.moreSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('settings_appearance'),
            onPressed: () => context.push('/settings/appearance'),
            icon: const Icon(Icons.palette_outlined),
            label: Text(l10n.appearanceTitle),
          ),
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
            onPressed: () => _confirmSignOut(context, ref, pendingCount),
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

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref, int pendingCount) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(
          pendingCount > 0 ? l10n.signOutPendingWarning(pendingCount) : l10n.signOutConfirmMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(authControllerProvider.notifier).signOut();
    if (!context.mounted) return;
    if (ref.read(authControllerProvider).status == AuthActionStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.genericError)));
    }
  }
}
