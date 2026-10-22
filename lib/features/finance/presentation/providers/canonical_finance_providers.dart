import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/firebase/firebase_observability.dart';
import '../../../../core/offline/pending_operation_queue.dart';
import '../../../../core/offline/pending_operation_sync_service.dart';
import '../../../../core/offline/sync_state.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/request_id.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/activity_report.dart';
import '../../domain/entities/balance_adjustment.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_command_failure.dart';
import '../../domain/entities/budget_item.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/entities/operation_page.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/canonical_finance_repository.dart';

final canonicalFinanceRepositoryProvider = Provider<CanonicalFinanceRepository>(
  (ref) => getIt<CanonicalFinanceRepository>(),
);

final firebaseObservabilityProvider = Provider<FirebaseObservability?>(
  (ref) => getIt.isRegistered<FirebaseObservability>() ? getIt<FirebaseObservability>() : null,
);

final dashboardAmountsHiddenProvider = NotifierProvider<DashboardAmountsHiddenNotifier, bool>(
  DashboardAmountsHiddenNotifier.new,
);

class DashboardAmountsHiddenNotifier extends Notifier<bool> {
  static const _preferenceKey = 'dashboard_amounts_hidden';

  @override
  bool build() => getIt.isRegistered<SharedPreferences>()
      ? getIt<SharedPreferences>().getBool(_preferenceKey) ?? false
      : false;

  Future<void> setHidden(bool hidden) async {
    if (getIt.isRegistered<SharedPreferences>()) {
      await getIt<SharedPreferences>().setBool(_preferenceKey, hidden);
    }
    state = hidden;
  }
}

final canonicalUserProfileProvider = StreamProvider.family<UserProfile?, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchUserProfile(userId),
);

final canonicalCategoriesProvider = StreamProvider.family<List<FinanceCategory>, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchCategories(userId),
);

final canonicalAccountsProvider = StreamProvider.family<List<FinanceAccount>, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchAccounts(userId),
);

final balanceAdjustmentsProvider = StreamProvider.family<List<BalanceAdjustmentEvent>, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchBalanceAdjustments(userId),
);

final canonicalOperationsPageProvider =
    FutureProvider.family<
      OperationPage,
      ({
        String userId,
        OperationPageCursor? cursor,
        String? monthKey,
        String? currency,
        OperationType? type,
        List<String>? accountIds,
        int pageSize,
      })
    >((ref, input) async {
      final result = await ref
          .read(canonicalFinanceRepositoryProvider)
          .fetchOperationsPage(
            input.userId,
            cursor: input.cursor,
            monthKey: input.monthKey,
            currency: input.currency,
            type: input.type,
            accountIds: input.accountIds,
            pageSize: input.pageSize,
          );
      return result.match((failure) => throw Exception(failure.message), (page) => page);
    });

final operationsPagerProvider =
    AsyncNotifierProvider.family<
      OperationsPagerNotifier,
      OperationPagerState,
      ({String userId, OperationType? type})
    >(
      OperationsPagerNotifier.new,
    );

