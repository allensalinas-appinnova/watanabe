import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/offline/sync_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalActivityScreen extends ConsumerStatefulWidget {
  const CanonicalActivityScreen({super.key});

  @override
  ConsumerState<CanonicalActivityScreen> createState() => _CanonicalActivityScreenState();
}

class _CanonicalActivityScreenState extends ConsumerState<CanonicalActivityScreen> {
  final _scrollController = ScrollController();
  OperationType? _selectedType;

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
      ref.read(operationsPagerProvider((userId: user.id, type: _selectedType)).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));

    final pagerProvider = operationsPagerProvider((userId: user.id, type: _selectedType));
    final pager = ref.watch(pagerProvider);
    final accounts =
        ref.watch(canonicalAccountsProvider(user.id)).valueOrNull ?? const <FinanceAccount>[];
    final categories =
        ref.watch(canonicalCategoriesProvider(user.id)).valueOrNull ?? const <FinanceCategory>[];
    final syncStatus = ref.watch(pendingOperationSyncStatusProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(pagerProvider.notifier).refresh(),
          child: CustomScrollView(
            key: const ValueKey('canonical_activity_scroll_view'),
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ClearBudget',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.blueDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
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
                        selectedType: _selectedType,
                        onSelected: (type) {
                          if (_selectedType == type) return;
                          for (final filter in const <OperationType?>[
                            null,
                            OperationType.income,
                            OperationType.expense,
                          ]) {
                            ref.invalidate(
                              operationsPagerProvider((userId: user.id, type: filter)),
                            );
                          }
                          setState(() => _selectedType = type);
                          if (_scrollController.hasClients) _scrollController.jumpTo(0);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
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
                      onRetry: () => ref.read(canonicalActionsProvider).syncPending(user.id),
                    ),
                  ),
                ),
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
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
    );
  }
}

class _ActivityTypeFilters extends StatelessWidget {
  const _ActivityTypeFilters({required this.selectedType, required this.onSelected});

  final OperationType? selectedType;
  final ValueChanged<OperationType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = <({String label, String key, OperationType? type})>[
      (label: l10n.activityFilterAll, key: 'all', type: null),
      (label: l10n.income, key: 'income', type: OperationType.income),
      (label: l10n.expense, key: 'expense', type: OperationType.expense),
    ];

    return Row(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: Center(
                child: Material(
                  color: options[index].type == selectedType ? AppColors.blueSoft : Colors.white,
                  shape: const StadiumBorder(side: BorderSide(color: AppColors.line)),
                  child: Semantics(
                    button: true,
                    selected: options[index].type == selectedType,
                    label: options[index].label,
                    child: InkWell(
                      key: ValueKey('activity_filter_${options[index].key}'),
                      customBorder: const StadiumBorder(),
                      onTap: () => onSelected(options[index].type),
                      child: SizedBox(
                        height: 36,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              options[index].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: options[index].type == selectedType
                                    ? AppColors.blueDark
                                    : AppColors.muted,
                                fontWeight: options[index].type == selectedType
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
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
    FinanceAccount? account;
    for (final item in accounts) {
      if (item.id == operation.accountId) account = item;
    }
    FinanceCategory? category;
    for (final item in categories) {
      if (item.id == operation.categoryId) category = item;
    }

    final detail = isTransfer
        ? l10n.transferOperationLabel
        : isIncome
        ? '${l10n.income} · ${account?.name ?? l10n.account}'
        : '${l10n.expense} · ${category?.customName ?? l10n.category}';
    final title = operation.description.trim().isEmpty ? detail : operation.description;
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
    final date = MaterialLocalizations.of(context).formatMediumDate(operation.occurredAt.toLocal());
    final semanticLabel = '$title, $detail, $signedAmount, $date';

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
            constraints: const BoxConstraints(minHeight: 70),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivitySyncBanner extends StatelessWidget {
  const _ActivitySyncBanner({required this.status, required this.onRetry});

  final SyncStatusSnapshot status;
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
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
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
