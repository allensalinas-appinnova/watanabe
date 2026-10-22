import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/offline/sync_state.dart';
import '../../../../core/routing/global_fab_visibility.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/activity_report.dart';
import '../../domain/entities/balance_adjustment.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../providers/canonical_finance_providers.dart';
import '../services/activity_csv_save_service.dart';
import '../services/activity_csv_share_service.dart';
import '../utils/activity_csv_exporter.dart';
import '../widgets/activity_export_review_sheet.dart';
import '../widgets/finance_category_icon.dart';
import '../widgets/sync_issue_localization.dart';

class CanonicalActivityScreen extends ConsumerStatefulWidget {
  const CanonicalActivityScreen({super.key});

  @override
  ConsumerState<CanonicalActivityScreen> createState() => _CanonicalActivityScreenState();
}

class _CanonicalActivityScreenState extends ConsumerState<CanonicalActivityScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNearEnd);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreWhenNearEnd)
      ..dispose();
    super.dispose();
  }

  void _loadMoreWhenNearEnd() {
    if (!_scrollController.hasClients || _scrollController.position.extentAfter >= 400) return;
    final user = ref.read(authSessionProvider).valueOrNull;
    if (user != null) {
      final selectedType = ref.read(activityTypeFilterProvider);
      ref.read(operationsPagerProvider((userId: user.id, type: selectedType)).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));

    final selectedType = ref.watch(activityTypeFilterProvider);
    final adjustmentsOnly = ref.watch(activityBalanceAdjustmentsOnlyProvider);
    final queryFilters = ref.watch(activityQueryFiltersProvider);
    final pagerProvider = operationsPagerProvider((userId: user.id, type: selectedType));
    final pager = ref.watch(pagerProvider);
    final reportProvider = activityReportProvider(user.id);
    final report = ref.watch(reportProvider);
    final accounts =
        ref.watch(canonicalAccountsProvider(user.id)).valueOrNull ?? const <FinanceAccount>[];
    final categories =
        ref.watch(canonicalCategoriesProvider(user.id)).valueOrNull ?? const <FinanceCategory>[];
    final syncStatus = ref.watch(pendingOperationSyncStatusProvider).valueOrNull;
    final pendingOperations = ref.watch(pendingOperationsProvider).valueOrNull ?? const [];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(pagerProvider.notifier).refresh(),
          child: GlobalFabScrollObserver(
            child: CustomScrollView(
              key: const ValueKey('canonical_activity_scroll_view'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.activity,
                          key: const ValueKey('activity_title'),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.activitySubtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ActivityTypeFilters(
                          selectedType: selectedType,
                          adjustmentsOnly: adjustmentsOnly,
                          onSelected: (type) {
                            ref.read(activityBalanceAdjustmentsOnlyProvider.notifier).select(false);
                            if (selectedType == type) return;
                            for (final filter in const <OperationType?>[
                              null,
                              OperationType.income,
                              OperationType.expense,
                            ]) {
                              ref.invalidate(
                                operationsPagerProvider((userId: user.id, type: filter)),
                              );
                            }
                            ref.read(activityTypeFilterProvider.notifier).select(type);
                            if (_scrollController.hasClients) _scrollController.jumpTo(0);
                          },
                          onAdjustmentsSelected: (value) {
                            ref.read(activityBalanceAdjustmentsOnlyProvider.notifier).select(value);
                            if (value) ref.read(activityTypeFilterProvider.notifier).select(null);
                            ref.invalidate(reportProvider);
                            if (_scrollController.hasClients) _scrollController.jumpTo(0);
                          },
                        ),
                        const SizedBox(height: 8),
                        _ActivityQueryFilterButton(
                          accountLabel: _activityAccountLabel(
                            accounts,
                            queryFilters.accountIds,
                            l10n,
                          ),
                          periodLabel: _activityPeriodLabel(queryFilters, context),
                          onPressed: () => context.push('/activity/filters'),
                        ),
                        if (queryFilters.hasBeenApplied) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.activityFilterSelectedDetails(
                              _activityAccountLabel(
                                accounts,
                                queryFilters.accountIds,
                                l10n,
                              ),
                              _activityPeriodRangeLabel(queryFilters, context),
                            ),
                            key: const ValueKey('activity_filter_summary'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: report.when(
                      loading: () => const _ActivityReportLoading(),
                      error: (_, _) => _ActivityReportError(
                        message: l10n.genericError,
                        retryLabel: l10n.retry,
                        onRetry: () => ref.invalidate(reportProvider),
                      ),
                      data: (value) => _ActivityReportSummary(report: value),
                    ),
                  ),
                ),
                if (syncStatus != null &&
                    (syncStatus.pending > 0 || syncStatus.syncing > 0 || syncStatus.rejected > 0))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: _ActivitySyncBanner(
                        status: syncStatus,
                        issue: firstSyncFailure(
                          pendingOperations.map((operation) => operation.lastError),
                        ),
                        onRetry: () => ref.read(canonicalActionsProvider).syncPending(user.id),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                    child: _ActivityMovementsHeader(
                      report: report,
                      onExport:
                          report.valueOrNull == null ||
                              (report.valueOrNull!.operations.isEmpty &&
                                  report.valueOrNull!.adjustments.isEmpty)
                          ? null
                          : () => _showExportReview(
                              userId: user.id,
                              accounts: accounts,
                              categories: categories,
                              report: report.valueOrNull!,
                              queryFilters: queryFilters,
                              selectedType: selectedType,
                              adjustmentsOnly: adjustmentsOnly,
                              l10n: l10n,
                            ),
                    ),
                  ),
                ),
                if (report.valueOrNull?.adjustments.isNotEmpty == true) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                      child: Text(
                        l10n.activityBalanceAdjustmentsHeader,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    sliver: SliverList.builder(
                      itemCount: report.valueOrNull!.adjustments.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BalanceAdjustmentCard(
                          key: ValueKey(
                            'balance_adjustment_${report.valueOrNull!.adjustments[index].requestId}_${report.valueOrNull!.adjustments[index].adjustment.accountId}',
                          ),
                          entry: report.valueOrNull!.adjustments[index],
                          accounts: accounts,
                          locale: Localizations.localeOf(context).toString(),
                          l10n: l10n,
                        ),
                      ),
                    ),
                  ),
                ],
                if (adjustmentsOnly)
                  if (report.valueOrNull?.adjustments.isEmpty ?? true)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ActivityMessage(message: l10n.activityBalanceAdjustmentsEmpty),
                    )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 96))
                else
                  pager.when(
                    loading: () => const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ActivityMessage(
                        message: l10n.genericError,
                        actionLabel: l10n.retry,
                        onAction: () => ref.read(pagerProvider.notifier).refresh(),
                      ),
                    ),
                    data: (page) => page.items.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: _ActivityMessage(message: l10n.noTransactions),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 104),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index >= page.items.length) {
                                    return SizedBox(
                                      height: 64,
                                      child: Center(
                                        child: page.errorMessage == null
                                            ? const CircularProgressIndicator()
                                            : TextButton(
                                                onPressed: () =>
                                                    ref.read(pagerProvider.notifier).loadMore(),
                                                child: Text(l10n.retry),
                                              ),
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _ActivityOperationCard(
                                      key: ValueKey('activity_operation_${page.items[index].id}'),
                                      operation: page.items[index],
                                      accounts: accounts,
                                      categories: categories,
                                      locale: Localizations.localeOf(context).toString(),
                                      l10n: l10n,
                                    ),
                                  );
                                },
                                childCount:
                                    page.items.length +
                                    (page.hasMore || page.isLoadingMore || page.errorMessage != null
                                        ? 1
                                        : 0),
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showExportReview({
    required String userId,
    required List<FinanceAccount> accounts,
    required List<FinanceCategory> categories,
    required ActivityReport report,
    required ActivityQueryFilters queryFilters,
    required OperationType? selectedType,
    required bool adjustmentsOnly,
    required AppLocalizations l10n,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Activity lives inside the indexed shell navigator. Put the modal on
      // the root navigator so it covers the shell's global FAB and tab bar;
      // otherwise those persistent controls paint over the sheet's actions.
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ActivityExportReviewSheet(
        report: report,
        accountLabel: _activityAccountLabel(accounts, queryFilters.accountIds, l10n),
        periodLabel: _activityPeriodRangeLabel(queryFilters, context),
        typeLabel: adjustmentsOnly
            ? l10n.activityBalanceAdjustmentType
            : selectedType == null
            ? l10n.activityFilterAll
            : selectedType == OperationType.income
            ? l10n.income
            : l10n.expense,
        accounts: accounts,
        categories: categories,
        locale: Localizations.localeOf(context).toString(),
        onExport: ({required operations, required action}) async {
          final content = ActivityCsvExporter.export(
            operations: operations,
            adjustments: report.adjustments,
            accounts: accounts,
            categories: categories,
            labels: ActivityCsvLabels(
              date: l10n.activityCsvDate,
              type: l10n.activityCsvType,
              description: l10n.activityCsvDescription,
              account: l10n.activityCsvAccount,
              category: l10n.activityCsvCategory,
              amount: l10n.activityCsvAmount,
              currency: l10n.activityCsvCurrency,
              status: l10n.activityCsvStatus,
              income: l10n.income,
              expense: l10n.expense,
              transfer: l10n.transferOperationLabel,
              pending: l10n.activityCsvPending,
              confirmed: l10n.activityCsvConfirmed,
              rejected: l10n.activityCsvRejected,
              unknownAccount: l10n.activityCsvUnknownAccount,
              unknownCategory: l10n.activityCsvUnknownCategory,
              balanceAdjustment: l10n.activityBalanceAdjustmentType,
              previousBalance: l10n.balanceAdjustmentPrevious,
              targetBalance: l10n.balanceAdjustmentTarget,
              difference: l10n.balanceAdjustmentDifferenceLabel,
            ),
          );
          final now = DateTime.now();
          final fileName =
              'lumiomoney-activity-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
          return switch (action) {
            ActivityExportAction.save =>
              ref
                  .read(activityCsvSaveServiceProvider)
                  .saveCsv(fileName: fileName, contents: content),
            ActivityExportAction.share => _shareExport(
              fileName: fileName,
              contents: content,
              subject: l10n.activityShareSubject,
            ),
          };
        },
      ),
    );
  }

  Future<bool> _shareExport({
    required String fileName,
    required String contents,
    required String subject,
  }) async {
    await ref
        .read(activityCsvShareServiceProvider)
        .shareCsv(fileName: fileName, contents: contents, subject: subject);
    return true;
  }
}