/// Refreshes the two read models that display recent and paginated activity.
void invalidateOperationLists(WidgetRef ref, String userId) {
  ref.invalidate(
    canonicalOperationsPageProvider((
      userId: userId,
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
    ref.invalidate(operationsPagerProvider((userId: userId, type: type)));
  }
}

final activityTypeFilterProvider = NotifierProvider<ActivityTypeFilterNotifier, OperationType?>(
  ActivityTypeFilterNotifier.new,
);

final activityBalanceAdjustmentsOnlyProvider =
    NotifierProvider<BalanceAdjustmentsOnlyNotifier, bool>(
      BalanceAdjustmentsOnlyNotifier.new,
    );

class BalanceAdjustmentsOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void select(bool value) => state = value;
}

final activityQueryFiltersProvider =
    NotifierProvider<ActivityQueryFiltersNotifier, ActivityQueryFilters>(
      ActivityQueryFiltersNotifier.new,
    );

/// Loads every non-rejected activity record matching the current filters so
/// summaries and exports are not limited to the list's currently loaded page.
final activityReportProvider = FutureProvider.family<ActivityReport, String>((ref, userId) async {
  final observability = ref.watch(firebaseObservabilityProvider);
  Future<ActivityReport> load() async {
    final filters = ref.watch(activityQueryFiltersProvider);
    final type = ref.watch(activityTypeFilterProvider);
    final adjustmentsOnly = ref.watch(activityBalanceAdjustmentsOnlyProvider);
    final adjustmentEventsState = ref.watch(balanceAdjustmentsProvider(userId));
    final localPending = ref.watch(pendingOperationsProvider).valueOrNull ?? const [];
    final repository = ref.watch(canonicalFinanceRepositoryProvider);
    final adjustmentEvents = adjustmentEventsState.valueOrNull ?? const <BalanceAdjustmentEvent>[];
    final operations = <FinancialOperation>[];
    OperationPageCursor? cursor;

    while (true) {
      final result = await repository.fetchOperationsPage(
        userId,
        cursor: cursor,
        monthKey: filters.monthKey,
        type: type,
        accountIds: filters.accountIds,
        startAt: filters.startAt,
        endAtExclusive: filters.endAtExclusive,
      );
      final page = result.match((failure) => throw Exception(failure.message), (value) => value);
      operations.addAll(page.items);
      cursor = page.nextCursor;
      if (cursor == null) break;
    }

    final knownIdempotencyKeys = operations.map((operation) => operation.idempotencyKey).toSet();
    for (final pending in localPending) {
      if (pending.status == 'rejected') continue;
      try {
        final payload = jsonDecode(pending.payload) as Map<String, dynamic>;
        // New queue entries carry ownership so another signed-in user's local
        // transactions are never exposed in this report or its export.
        if (payload['ownerUserId'] != userId) continue;
        final operation = _pendingActivityOperation(pending, payload);
        if (operation == null || knownIdempotencyKeys.contains(operation.idempotencyKey)) {
          continue;
        }
        if (type != null && operation.type != type) continue;
        if (filters.monthKey != null && operation.monthKey != filters.monthKey) continue;
        if (filters.isDateRange &&
            (operation.occurredAt.isBefore(filters.startAt!) ||
                !operation.occurredAt.isBefore(filters.endAtExclusive!))) {
          continue;
        }
        if (filters.accountIds.isNotEmpty &&
            !filters.accountIds.any(
              (id) =>
                  id == operation.accountId ||
                  id == operation.sourceAccountId ||
                  id == operation.destinationAccountId,
            )) {
          continue;
        }
        operations.add(operation);
        knownIdempotencyKeys.add(operation.idempotencyKey);
      } on Object {
        // A malformed or legacy queue row is left untouched and omitted safely.
      }
    }

    final adjustments = <BalanceAdjustmentActivityEntry>[];
    if (type == null) {
      for (final event in adjustmentEvents) {
        final localDate = event.adjustedAt.toLocal();
        final monthKey =
            '${localDate.year.toString().padLeft(4, '0')}-${localDate.month.toString().padLeft(2, '0')}';
        if (filters.monthKey != null && monthKey != filters.monthKey) continue;
        if (filters.isDateRange &&
            (event.adjustedAt.isBefore(filters.startAt!) ||
                !event.adjustedAt.isBefore(filters.endAtExclusive!))) {
          continue;
        }
        for (final adjustment in event.adjustments) {
          if (filters.accountIds.isNotEmpty && !filters.accountIds.contains(adjustment.accountId)) {
            continue;
          }
          adjustments.add(
            BalanceAdjustmentActivityEntry(
              requestId: event.requestId,
              adjustedAt: event.adjustedAt,
              adjustment: adjustment,
            ),
          );
        }
      }
    }
    return ActivityReport.fromOperations(
      adjustmentsOnly ? const [] : operations,
      adjustments: adjustments,
    );
  }

  if (observability == null) return load();
  return observability.tracePerformance(PerformanceTraceName.activityReportPreparation, load);
});

FinancialOperation? _pendingActivityOperation(
  PendingOperation pending,
  Map<String, dynamic> payload,
) {
  final isTransfer = pending.operationType == 'transfer';
  final type = isTransfer
      ? OperationType.transfer
      : OperationType.values.byName(payload['type'] as String);
  final occurredAt = DateTime.tryParse(payload['occurredAt'] as String? ?? '');
  final amountMinor = payload['amountMinor'];
  if (occurredAt == null || amountMinor is! int) return null;
  final monthKey =
      payload['monthKey'] as String? ??
      '${occurredAt.year.toString().padLeft(4, '0')}-${occurredAt.month.toString().padLeft(2, '0')}';
  return FinancialOperation(
    id: 'local-${pending.idempotencyKey}',
    type: type,
    amountMinor: amountMinor,
    currency: payload['currency'] as String? ?? '',
    monthKey: monthKey,
    occurredAt: occurredAt,
    status: OperationStatus.pending,
    idempotencyKey: pending.idempotencyKey,
    description: payload['description'] as String? ?? '',
    accountId: payload['accountId'] as String?,
    categoryId: payload['categoryId'] as String?,
    sourceAccountId: payload['sourceAccountId'] as String?,
    destinationAccountId: payload['destinationAccountId'] as String?,
  );
}

class ActivityQueryFilters {
  const ActivityQueryFilters({
    this.accountIds = const [],
    this.monthKey,
    this.startAt,
    this.endAtExclusive,
    this.hasBeenApplied = false,
  });

  final List<String> accountIds;
  final String? monthKey;
  final DateTime? startAt;
  final DateTime? endAtExclusive;
  final bool hasBeenApplied;

  bool get isDateRange => startAt != null && endAtExclusive != null;
}

class ActivityQueryFiltersNotifier extends Notifier<ActivityQueryFilters> {
  @override
  ActivityQueryFilters build() => ActivityQueryFilters(monthKey: _monthKey(DateTime.now()));

  void apply(ActivityQueryFilters filters) => state = filters;

  void reset() => state = ActivityQueryFilters(
    monthKey: _monthKey(DateTime.now()),
    hasBeenApplied: true,
  );

  static String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
}

class ActivityTypeFilterNotifier extends Notifier<OperationType?> {
  @override
  OperationType? build() => null;

  void select(OperationType? type) => state = type;
}

class OperationsPagerNotifier extends AsyncNotifier<OperationPagerState> {
  OperationsPagerNotifier(this.filter);

  final ({String userId, OperationType? type}) filter;
  int _requestGeneration = 0;

  @override
  Future<OperationPagerState> build() {
    ref.watch(activityQueryFiltersProvider);
    return _loadInitial(type: filter.type);
  }

  Future<void> refresh() async {
    final generation = ++_requestGeneration;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _loadInitial(type: filter.type));
    if (generation == _requestGeneration) state = result;
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    final generation = _requestGeneration;
    state = AsyncData(current.copyWith(isLoadingMore: true, errorMessage: null));
    final result = await ref
        .read(canonicalFinanceRepositoryProvider)
        .fetchOperationsPage(
          filter.userId,
          cursor: current.nextCursor,
          monthKey: current.monthKey,
          currency: current.currency,
          type: current.type,
          accountIds: current.accountIds,
          startAt: current.startAt,
          endAtExclusive: current.endAtExclusive,
        );
    if (generation != _requestGeneration) return;
    result.match(
      (failure) => state = AsyncData(
        current.copyWith(isLoadingMore: false, errorMessage: failure.message),
      ),
      (page) {
        final knownIds = current.items.map((item) => item.id).toSet();
        final additions = <FinancialOperation>[];
        for (final item in page.items) {
          if (knownIds.add(item.id)) additions.add(item);
        }
        state = AsyncData(
          current.copyWith(
            items: [...current.items, ...additions],
            nextCursor: page.nextCursor,
            isLoadingMore: false,
            errorMessage: null,
          ),
        );
      },
    );
  }

  Future<OperationPagerState> _loadInitial({required OperationType? type}) async {
    final filters = ref.read(activityQueryFiltersProvider);
    final result = await ref
        .read(canonicalFinanceRepositoryProvider)
        .fetchOperationsPage(
          filter.userId,
          type: type,
          accountIds: filters.accountIds,
          monthKey: filters.monthKey,
          startAt: filters.startAt,
          endAtExclusive: filters.endAtExclusive,
        );
    return result.match(
      (failure) => throw Exception(failure.message),
      (page) => OperationPagerState(
        items: page.items,
        nextCursor: page.nextCursor,
        type: type,
        accountIds: filters.accountIds,
        monthKey: filters.monthKey,
        startAt: filters.startAt,
        endAtExclusive: filters.endAtExclusive,
      ),
    );
  }
}

