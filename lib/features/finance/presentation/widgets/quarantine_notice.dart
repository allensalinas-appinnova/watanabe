import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/offline/pending_operation_queue.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../l10n/generated/app_localizations.dart';

final quarantineCountProvider = StreamProvider<int>(
  (ref) => GetIt.I.isRegistered<PendingOperationDatabase>()
      ? GetIt.I<PendingOperationDatabase>().watchQuarantineCount()
      : Stream.value(0),
);

class QuarantineNotice extends ConsumerWidget {
  const QuarantineNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if ((ref.watch(quarantineCountProvider).valueOrNull ?? 0) == 0) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.quarantineMessage),
            TextButton(
              onPressed: () async {
                final accepted = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    content: Text(l.quarantineConfirm),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(l.quarantineDiscard),
                      ),
                    ],
                  ),
                );
                if (accepted == true) await GetIt.I<PendingOperationDatabase>().discardQuarantine();
              },
              child: Text(l.quarantineDiscard),
            ),
          ],
        ),
      ),
    );
  }
}
