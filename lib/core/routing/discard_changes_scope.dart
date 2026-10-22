import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

class DiscardChangesScope extends StatefulWidget {
  const DiscardChangesScope({required this.isDirty, required this.child, super.key});

  final bool isDirty;
  final Widget child;

  @override
  State<DiscardChangesScope> createState() => _DiscardChangesScopeState();
}

class _DiscardChangesScopeState extends State<DiscardChangesScope> {
  bool _allowPop = false;
  bool _showingDialog = false;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !widget.isDirty || _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && widget.isDirty) _confirmDiscard(result);
    },
    child: widget.child,
  );

  Future<void> _confirmDiscard(Object? result) async {
    if (_showingDialog) return;
    _showingDialog = true;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.discardChangesTitle),
        content: Text(l10n.discardChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.discardChanges),
          ),
        ],
      ),
    );
    _showingDialog = false;
    if (confirmed != true || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }
}
