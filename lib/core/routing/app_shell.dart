import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/global_fab_visibility.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/async_value_extensions.dart';
import '../../core/utils/currency_formatter.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/finance/domain/entities/financial_operation.dart';
import '../../features/finance/presentation/models/movement_save_result.dart';
import '../../features/finance/presentation/providers/canonical_finance_providers.dart';
import '../../features/finance/presentation/widgets/finance_components.dart';
import '../../features/finance/presentation/widgets/movement_action_sheet.dart';
import '../../l10n/generated/app_localizations.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _addMovementFocus = FocusNode(debugLabel: 'globalAddMovement');
  bool _showingSheet = false;
  bool _openingForm = false;

  @override
  void dispose() {
    _addMovementFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pendingOperationAutoSyncProvider);
    final showFab = ref.watch(globalFabVisibleProvider);
    final pendingOperations = ref.watch(pendingOperationsProvider).valueOrNull ?? const [];
    final activePending = pendingOperations
        .where((operation) => operation.status == 'pending' || operation.status == 'syncing')
        .length;
    final rejected = pendingOperations.any((operation) => operation.status == 'rejected');
    return Scaffold(
      body: Column(
        children: [
          if (activePending > 0 || rejected)
            Material(
              color: rejected ? const Color(0xFFFFF1F0) : AppColors.blueSoft,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Icon(
                        rejected ? Icons.warning_amber_rounded : Icons.sync,
                        color: rejected ? const Color(0xFFC73338) : AppColors.blueDark,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          rejected
                              ? AppLocalizations.of(context).offlineRejected
                              : AppLocalizations.of(context).pendingBalanceNote,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => widget.navigationShell.goBranch(1),
                        child: Text(AppLocalizations.of(context).viewPendingOperations),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: widget.navigationShell),
        ],
      ),
      floatingActionButton: _showingSheet || _openingForm
          ? null
          : ExcludeSemantics(
              excluding: !showFab,
              child: IgnorePointer(
                ignoring: !showFab,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  offset: showFab ? Offset.zero : const Offset(0, 1.5),
                  child: AnimatedOpacity(
                    key: const ValueKey('global_add_operation_visibility'),
                    duration: const Duration(milliseconds: 180),
                    opacity: showFab ? 1 : 0,
                    child: Semantics(
                      button: true,
                      label: AppLocalizations.of(context).addMovement,
                      child: FloatingActionButton(
                        key: const ValueKey('global_add_operation'),
                        focusNode: _addMovementFocus,
                        tooltip: AppLocalizations.of(context).addMovement,
                        onPressed: _openMovementActions,
                        child: const Icon(Icons.add),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: FinanceBottomNavigation(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          ref.read(globalFabVisibleProvider.notifier).setVisible(true);
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
      ),
    );
  }

  Future<void> _openMovementActions() async {
    if (_showingSheet || _openingForm || !mounted) return;
    setState(() => _showingSheet = true);
    final action = await MovementActionSheet.show(context);
    if (!mounted) return;
    setState(() => _showingSheet = false);
    _addMovementFocus.requestFocus();
    if (action == null) return;

    final route = switch (action) {
      OperationType.income => '/operations/new?type=income',
      OperationType.expense => '/operations/new?type=expense',
      OperationType.transfer => '/transfers/new',
    };
    setState(() => _openingForm = true);
    try {
      final result = await context.push<MovementSaveResult>(route);
      if (mounted && result != null) {
        if (result.status == MovementSaveStatus.confirmed) _refreshActivityPages();
        _showSaveFeedback(result);
      }
    } finally {
      if (mounted) setState(() => _openingForm = false);
    }
  }

  void _refreshActivityPages() {
    final user = ref.read(authSessionProvider).valueOrNull;
    if (user == null) return;
    ref.invalidate(
      canonicalOperationsPageProvider((
        userId: user.id,
        cursor: null,
        monthKey: null,
        currency: null,
        type: null,
        accountIds: null,
        pageSize: 10,
      )),
    );
    for (final type in const <OperationType?>[
      null,
      OperationType.income,
      OperationType.expense,
    ]) {
      ref.invalidate(operationsPagerProvider((userId: user.id, type: type)));
    }
  }

  void _showSaveFeedback(MovementSaveResult result) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (result.status == MovementSaveStatus.pending) {
      messenger.showSnackBar(
        SnackBar(
          showCloseIcon: true,
          content: Text(l10n.savedPending),
          action: SnackBarAction(
            label: l10n.viewPendingOperations,
            onPressed: () => widget.navigationShell.goBranch(1),
          ),
        ),
      );
      return;
    }

    final amount = CurrencyFormatter.formatMinor(result.amountMinor, result.currency);
    final message = switch (result.type) {
      OperationType.income => l10n.incomeRegistered(amount),
      OperationType.expense => l10n.expenseRegistered(amount),
      OperationType.transfer => l10n.transferRegistered,
    };
    final isVisibleInActivity =
        widget.navigationShell.currentIndex != 1 ||
        _isIncludedByActivityFilter(ref.read(activityTypeFilterProvider), result.type);
    final content = isVisibleInActivity
        ? message
        : '${l10n.notVisibleWithCurrentFilters} · $message';

    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: true,
        content: Text(content),
        action: isVisibleInActivity
            ? SnackBarAction(
                label: result.type == OperationType.transfer ? l10n.viewDetails : l10n.viewMovement,
                onPressed: () => _showMovementReceipt(result),
              )
            : null,
      ),
    );
  }

  bool _isIncludedByActivityFilter(OperationType? filter, OperationType type) =>
      filter == null || filter == type;

  Future<void> _showMovementReceipt(MovementSaveResult result) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final amount = CurrencyFormatter.formatMinor(result.amountMinor, result.currency);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.type == OperationType.transfer ? l10n.transferMoney : result.description,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(amount, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (result.type == OperationType.transfer) ...[
              _ReceiptLine(label: l10n.sourceAccount, value: result.sourceAccountName ?? '—'),
              _ReceiptLine(
                label: l10n.destinationAccount,
                value: result.destinationAccountName ?? '—',
              ),
            ] else ...[
              _ReceiptLine(label: l10n.account, value: result.accountName ?? '—'),
              _ReceiptLine(label: l10n.category, value: result.categoryName ?? '—'),
            ],
            _ReceiptLine(
              label: l10n.date,
              value: MaterialLocalizations.of(context).formatMediumDate(result.occurredAt),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}
