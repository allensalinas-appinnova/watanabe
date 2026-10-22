import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final globalFabVisibleProvider = NotifierProvider<GlobalFabVisibilityNotifier, bool>(
  GlobalFabVisibilityNotifier.new,
);

class GlobalFabVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setVisible(bool visible) {
    if (state != visible) state = visible;
  }
}

/// Keeps the shared add action out of the way while a section is scrolling.
class GlobalFabScrollObserver extends StatelessWidget {
  const GlobalFabScrollObserver({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
    onNotification: (notification) {
      final container = ProviderScope.containerOf(context, listen: false);
      void updateVisibility(bool visible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            container.read(globalFabVisibleProvider.notifier).setVisible(visible);
          }
        });
      }

      if (notification is ScrollStartNotification || notification is ScrollUpdateNotification) {
        updateVisibility(false);
      } else if (notification is ScrollEndNotification) {
        updateVisibility(true);
      }
      return false;
    },
    child: child,
  );
}