class _ActivityMovementsHeader extends StatelessWidget {
  const _ActivityMovementsHeader({required this.report, required this.onExport});

  final AsyncValue<ActivityReport> report;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = report.valueOrNull == null
        ? null
        : report.valueOrNull!.operations.length + report.valueOrNull!.adjustments.length;
    return Row(
      children: [
        Expanded(
          child: Text(
            count == null ? l10n.activityMovements : l10n.activityMovementCount(count),
            key: const ValueKey('activity_movement_count'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton.icon(
          key: const ValueKey('activity_export_open'),
          onPressed: onExport,
          icon: const Icon(Icons.download_outlined),
          label: Text(l10n.activityExportAction),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
      ],
    );
  }
}

class _ActivityReportSummary extends StatelessWidget {
  const _ActivityReportSummary({required this.report});

  final ActivityReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final totals = report.totalsByCurrency.values.toList();
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.activityTotalsTitle, style: Theme.of(context).textTheme.titleSmall),
            if (totals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.activityTotalsEmpty),
              )
            else
              for (final total in totals) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(total.currency, style: Theme.of(context).textTheme.labelLarge),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 340;
                    final rows = [
                      _ActivityTotalLine(
                        label: l10n.activityTotalsIncome,
                        amount: total.incomeMinor,
                        currency: total.currency,
                        color: AppColors.green,
                        locale: locale,
                      ),
                      _ActivityTotalLine(
                        label: l10n.activityTotalsExpenses,
                        amount: total.expenseMinor,
                        currency: total.currency,
                        color: const Color(0xFFD32F2F),
                        locale: locale,
                      ),
                      _ActivityTotalLine(
                        label: l10n.activityTotalsNet,
                        amount: total.netMinor,
                        currency: total.currency,
                        color: AppColors.navy,
                        locale: locale,
                      ),
                    ];
                    return compact
                        ? Column(children: rows)
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [for (final row in rows) Expanded(child: row)],
                          );
                  },
                ),
              ],
            const SizedBox(height: 8),
            Text(
              l10n.activityTotalsPendingNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTotalLine extends StatelessWidget {
  const _ActivityTotalLine({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.locale,
  });

  final String label;
  final int amount;
  final String currency;
  final Color color;
  final String locale;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, right: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          CurrencyFormatter.formatMinor(amount, currency, locale: locale),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ],
    ),
  );
}