class OperationPagerState {
  const OperationPagerState({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
    this.errorMessage,
    this.monthKey,
    this.currency,
    this.type,
    this.accountIds = const [],
    this.startAt,
    this.endAtExclusive,
  });

  final List<FinancialOperation> items;
  final OperationPageCursor? nextCursor;
  final bool isLoadingMore;
  final String? errorMessage;
  final String? monthKey;
  final String? currency;
  final OperationType? type;
  final List<String> accountIds;
  final DateTime? startAt;
  final DateTime? endAtExclusive;

  bool get hasMore => nextCursor != null;

  OperationPagerState copyWith({
    List<FinancialOperation>? items,
    OperationPageCursor? nextCursor,
    bool clearCursor = false,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    String? monthKey,
    String? currency,
    OperationType? type,
    bool clearType = false,
    List<String>? accountIds,
    DateTime? startAt,
    DateTime? endAtExclusive,
  }) => OperationPagerState(
    items: items ?? this.items,
    nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    monthKey: monthKey ?? this.monthKey,
    currency: currency ?? this.currency,
    type: clearType ? null : type ?? this.type,
    accountIds: accountIds ?? this.accountIds,
    startAt: startAt ?? this.startAt,
    endAtExclusive: endAtExclusive ?? this.endAtExclusive,
  );
}

