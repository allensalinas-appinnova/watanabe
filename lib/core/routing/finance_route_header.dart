import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

class FinanceRouteHeader extends StatelessWidget implements PreferredSizeWidget {
  const FinanceRouteHeader({
    required this.title,
    required this.backLabel,
    required this.onBack,
    this.backButtonKey,
    this.titleKey,
    super.key,
  });

  final String title;
  final String backLabel;
  final VoidCallback onBack;
  final Key? backButtonKey;
  final Key? titleKey;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 52,
    automaticallyImplyLeading: false,
    leadingWidth: 56,
    leading: IconButton(
      key: backButtonKey,
      tooltip: backLabel,
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back, color: AppColors.navy),
    ),
    title: Text(title, key: titleKey),
    titleSpacing: 0,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  );
}

void popOrGo(BuildContext context, String fallbackLocation) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallbackLocation);
  }
}