class _ActivityReportLoading extends StatelessWidget {
  const _ActivityReportLoading();

  @override
  Widget build(BuildContext context) => const Card(
    child: SizedBox(height: 110, child: Center(child: CircularProgressIndicator())),
  );
}

class _ActivityReportError extends StatelessWidget {
  const _ActivityReportError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ),
        ],
      ),
    ),
  );
}

class _ActivityQueryFilterButton extends StatelessWidget {
  const _ActivityQueryFilterButton({
    required this.accountLabel,
    required this.periodLabel,
    required this.onPressed,
  });

  final String accountLabel;
  final String periodLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        key: const ValueKey('activity_open_filters'),
        onPressed: onPressed,
        icon: const Icon(Icons.tune, size: 18),
        label: Text(
          l10n.activityFilterAction(accountLabel, periodLabel),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: AppColors.navy,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

String _activityAccountLabel(
  List<FinanceAccount> accounts,
  List<String> accountIds,
  AppLocalizations l10n,
) {
  if (accountIds.isEmpty) return l10n.activityFilterAllAccounts;
  if (accountIds.length > 1) return l10n.activityFilterSelectedAccountCount(accountIds.length);
  for (final account in accounts) {
    if (account.id == accountIds.single) return account.name;
  }
  return l10n.activityFilterAllAccounts;
}

String _activityPeriodLabel(ActivityQueryFilters filters, BuildContext context) {
  final locale = Localizations.localeOf(context).toString();
  if (filters.isDateRange) {
    return '${DateFormat('d MMM', locale).format(filters.startAt!)}–'
        '${DateFormat('d MMM', locale).format(filters.endAtExclusive!.subtract(const Duration(days: 1)))}';
  }
  final key = filters.monthKey;
  if (key == null) return AppLocalizations.of(context).activityFilterAllDates;
  final parts = key.split('-');
  if (parts.length != 2) return AppLocalizations.of(context).activityFilterAllDates;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) {
    return AppLocalizations.of(context).activityFilterAllDates;
  }
  return DateFormat.yMMMM(locale).format(DateTime(year, month));
}

String _activityPeriodRangeLabel(ActivityQueryFilters filters, BuildContext context) {
  final locale = Localizations.localeOf(context).toString();
  if (filters.isDateRange) {
    return '${DateFormat.yMMMd(locale).format(filters.startAt!)} – '
        '${DateFormat.yMMMd(locale).format(filters.endAtExclusive!.subtract(const Duration(days: 1)))}';
  }
  final key = filters.monthKey;
  if (key == null) return AppLocalizations.of(context).activityFilterAllDates;
  final parts = key.split('-');
  if (parts.length != 2) return AppLocalizations.of(context).activityFilterAllDates;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) {
    return AppLocalizations.of(context).activityFilterAllDates;
  }
  final start = DateTime(year, month);
  final end = DateTime(year, month + 1, 0);
  return '${DateFormat.yMMMd(locale).format(start)} – ${DateFormat.yMMMd(locale).format(end)}';
}

