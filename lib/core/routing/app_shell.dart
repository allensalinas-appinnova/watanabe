import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/async_value_extensions.dart';
import '../../core/utils/currency_formatter.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/finance/domain/entities/finance_category.dart';
import '../../features/finance/domain/entities/financial_operation.dart';
import '../../features/finance/presentation/models/movement_save_result.dart';
import '../../features/finance/presentation/providers/canonical_finance_providers.dart';
import '../../features/finance/presentation/widgets/finance_components.dart';
import '../../features/finance/presentation/widgets/movement_action_sheet.dart';
import '../../l10n/generated/app_localizations.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, this.currentLocation = '/home', super.key});

  final StatefulNavigationShell navigationShell;
  final String currentLocation;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _showingSheet = false;
  bool _openingForm = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(pendingOperationAutoSyncProvider);
    final sessionUser = ref.watch(authSessionProvider).valueOrNull;
    final profile = sessionUser == null
        ? null
        : ref.watch(canonicalUserProfileProvider(sessionUser.id)).valueOrNull;
    final categoryCatalogSync =
        profile != null && profile.categoryCatalogVersion < currentCategoryCatalogVersion
        ? ref.watch(
            categoryCatalogSyncProvider((
              userId: profile.id,
              locale: profile.locale,
              countryCode: profile.countryCode,
            )),
          )
        : null;
    final pendingOperations = ref.watch(pendingOperationsProvider).valueOrNull ?? const [];
    final activePending = pendingOperations
        .where((operation) => operation.status == 'pending' || operation.status == 'syncing')
        .length;
    final rejected = pendingOperations.any((operation) => operation.status == 'rejected');
    final hasSyncNotice = activePending > 0 || rejected;
    final planningFollowUpSheetOpen = ref.watch(planningFollowUpSheetOpenProvider);
    final isSectionRoot = const {
      '/home',
      '/activity',
      '/accounts',
      '/budgets',
      '/budgets/agenda',
      '/budgets/debt-payments',
      '/coach',
    }.contains(widget.currentLocation);
    final showRegisterAction =
        (widget.currentLocation == '/home' || widget.currentLocation == '/activity') &&
        !_showingSheet &&
        !planningFollowUpSheetOpen &&
        !_openingForm;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (categoryCatalogSync?.hasError == true)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(AppLocalizations.of(context).categoryCatalogSyncMessage),
                      ),
                      TextButton(
                        onPressed: () {
                          if (profile != null) {
                            ref.invalidate(
                              categoryCatalogSyncProvider((
                                userId: profile.id,
                                locale: profile.locale,
                                countryCode: profile.countryCode,
                              )),
                            );
                          }
                        },
                        child: Text(AppLocalizations.of(context).retry),
                      ),
                    ],
                  ),
                ),
              ),
            if (hasSyncNotice)
              Material(
                color: rejected
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Icon(
                        rejected ? Icons.warning_amber_rounded : Icons.sync,
                        color: rejected
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          rejected
                              ? AppLocalizations.of(context).offlineRejected
                              : AppLocalizations.of(context).pendingBalanceNote,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
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
            if (isSectionRoot)
              SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).appTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('global_settings_action'),
                        tooltip: AppLocalizations.of(context).settingsTitle,
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.settings_outlined, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: widget.navigationShell),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showRegisterAction)
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('global_add_operation'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _openMovementActions,
                    icon: const Icon(Icons.add),
                    label: Text(AppLocalizations.of(context).registerMovement),
                  ),
                ),
              ),
            ),
          FinanceBottomNavigation(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: (index) => widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMovementActions() async {
    if (_showingSheet || _openingForm || !mounted) return;
    setState(() => _showingSheet = true);
    final action = await MovementActionSheet.show(context);
    if (!mounted) return;
    setState(() => _showingSheet = false);
    if (action == null) return;

    final route = switch (action) {
      MovementEntryAction.income => '/operations/new?type=income',
      MovementEntryAction.expense => '/operations/new?type=expense',
      MovementEntryAction.transfer => '/transfers/new',
      MovementEntryAction.debtPayment => '/accounts/pay-debt',
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
    invalidateOperationLists(ref, user.id);
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
      OperationType.expenseRefund => l10n.debtRefund,
      OperationType.debtAdjustment => l10n.debtAdjust,
      OperationType.unallocatedDebtPayment => l10n.unallocatedPaymentStatus,
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
                color: Theme.of(context).colorScheme.onSurface,
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