final canonicalBudgetsProvider =
    StreamProvider.family<List<Budget>, ({String userId, String monthKey})>(
      (ref, input) =>
          getIt<CanonicalFinanceRepository>().watchBudgets(input.userId, input.monthKey),
    );

final canonicalBudgetProvider = StreamProvider.family<Budget?, ({String userId, String budgetId})>(
  (ref, input) => getIt<CanonicalFinanceRepository>().watchBudget(input.userId, input.budgetId),
);

final canonicalBudgetItemOperationsProvider =
    StreamProvider.family<
      List<FinancialOperation>,
      ({String userId, String budgetId, String itemId})
    >(
      (ref, input) => ref
          .watch(canonicalFinanceRepositoryProvider)
          .watchBudgetItemOperations(
            input.userId,
            input.budgetId,
            input.itemId,
          ),
    );

final canonicalMonthlySummaryProvider =
    StreamProvider.family<MonthlySummary?, ({String userId, String monthKey, String currency})>(
      (ref, input) => getIt<CanonicalFinanceRepository>().watchMonthlySummary(
        input.userId,
        input.monthKey,
        input.currency,
      ),
    );

final homeInitialLoadProvider =
    FutureProvider.family<void, ({String userId, String monthKey, String currency})>((
      ref,
      input,
    ) async {
      final observability = ref.watch(firebaseObservabilityProvider);
      Future<void> load() async {
        await Future.wait<Object?>([
          ref.watch(canonicalAccountsProvider(input.userId).future),
          ref.watch(canonicalCategoriesProvider(input.userId).future),
          ref.watch(
            canonicalOperationsPageProvider((
              userId: input.userId,
              cursor: null,
              monthKey: null,
              currency: null,
              type: null,
              accountIds: null,
              pageSize: 10,
            )).future,
          ),
          ref.watch(
            canonicalMonthlySummaryProvider((
              userId: input.userId,
              monthKey: input.monthKey,
              currency: input.currency,
            )).future,
          ),
          ref.watch(
            canonicalBudgetsProvider((userId: input.userId, monthKey: input.monthKey)).future,
          ),
        ]);
      }

      if (observability == null) {
        await load();
      } else {
        await observability.tracePerformance(PerformanceTraceName.homeInitialLoad, load);
      }
    });

final bootstrapCategoriesProvider = Provider<BootstrapCategories>(
  (ref) => BootstrapCategories(
    getIt<CanonicalFinanceRepository>(),
    getIt<FirebaseObservability>(),
  ),
);