class _ActivityTypeFilters extends StatelessWidget {
  const _ActivityTypeFilters({
    required this.selectedType,
    required this.adjustmentsOnly,
    required this.onSelected,
    required this.onAdjustmentsSelected,
  });

  final OperationType? selectedType;
  final bool adjustmentsOnly;
  final ValueChanged<OperationType?> onSelected;
  final ValueChanged<bool> onAdjustmentsSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = <({String label, String key, bool selected, VoidCallback onTap})>[
      (
        label: l10n.activityFilterAll,
        key: 'all',
        selected: !adjustmentsOnly && selectedType == null,
        onTap: () => onSelected(null),
      ),
      (
        label: l10n.income,
        key: 'income',
        selected: !adjustmentsOnly && selectedType == OperationType.income,
        onTap: () => onSelected(OperationType.income),
      ),
      (
        label: l10n.expense,
        key: 'expense',
        selected: !adjustmentsOnly && selectedType == OperationType.expense,
        onTap: () => onSelected(OperationType.expense),
      ),
      (
        label: l10n.activityBalanceAdjustmentsFilter,
        key: 'balance_adjustments',
        selected: adjustmentsOnly,
        onTap: () => onAdjustmentsSelected(!adjustmentsOnly),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Semantics(
              button: true,
              selected: options[index].selected,
              label: options[index].label,
              child: ChoiceChip(
                key: ValueKey('activity_filter_${options[index].key}'),
                label: Text(options[index].label),
                selected: options[index].selected,
                onSelected: (_) => options[index].onTap(),
                showCheckmark: false,
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: options[index].selected ? AppColors.blueDark : AppColors.muted,
                  fontWeight: options[index].selected ? FontWeight.w600 : FontWeight.w500,
                ),
                side: const BorderSide(color: AppColors.line),
                backgroundColor: Colors.white,
                selectedColor: AppColors.blueSoft,
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceAdjustmentCard extends StatelessWidget {
  const _BalanceAdjustmentCard({
    required this.entry,
    required this.accounts,
    required this.locale,
    required this.l10n,
    super.key,
  });
  final BalanceAdjustmentActivityEntry entry;
  final List<FinanceAccount> accounts;
  final String locale;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final adjustment = entry.adjustment;
    var name = l10n.activityCsvUnknownAccount;
    for (final account in accounts) {
      if (account.id == adjustment.accountId) name = account.name;
    }
    String format(int value) =>
        CurrencyFormatter.formatMinor(value, adjustment.currency, locale: locale);
    final date = DateFormat.yMMMd(locale).add_Hm().format(entry.adjustedAt.toLocal());
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: AppColors.blueDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  format(adjustment.deltaMinor),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.blueDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.activityBalanceAdjustmentType} · $date',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.activityBalanceAdjustmentEntry(
                format(adjustment.previousBalanceMinor),
                format(adjustment.targetBalanceMinor),
                format(adjustment.deltaMinor),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityOperationCard extends StatelessWidget {
  const _ActivityOperationCard({
    required this.operation,
    required this.accounts,
    required this.categories,
    required this.locale,
    required this.l10n,
    super.key,
  });

  final FinancialOperation operation;
  final List<FinanceAccount> accounts;
  final List<FinanceCategory> categories;
  final String locale;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isIncome = operation.type == OperationType.income;
    final isTransfer = operation.type == OperationType.transfer;
    FinanceAccount? findAccount(String? id) {
      for (final item in accounts) {
        if (item.id == id) return item;
      }
      return null;
    }

    final account = findAccount(operation.accountId);
    final sourceAccount = findAccount(operation.sourceAccountId);
    final destinationAccount = findAccount(operation.destinationAccountId);
    FinanceCategory? category;
    for (final item in categories) {
      if (item.id == operation.categoryId) category = item;
    }

    final categoryName = category?.customName ?? l10n.category;
    final typeLabel = isTransfer
        ? l10n.transferOperationLabel
        : isIncome
        ? l10n.income
        : l10n.expense;
    final accountDetail = isTransfer
        ? '${sourceAccount?.name ?? l10n.account} → ${destinationAccount?.name ?? l10n.account}'
        : '${account?.name ?? l10n.account} · $categoryName';
    final title = operation.description.trim().isEmpty ? typeLabel : operation.description;
    final amount = CurrencyFormatter.formatMinor(
      operation.amountMinor,
      operation.currency,
      locale: locale,
    );
    final signedAmount = isIncome
        ? '+ $amount'
        : isTransfer
        ? amount
        : '− $amount';
    final occurredAt = operation.occurredAt.toLocal();
    final dateTime = DateFormat.yMMMd(locale).add_Hm().format(occurredAt);
    final typeAndDate = '$typeLabel · $dateTime';
    final semanticLabel = '$title, $typeAndDate, $accountDetail, $signedAmount';

    return Semantics(
      button: !isTransfer,
      label: semanticLabel,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isTransfer
              ? null
              : () => context.push('/operations/${operation.id}/edit', extra: operation),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (isTransfer)
                    const CircleAvatar(
                      backgroundColor: AppColors.blueSoft,
                      child: Icon(Icons.swap_horiz, color: AppColors.blueDark),
                    )
                  else
                    FinanceCategoryIcon(
                      iconId: category?.icon,
                      colorValue: category?.colorValue,
                      semanticLabel: categoryName,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final amountWidth = (constraints.maxWidth * .42).clamp(100.0, 160.0);
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: amountWidth,
                                  child: Text(
                                    key: ValueKey('activity_operation_amount_${operation.id}'),
                                    signedAmount,
                                    textAlign: TextAlign.end,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: isIncome ? AppColors.green : AppColors.navy,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        Text(
                          typeAndDate,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          accountDetail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivitySyncBanner extends StatelessWidget {
  const _ActivitySyncBanner({required this.status, required this.issue, required this.onRetry});

  final SyncStatusSnapshot status;
  final SyncFailureInfo? issue;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = status.rejected > 0
        ? l10n.offlineRejected
        : status.syncing > 0
        ? l10n.syncing
        : l10n.offlinePending;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync, color: AppColors.blueDark),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: Theme.of(context).textTheme.bodySmall),
                if (issue != null) Text(syncIssueMessage(l10n, issue!)),
                if (issue?.technicalCode case final code?)
                  SelectableText(l10n.syncDiagnosticCode(code)),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}

class _ActivityMessage extends StatelessWidget {
  const _ActivityMessage({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
