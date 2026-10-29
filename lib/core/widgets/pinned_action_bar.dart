import 'package:flutter/material.dart';

/// A persistent primary action placed above the app's bottom navigation.
class PinnedActionBar extends StatelessWidget {
  const PinnedActionBar({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.buttonKey,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 8),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: buttonKey,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}