final pendingOperationsProvider = StreamProvider<List<PendingOperation>>((ref) {
  return getIt<PendingOperationDatabase>().watchActive();
});

final pendingOperationSyncStatusProvider = StreamProvider<SyncStatusSnapshot>((ref) {
  return getIt<PendingOperationSyncService>().watchStatus();
});

final pendingOperationAutoSyncProvider = Provider.autoDispose<void>((ref) {
  final user = ref.watch(authSessionProvider).value;
  if (user == null) return;
  final actions = ref.read(canonicalActionsProvider);
  final subscription = actions.startAutoSync(user.id);
  ref.onDispose(subscription.cancel);
  unawaited(actions.syncPending(user.id));
});

class BootstrapCategories {
  const BootstrapCategories(this._repository, this._observability);

  final CanonicalFinanceRepository _repository;
  final FirebaseObservability _observability;

  Future<void> call(
    String userId, {
    required String locale,
    required String countryCode,
    String timeZone = 'UTC',
    String defaultCurrency = 'COP',
  }) async {
    final result = await _repository.ensureDefaultCategories(
      userId,
      locale: locale,
      countryCode: countryCode,
      timeZone: timeZone,
      defaultCurrency: defaultCurrency,
    );
    result.match((failure) => throw Exception(failure.message), (_) {
      unawaited(_observability.logEvent('onboarding_completed'));
    });
  }
}

final canonicalActionsProvider = Provider<CanonicalFinanceActions>(
  (ref) => CanonicalFinanceActions(
    getIt<CanonicalFinanceRepository>(),
    getIt<PendingOperationSyncService>(),
    getIt<PendingOperationDatabase>(),
    getIt<FirebaseObservability>(),
  ),
);

class CanonicalFinanceActions {
  CanonicalFinanceActions(
    this._repository,
    this._sync,
    this._database,
    this._observability,
  );

  final CanonicalFinanceRepository _repository;
  final PendingOperationSyncService _sync;
  final PendingOperationDatabase _database;
  final FirebaseObservability _observability;

  Future<void> createAccount(
    String userId, {
    required String name,
    required String type,
    required String currency,
    required int openingBalanceMinor,
  }) async {
    final result = await _repository.createAccount(
      userId,
      name: name,
      type: type,
      currency: currency,
      openingBalanceMinor: openingBalanceMinor,
    );
    result.match((failure) => throw Exception(failure.message), (_) {
      unawaited(_observability.logEvent('account_created'));
    });
  }

  Future<void> updateAccount(String userId, FinanceAccount account, {required String name}) async {
    final result = await _repository.updateAccount(
      userId,
      FinanceAccount(
        id: account.id,
        name: name,
        type: account.type,
        currency: account.currency,
        openingBalanceMinor: account.openingBalanceMinor,
        currentBalanceMinor: account.currentBalanceMinor,
        includeInDashboard: account.includeInDashboard,
        status: account.status,
        createdAt: account.createdAt,
        updatedAt: account.updatedAt,
        archivedAt: account.archivedAt,
      ),
    );
    result.match((failure) => throw Exception(failure.message), (_) {});
  }

  Future<SyncState> createOperation(
    String userId,
    FinancialOperationDraft draft,
  ) async {
    return _observability.tracePerformance(PerformanceTraceName.operationSave, () async {
      await _sync.enqueue(
        idempotencyKey: draft.idempotencyKey,
        operationType: 'operation',
        payload: {..._operationPayload(draft), 'ownerUserId': userId},
      );
      await _sync.drain((type, payload) => _send(userId, type, payload));
      final status = (await _database.findByIdempotencyKey(draft.idempotencyKey))?.status;
      if (status == SyncState.confirmed.name) {
        await _observability.logEvent('${draft.type.name}_created');
      }
      return SyncState.values.firstWhere(
        (value) => value.name == status,
        orElse: () => SyncState.pending,
      );
    });
  }

