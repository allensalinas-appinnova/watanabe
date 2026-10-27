import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/finance_route_header.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'device_providers.dart';

class MyDevicesScreen extends ConsumerWidget {
  const MyDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    final uid = user == null || user.isAnonymous ? null : user.id;
    final devices = uid == null ? null : ref.watch(deviceInstallationsProvider(uid));
    final failure = ref.watch(deviceRemovalControllerProvider);
    return Scaffold(
      appBar: FinanceRouteHeader(
        title: l10n.myDevicesTitle,
        backLabel: l10n.back,
        onBack: () => context.pop(),
      ),
      body: uid == null
          ? Center(child: Text(l10n.myDevicesRegisteredOnly))
          : devices!.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _MessageState(
                message: l10n.myDevicesLoadError,
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(deviceInstallationsProvider(uid)),
              ),
              data: (items) => ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  Text(
                    l10n.myDevicesActiveCount(items.length),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.myDevicesDescription),
                  const SizedBox(height: 8),
                  Text(l10n.myDevicesRetention),
                  if (failure != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      failure.message,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.myDevicesEmpty),
                      ),
                    )
                  else
                    ...items.map((device) {
                      final platform = switch (device.platform) {
                        'android' => l10n.myDevicesAndroid,
                        'ios' => l10n.myDevicesIos,
                        'web' => l10n.myDevicesWeb,
                        _ => l10n.myDevicesUnknown,
                      };
                      final lastSeen = device.lastSeenAt == null
                          ? l10n.myDevicesUnknown
                          : DateFormat.yMMMd(
                              Localizations.localeOf(context).toLanguageTag(),
                            ).add_jm().format(device.lastSeenAt!.toLocal());
                      return Card(
                        child: ListTile(
                          leading: Icon(_iconFor(device.platform)),
                          title: Text(platform),
                          subtitle: Text(l10n.myDevicesLastSeen(lastSeen)),
                          trailing: IconButton(
                            tooltip: l10n.myDevicesRemove,
                            onPressed: () => _confirmRemoval(context, ref, uid, device.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  IconData _iconFor(String platform) => switch (platform) {
    'android' => Icons.phone_android,
    'ios' => Icons.phone_iphone,
    'web' => Icons.computer,
    _ => Icons.devices_other,
  };

  Future<void> _confirmRemoval(BuildContext context, WidgetRef ref, String uid, String id) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.myDevicesRemoveTitle),
        content: Text(l10n.myDevicesRemoveWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.myDevicesRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final success = await ref.read(deviceRemovalControllerProvider.notifier).remove(id);
    if (!context.mounted) return;
    if (success) {
      ref.invalidate(deviceInstallationsProvider(uid));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.myDevicesRemoved)));
    }
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, required this.actionLabel, required this.onAction});
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
