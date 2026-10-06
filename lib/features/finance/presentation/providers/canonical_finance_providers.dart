import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/offline/pending_operation_queue.dart';
import '../../../../core/offline/pending_operation_sync_service.dart';
import '../../../../core/offline/sync_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/entities/operation_page.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/canonical_finance_repository.dart';

final canonicalUserProfileProvider = StreamProvider.family<UserProfile?, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchUserProfile(userId),
);

final canonicalCategoriesProvider = StreamProvider.family<List<FinanceCategory>, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchCategories(userId),
);

final canonicalAccountsProvider = StreamProvider.family<List<FinanceAccount>, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchAccounts(userId),
);

final canonicalOperationsProvider = StreamProvider.family<List<FinancialOperation>, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchOperations(userId),
);

final canonicalOperationsPageProvider =
    FutureProvider.family<
      OperationPage,
      ({
        String userId,
        OperationPageCursor? cursor,
      })
    >((ref, input) async {
      final result = await getIt<CanonicalFinanceRepository>().fetchOperationsPage(
        input.userId,
        cursor: input.cursor,
      );
      return result.match((failure) => throw Exception(failure.message), (page) => page);
    });

final canonicalBudgetsProvider =
    StreamProvider.family<List<Budget>, ({String userId, String monthKey})>(
      (ref, input) =>
          getIt<CanonicalFinanceRepository>().watchBudgets(input.userId, input.monthKey),
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
  (ref) => BootstrapCategories(getIt<CanonicalFinanceRepository>()),
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
});

class BootstrapCategories {
  const BootstrapCategories(this._repository);

  final CanonicalFinanceRepository _repository;

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
    result.match((failure) => throw Exception(failure.message), (_) {});
  }
}

final canonicalActionsProvider = Provider<CanonicalFinanceActions>(
  (ref) => CanonicalFinanceActions(
    getIt<CanonicalFinanceRepository>(),
    getIt<PendingOperationSyncService>(),
    getIt<PendingOperationDatabase>(),
  ),
);

class CanonicalFinanceActions {
  const CanonicalFinanceActions(this._repository, this._sync, this._database);

  final CanonicalFinanceRepository _repository;
  final PendingOperationSyncService _sync;
  final PendingOperationDatabase _database;

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
    result.match((failure) => throw Exception(failure.message), (_) {});
  }

  Future<bool> createOperation(
    String userId,
    FinancialOperationDraft draft,
  ) async {
    await _sync.enqueue(
      idempotencyKey: draft.idempotencyKey,
      operationType: 'operation',
      payload: _operationPayload(draft),
    );
    await _sync.drain((type, payload) => _send(userId, type, payload));
    return (await _database.findByIdempotencyKey(draft.idempotencyKey))?.status == 'confirmed';
  }

  Future<bool> createTransfer(String userId, TransferDraft draft) async {
    await _sync.enqueue(
      idempotencyKey: draft.idempotencyKey,
      operationType: 'transfer',
      payload: _transferPayload(draft),
    );
    await _sync.drain((type, payload) => _send(userId, type, payload));
    return (await _database.findByIdempotencyKey(draft.idempotencyKey))?.status == 'confirmed';
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
    result.match((failure) => throw Exception(failure.message), (_) {});
  }

  Future<void> addBudgetItem(
    String userId,
    String budgetId,
    CanonicalBudgetItemDraft item,
  ) async {
    final result = await _repository.addBudgetItem(userId, budgetId, item);
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

  Future<void> _send(String userId, String type, Map<String, dynamic> payload) async {
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
      result.match((failure) => throw Exception(failure.message), (_) {});
      return;
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
    result.match((failure) => throw Exception(failure.message), (_) {});
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