  Future<SyncState> createTransfer(String userId, TransferDraft draft) async {
    return _observability.tracePerformance(PerformanceTraceName.operationSave, () async {
      await _sync.enqueue(
        idempotencyKey: draft.idempotencyKey,
        operationType: 'transfer',
        payload: {..._transferPayload(draft), 'ownerUserId': userId},
      );
      await _sync.drain((type, payload) => _send(userId, type, payload));
      final status = (await _database.findByIdempotencyKey(draft.idempotencyKey))?.status;
      if (status == SyncState.confirmed.name) await _observability.logEvent('transfer_created');
      return SyncState.values.firstWhere(
        (value) => value.name == status,
        orElse: () => SyncState.pending,
      );
    });
  }

  final Map<String, String> _budgetRequestIds = {};

  List<Object> _budgetItemKey(CanonicalBudgetItemDraft item) => [
    item.description.trim(),
    item.amountMinor,
    item.dayOfMonth,
  ];

  Future<T> _runBudget<T>(String key, Future<Either<Failure, T>> Function(String) send) async {
    return _observability.tracePerformance(PerformanceTraceName.budgetSave, () async {
      final requestId = _budgetRequestIds.putIfAbsent(key, newRequestId);
      final result = await send(requestId);
      return result.match(
        (failure) => throw BudgetCommandException.fromFailure(failure),
        (value) {
          _budgetRequestIds.remove(key);
          return value;
        },
      );
    });
  }

  Future<Budget> createBudget(
    String userId, {
    required String categoryId,
    required String flowType,
    required String monthKey,
    required String currency,
    required List<CanonicalBudgetItemDraft> items,
  }) async {
    final key = jsonEncode([
      userId,
      'create',
      categoryId,
      flowType,
      monthKey,
      currency,
      items.map(_budgetItemKey).toList(),
    ]);
    final budget = await _runBudget(
      key,
      (requestId) => _repository.createBudgetWithItems(
        userId,
        categoryId: categoryId,
        flowType: flowType,
        monthKey: monthKey,
        currency: currency,
        items: items,
        requestId: requestId,
      ),
    );
    unawaited(_observability.logEvent('budget_created'));
    return budget;
  }

  Future<void> addBudgetItem(String userId, String budgetId, CanonicalBudgetItemDraft item) async {
    final key = jsonEncode([userId, 'addItem', budgetId, _budgetItemKey(item)]);
    await _runBudget(
      key,
      (requestId) => _repository.addBudgetItem(userId, budgetId, item, requestId: requestId),
    );
  }

  Future<void> updateBudgetItem(String userId, String budgetId, BudgetItem item) async {
    final key = jsonEncode([
      userId,
      'updateItem',
      budgetId,
      item.id,
      item.description.trim(),
      item.amountMinor,
      item.dayOfMonth,
    ]);
    await _runBudget(
      key,
      (requestId) => _repository.updateBudgetItem(userId, budgetId, item, requestId: requestId),
    );
  }

  Future<void> deleteBudgetItem(String userId, String budgetId, String itemId) async {
    final key = jsonEncode([userId, 'archiveItem', budgetId, itemId]);
    await _runBudget(
      key,
      (requestId) => _repository.deleteBudgetItem(userId, budgetId, itemId, requestId: requestId),
    );
  }

  Future<Failure?> archiveBudget(String userId, String budgetId) async {
    return _observability.tracePerformance(PerformanceTraceName.budgetSave, () async {
      final key = jsonEncode([userId, 'archiveBudget', budgetId]);
      final requestId = _budgetRequestIds.putIfAbsent(key, newRequestId);
      final result = await _repository.archiveBudget(userId, budgetId, requestId: requestId);
      return result.match(
        (failure) {
          if (kDebugMode) {
            debugPrint('budget_archive_failure code=${failure.technicalCode ?? 'unexpected'}');
          }
          unawaited(_observability.recordNonFatal(TechnicalErrorCode.firebaseRequest));
          return failure;
        },
        (_) {
          _budgetRequestIds.remove(key);
          return null;
        },
      );
    });
  }

  Future<void> updateOperation(String userId, FinancialOperation operation) async {
    final result = await _repository.updateOperation(userId, operation);
    result.match((failure) => throw Exception(failure.message), (_) {});
  }

  Future<void> deleteOperation(String userId, String operationId) async {
    final result = await _repository.deleteOperation(userId, operationId);
    result.match((failure) => throw Exception(failure.message), (_) {});
  }

