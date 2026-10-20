import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/firebase/firebase_observability.dart';
import '../../../../core/offline/pending_operation_queue.dart';
import '../../../../core/offline/pending_operation_sync_service.dart';
import '../../../../core/offline/sync_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/budget.dart';
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

final activityTypeFilterProvider = NotifierProvider<ActivityTypeFilterNotifier, OperationType?>(
  ActivityTypeFilterNotifier.new,
);

final activityQueryFiltersProvider =
    NotifierProvider<ActivityQueryFiltersNotifier, ActivityQueryFilters>(
      ActivityQueryFiltersNotifier.new,
    );

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

final canonicalMonthlySummaryProvider =
    StreamProvider.family<MonthlySummary?, ({String userId, String monthKey, String currency})>(
      (ref, input) => getIt<CanonicalFinanceRepository>().watchMonthlySummary(
        input.userId,
        input.monthKey,
        input.currency,
      ),
    );

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
  const CanonicalFinanceActions(
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
    await _sync.enqueue(
      idempotencyKey: draft.idempotencyKey,
      operationType: 'operation',
      payload: _operationPayload(draft),
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
  }

  Future<SyncState> createTransfer(String userId, TransferDraft draft) async {
    await _sync.enqueue(
      idempotencyKey: draft.idempotencyKey,
      operationType: 'transfer',
      payload: _transferPayload(draft),
    );
    await _sync.drain((type, payload) => _send(userId, type, payload));
    final status = (await _database.findByIdempotencyKey(draft.idempotencyKey))?.status;
    if (status == SyncState.confirmed.name) await _observability.logEvent('transfer_created');
    return SyncState.values.firstWhere(
      (value) => value.name == status,
      orElse: () => SyncState.pending,
    );
  }

  Future<void> createBudget(
    String userId, {
    required String categoryId,
    required String flowType,
    required String monthKey,
    required String currency,
    required List<CanonicalBudgetItemDraft> items,
  }) async {
    final result = await _repository.createBudgetWithItems(
      userId,
      categoryId: categoryId,
      flowType: flowType,
      monthKey: monthKey,
      currency: currency,
      items: items,
    );
    result.match((failure) => throw Exception(failure.message), (_) {
      unawaited(_observability.logEvent('budget_created'));
    });
  }

  Future<void> addBudgetItem(
    String userId,
    String budgetId,
    CanonicalBudgetItemDraft item,
  ) async {
    final result = await _repository.addBudgetItem(userId, budgetId, item);
    result.match((failure) => throw Exception(failure.message), (_) {});
  }

  Future<void> updateBudgetItem(String userId, String budgetId, BudgetItem item) async {
    final result = await _repository.updateBudgetItem(userId, budgetId, item);
    result.match((failure) => throw Exception(failure.message), (_) {});
  }

  Future<void> deleteBudgetItem(String userId, String budgetId, String itemId) async {
    final result = await _repository.deleteBudgetItem(userId, budgetId, itemId);
    result.match((failure) {
      if (failure is ConflictFailure && failure.message == 'budget-last-item') {
        throw StateError('budget-last-item');
      }
      throw Exception(failure.message);
    }, (_) {});
  }

  Future<void> archiveBudget(String userId, String budgetId) async {
    final result = await _repository.archiveBudget(userId, budgetId);
    result.match((failure) => throw Exception(failure.message), (_) {});
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
      ),
    );
    return result.match(_syncFailureResult, (_) => const SyncAttemptResult.success());
  }

  SyncAttemptResult _syncFailureResult(Failure failure) => switch (failure) {
    NetworkFailure() => const SyncAttemptResult.retryable(SyncIssueCode.networkUnavailable),
    AuthFailure() => const SyncAttemptResult.rejected(SyncIssueCode.permissionDenied),
    ConflictFailure() => const SyncAttemptResult.rejected(SyncIssueCode.invalidOperation),
    UnknownFailure() => const SyncAttemptResult.rejected(SyncIssueCode.invalidOperation),
  };

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