  Future<void> syncPending(String userId, {bool retryRejected = true}) {
    return _sync.drain(
      (type, payload) => _send(userId, type, payload),
      retryRejected: retryRejected,
    );
  }

  StreamSubscription<dynamic> startAutoSync(String userId) =>
      _sync.listenForReconnect((type, payload) => _send(userId, type, payload));

  Future<SyncAttemptResult> _send(String userId, String type, Map<String, dynamic> payload) async {
    if (type == 'transfer') {
      final result = await _repository.createTransfer(
        userId,
        TransferDraft(
          amountMinor: payload['amountMinor'] as int,
          currency: payload['currency'] as String,
          sourceAccountId: payload['sourceAccountId'] as String,
          destinationAccountId: payload['destinationAccountId'] as String,
          occurredAt: DateTime.parse(payload['occurredAt'] as String),
          description: payload['description'] as String,
          idempotencyKey: payload['idempotencyKey'] as String,
          monthKey: payload['monthKey'] as String?,
        ),
      );
      return result.match(_syncFailureResult, (_) => const SyncAttemptResult.success());
    }
    final result = await _repository.createOperation(
      userId,
      FinancialOperationDraft(
        type: OperationType.values.byName(payload['type'] as String),
        amountMinor: payload['amountMinor'] as int,
        currency: payload['currency'] as String,
        accountId: payload['accountId'] as String,
        categoryId: payload['categoryId'] as String?,
        occurredAt: DateTime.parse(payload['occurredAt'] as String),
        monthKey: payload['monthKey'] as String?,
        description: payload['description'] as String,
        idempotencyKey: payload['idempotencyKey'] as String,
        budgetId: payload['budgetId'] as String?,
        budgetItemId: payload['budgetItemId'] as String?,
      ),
    );
    return result.match(_syncFailureResult, (_) => const SyncAttemptResult.success());
  }

  SyncAttemptResult _syncFailureResult(Failure failure) {
    final result = switch (failure) {
      NetworkFailure() => SyncAttemptResult.retryable(
        SyncIssueCode.networkUnavailable,
        technicalCode: failure.technicalCode,
      ),
      AuthFailure() => SyncAttemptResult.rejected(
        SyncIssueCode.permissionDenied,
        technicalCode: failure.technicalCode,
      ),
      ConflictFailure() => SyncAttemptResult.rejected(
        SyncIssueCode.invalidOperation,
        technicalCode: failure.technicalCode,
      ),
      UnknownFailure() => SyncAttemptResult.rejected(
        SyncIssueCode.invalidOperation,
        technicalCode: failure.technicalCode,
      ),
    };

    if (kDebugMode) {
      debugPrint(
        'operation_sync_failure issue=${result.issueCode?.name} '
        'firebaseCode=${result.technicalCode ?? 'none'}',
      );
    }
    if (!result.retryable) {
      unawaited(_recordRejectedSync());
    }
    return result;
  }

  Future<void> _recordRejectedSync() async {
    try {
      await _observability.logEvent('sync_rejected');
    } catch (_) {
      // Diagnostics must never replace or hide the user's sync failure.
    }
    await _observability.recordNonFatal(TechnicalErrorCode.sync);
  }

  Map<String, dynamic> _operationPayload(FinancialOperationDraft draft) => {
    'type': draft.type.name,
    'amountMinor': draft.amountMinor,
    'currency': draft.currency,
    'accountId': draft.accountId,
    'categoryId': draft.categoryId,
    'occurredAt': draft.occurredAt.toIso8601String(),
    'monthKey': draft.monthKey,
    'description': draft.description,
    'idempotencyKey': draft.idempotencyKey,
    'budgetId': draft.budgetId,
    'budgetItemId': draft.budgetItemId,
  };

  Map<String, dynamic> _transferPayload(TransferDraft draft) => {
    'amountMinor': draft.amountMinor,
    'currency': draft.currency,
    'sourceAccountId': draft.sourceAccountId,
    'destinationAccountId': draft.destinationAccountId,
    'occurredAt': draft.occurredAt.toIso8601String(),
    'monthKey': draft.monthKey,
    'description': draft.description,
    'idempotencyKey': draft.idempotencyKey,
  };
}
