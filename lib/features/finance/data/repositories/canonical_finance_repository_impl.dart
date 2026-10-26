import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/firebase_failure_mapper.dart';
import '../../domain/entities/appearance_preferences.dart';
import '../../domain/entities/balance_adjustment.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_flow_type.dart';
import '../../domain/entities/budget_item.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/home_dashboard_preferences.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/entities/operation_page.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../datasources/budget_command_failure_mapper.dart';
import '../datasources/canonical_finance_remote_data_source.dart';
import '../mappers/firestore_date_mapper.dart';

class CanonicalFinanceRepositoryImpl implements CanonicalFinanceRepository {
  const CanonicalFinanceRepositoryImpl({required CanonicalFinanceRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final CanonicalFinanceRemoteDataSource _remoteDataSource;

  @override
  Stream<UserProfile?> watchUserProfile(String userId) => _remoteDataSource
      .watchUserProfile(userId)
      .map((record) => record == null ? null : _profile(record, userId));

  @override
  Future<Either<Failure, Unit>> updateHomeDashboardPreferences(
    String userId,
    HomeDashboardPreferences preferences,
  ) async {
    try {
      await _remoteDataSource.updateHomeDashboardPreferences(userId, preferences);
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateAppearancePreferences(
    String userId,
    AppearancePreferences preferences,
  ) async {
    try {
      await _remoteDataSource.updateAppearancePreferences(userId, preferences);
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> ensureDefaultCategories(
    String userId, {
    required String locale,
    required String countryCode,
    String timeZone = 'UTC',
    String defaultCurrency = 'COP',
  }) async {
    try {
      await _remoteDataSource.ensureDefaultCategories(
        userId,
        locale: locale,
        countryCode: countryCode,
        timeZone: timeZone,
        defaultCurrency: defaultCurrency,
      );
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> syncDefaultCategories(
    String userId, {
    required String locale,
    required String countryCode,
  }) async {
    try {
      await _remoteDataSource.syncDefaultCategories(
        userId,
        locale: locale,
        countryCode: countryCode,
      );
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Stream<List<FinanceCategory>> watchCategories(String userId) =>
      _remoteDataSource.watchCategories(userId).map((records) => records.map(_category).toList());

  @override
  Future<Either<Failure, FinanceCategory>> createCategory(
    String userId, {
    required String name,
    required CategoryType type,
    required String icon,
    int? colorValue,
  }) async {
    try {
      return Right(
        _category(
          await _remoteDataSource.createCategory(
            userId,
            name: name,
            type: type,
            icon: icon,
            colorValue: colorValue,
          ),
        ),
      );
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateCategory(String userId, FinanceCategory category) async {
    try {
      await _remoteDataSource.updateCategory(userId, category);
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> archiveCategory(String userId, String categoryId) async {
    try {
      await _remoteDataSource.archiveCategory(userId, categoryId);
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Stream<List<FinanceAccount>> watchAccounts(String userId) =>
      _remoteDataSource.watchAccounts(userId).map((records) => records.map(_account).toList());

  @override
  Stream<FinanceAccount?> watchAccount(String userId, String accountId) => _remoteDataSource
      .watchAccount(userId, accountId)
      .map((record) => record == null ? null : _account(record));

  @override
  Stream<List<BalanceAdjustmentEvent>> watchBalanceAdjustments(String userId) => _remoteDataSource
      .watchBalanceAdjustments(userId)
      .map(
        (records) => records
            .map((record) {
              final adjustedAt =
                  FirestoreDateMapper.toDateTime(record['adjustedAt']) ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
              final rows = (record['adjustments'] as List<dynamic>? ?? const [])
                  .whereType<Map<dynamic, dynamic>>();
              return BalanceAdjustmentEvent(
                requestId: record['requestId'] as String? ?? '',
                adjustedAt: adjustedAt,
                reason: record['reason'] as String?,
                adjustments: rows
                    .map(
                      (row) => BalanceAdjustmentRecord(
                        accountId: row['accountId'] as String? ?? '',
                        currency: row['currency'] as String? ?? '',
                        previousBalanceMinor: row['previousBalanceMinor'] as int? ?? 0,
                        targetBalanceMinor: row['targetBalanceMinor'] as int? ?? 0,
                        deltaMinor: row['deltaMinor'] as int? ?? 0,
                      ),
                    )
                    .toList(growable: false),
              );
            })
            .toList(growable: false),
      );

  @override
  Future<Either<Failure, FinanceAccount>> createAccount(
    String userId, {
    required String name,
    required String type,
    required String currency,
    required int openingBalanceMinor,
  }) async {
    try {
      return Right(
        _account(
          await _remoteDataSource.createAccount(
            userId,
            name: name,
            type: type,
            currency: currency,
            openingBalanceMinor: openingBalanceMinor,
          ),
        ),
      );
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateAccount(String userId, FinanceAccount account) async {
    try {
      await _remoteDataSource.updateAccount(userId, account);
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> archiveAccount(String userId, String accountId) async {
    try {
      await _remoteDataSource.archiveAccount(userId, accountId);
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, BalanceAdjustmentResult>> adjustAccountBalances(
    String userId, {
    required String requestId,
    required List<BalanceAdjustmentDraft> adjustments,
    String? reason,
  }) async {
    try {
      final response = await _remoteDataSource.adjustAccountBalances(
        userId: userId,
        requestId: requestId,
        adjustments: adjustments,
        reason: reason,
      );
      final records = (response['adjustments'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (row) => BalanceAdjustmentRecord(
              accountId: row['accountId'] as String,
              currency: row['currency'] as String,
              previousBalanceMinor: row['previousBalanceMinor'] as int,
              targetBalanceMinor: row['targetBalanceMinor'] as int,
              deltaMinor: row['deltaMinor'] as int,
            ),
          )
          .toList(growable: false);
      return Right(
        BalanceAdjustmentResult(
          requestId: response['requestId'] as String,
          adjustments: records,
          adjustedAt: DateTime.parse(response['adjustedAt'] as String),
        ),
      );
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Stream<List<FinancialOperation>> watchOperations(String userId) =>
      _remoteDataSource.watchOperations(userId).map(_visibleOperations);

  @override
  Future<Either<Failure, OperationPage>> fetchOperationsPage(
    String userId, {
    OperationPageCursor? cursor,
    String? monthKey,
    String? currency,
    OperationType? type,
    bool debtPaymentsOnly = false,
    String? accountId,
    List<String>? accountIds,
    DateTime? startAt,
    DateTime? endAtExclusive,
    int pageSize = 100,
  }) async {
    try {
      final page = await _remoteDataSource.fetchOperationsPage(
        userId,
        cursor: cursor,
        monthKey: monthKey,
        currency: currency,
        type: type,
        debtPaymentsOnly: debtPaymentsOnly,
        accountId: accountId,
        accountIds: accountIds,
        startAt: startAt,
        endAtExclusive: endAtExclusive,
        pageSize: pageSize,
      );
      return Right(
        OperationPage(
          // A user-initiated removal is represented as a rejected operation
          // because Firestore rules intentionally disallow hard deletes. It
          // must not continue to appear in activity or recent activity.
          items: _visibleOperations(page.records),
          nextCursor: page.nextCursor,
        ),
      );
    } catch (error, stackTrace) {
      // This path intentionally returns a user-safe Failure, so retain a
      // redacted diagnostic in debug builds instead of silently swallowing
      // the Firestore error. Never log document contents or the user ID.
      if (kDebugMode) {
        final requestCode = error is FirebaseException
            ? '${error.plugin}/${error.code}'
            : error.runtimeType.toString();
        debugPrint('fetchOperationsPage failed ($requestCode)');
        debugPrintStack(stackTrace: stackTrace);
      }
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  List<FinancialOperation> _visibleOperations(List<Map<String, dynamic>> records) => records
      .map(_operation)
      .where((operation) => operation.status != OperationStatus.rejected)
      .toList(growable: false);

  @override
  Stream<List<LedgerEntry>> watchLedgerEntries(String userId, String accountId) => _remoteDataSource
      .watchLedgerEntries(userId, accountId)
      .map((records) => records.map(_ledgerEntry).toList());

  @override
  Future<Either<Failure, FinancialOperation>> createOperation(
    String userId,
    FinancialOperationDraft draft,
  ) async {
    try {
      final record = await _remoteDataSource.createOperation(userId, draft);
      return Right(_operation(record));
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, FinancialOperation>> createTransfer(
    String userId,
    TransferDraft draft,
  ) async {
    try {
      final record = await _remoteDataSource.createTransfer(userId, draft);
      return Right(_operation(record));
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateOperation(
    String userId,
    FinancialOperation operation,
  ) async {
    try {
      await _remoteDataSource.updateOperation(userId, operation);
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteOperation(String userId, String operationId) async {
    try {
      await _remoteDataSource.deleteOperation(userId, operationId);
      return const Right(unit);
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Stream<List<Budget>> watchBudgets(String userId, String monthKey) => _remoteDataSource
      .watchBudgets(userId, monthKey)
      .map((records) => records.map(_budget).toList());

  @override
  Stream<Budget?> watchBudget(String userId, String budgetId) => _remoteDataSource
      .watchBudget(userId, budgetId)
      .map((record) => record == null ? null : _budget(record));

  @override
  Future<Either<Failure, Budget>> createBudgetWithItems(
    String userId, {
    required String categoryId,
    required String flowType,
    required String monthKey,
    required String currency,
    required List<CanonicalBudgetItemDraft> items,
    String? requestId,
  }) async {
    try {
      final record = await _remoteDataSource.createBudgetWithItems(
        userId,
        categoryId: categoryId,
        flowType: flowType,
        monthKey: monthKey,
        currency: currency,
        items: items,
        requestId: requestId,
      );
      return Right(_budget(record));
    } catch (error) {
      if (error is StateError && error.message.contains('A budget already exists')) {
        return const Left(ConflictFailure('budget-already-exists'));
      }
      return Left(BudgetCommandFailureMapper.fromException(error));
    }
  }

  @override
  Stream<List<BudgetItem>> watchBudgetItems(String userId, String budgetId) => _remoteDataSource
      .watchBudgetItems(userId, budgetId)
      .map(
        (records) => records.map(_budgetItem).toList(),
      );

  @override
  Stream<List<FinancialOperation>> watchBudgetItemOperations(
    String userId,
    String budgetId,
    String itemId,
  ) => _remoteDataSource
      .watchBudgetItemOperations(userId, budgetId, itemId)
      .map((records) => records.map(_operation).toList());

  @override
  Future<Either<Failure, BudgetItem>> addBudgetItem(
    String userId,
    String budgetId,
    CanonicalBudgetItemDraft item, {
    String? requestId,
  }) async {
    try {
      return Right(
        _budgetItem(
          await _remoteDataSource.addBudgetItem(userId, budgetId, item, requestId: requestId),
        ),
      );
    } catch (error) {
      return Left(BudgetCommandFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateBudgetItem(
    String userId,
    String budgetId,
    BudgetItem item, {
    String? requestId,
  }) async {
    try {
      await _remoteDataSource.updateBudgetItem(userId, budgetId, item, requestId: requestId);
      return const Right(unit);
    } catch (error) {
      return Left(BudgetCommandFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteBudgetItem(
    String userId,
    String budgetId,
    String itemId, {
    String? requestId,
  }) async {
    try {
      await _remoteDataSource.deleteBudgetItem(userId, budgetId, itemId, requestId: requestId);
      return const Right(unit);
    } catch (error) {
      if (error is StateError && error.message == 'budget-last-item') {
        return const Left(ConflictFailure('budget-last-item'));
      }
      return Left(BudgetCommandFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> archiveBudget(
    String userId,
    String budgetId, {
    String? requestId,
  }) async {
    try {
      await _remoteDataSource.archiveBudget(userId, budgetId, requestId: requestId);
      return const Right(unit);
    } catch (error) {
      return Left(BudgetCommandFailureMapper.fromException(error));
    }
  }

  @override
  Stream<MonthlySummary?> watchMonthlySummary(String userId, String monthKey, String currency) =>
      _remoteDataSource
          .watchMonthlySummary(userId, monthKey, currency)
          .map(
            (record) => record == null
                ? null
                : MonthlySummary(
                    monthKey: record['monthKey'] as String? ?? monthKey,
                    currency: record['currency'] as String? ?? currency,
                    incomeMinor: (record['incomeMinor'] as num? ?? 0).toInt(),
                    expenseMinor: (record['expenseMinor'] as num? ?? 0).toInt(),
                    transferInMinor: (record['transferInMinor'] as num? ?? 0).toInt(),
                    transferOutMinor: (record['transferOutMinor'] as num? ?? 0).toInt(),
                    byCategory: Map<String, int>.from(record['byCategory'] as Map? ?? const {}),
                  ),
          );

  UserProfile _profile(Map<String, dynamic> data, String id) => UserProfile(
    id: id,
    locale: data['locale'] as String? ?? 'es',
    countryCode: data['countryCode'] as String? ?? 'CO',
    timeZone: data['timeZone'] as String? ?? 'UTC',
    defaultCurrency: data['defaultCurrency'] as String? ?? 'COP',
    onboardingStatus: data['onboardingStatus'] as String? ?? 'not_started',
    categoryCatalogVersion: (data['categoryCatalogVersion'] as num? ?? 1).toInt(),
    homeDashboardPreferences: HomeDashboardPreferences.fromMap(data['homePreferences']),
    appearancePreferences: AppearancePreferences.fromMap(data['appearancePreferences']),
    dataGeneration: (data['dataGeneration'] as num? ?? 0).toInt(),
    resetStatus: data['resetStatus'] as String? ?? 'ready',
    resetRequestId: data['resetRequestId'] as String?,
    resetPreviousGeneration: (data['resetPreviousGeneration'] as num?)?.toInt(),
  );

  FinanceCategory _category(Map<String, dynamic> data) => FinanceCategory(
    id: data['id'] as String,
    type: data['type'] == 'income' ? CategoryType.income : CategoryType.expense,
    icon: data['icon'] as String? ?? 'category',
    sortOrder: (data['sortOrder'] as num? ?? 0).toInt(),
    isSystem: data['isSystem'] as bool? ?? false,
    isArchived: data['isArchived'] as bool? ?? false,
    catalogId: data['catalogId'] as String?,
    customName: data['name'] as String?,
    colorValue: data['colorValue'] is int ? data['colorValue'] as int : null,
  );

  FinanceAccount _account(Map<String, dynamic> data) => FinanceAccount(
    id: data['id'] as String,
    name: data['name'] as String? ?? '',
    type: data['type'] as String? ?? 'cash',
    currency: data['currency'] as String? ?? 'COP',
    openingBalanceMinor: (data['openingBalanceMinor'] as num? ?? 0).toInt(),
    currentBalanceMinor: (data['currentBalanceMinor'] as num? ?? 0).toInt(),
    includeInDashboard: data['includeInDashboard'] as bool? ?? true,
    status: data['status'] as String? ?? 'active',
    createdAt: FirestoreDateMapper.toDateTime(data['createdAt']),
    updatedAt: FirestoreDateMapper.toDateTime(data['updatedAt']),
    archivedAt: FirestoreDateMapper.toDateTime(data['archivedAt']),
    nature: data['nature'] as String? ?? 'money',
    referenceAt: FirestoreDateMapper.toDateTime(data['referenceAt']),
    principalMinor: (data['principalMinor'] as num? ?? 0).toInt(),
    chargesMinor: (data['chargesMinor'] as num? ?? 0).toInt(),
    limitMinor: (data['limitMinor'] as num?)?.toInt(),
    creditor: data['creditor'] as String?,
    lastFour: data['lastFour'] as String?,
    statementClosingDay: (data['statementClosingDay'] as num?)?.toInt(),
    paymentDueDay: (data['paymentDueDay'] as num?)?.toInt(),
  );

  FinancialOperation _operation(Map<String, dynamic> data) => FinancialOperation(
    id: data['id'] as String,
    type: OperationType.values.byName(data['type'] as String? ?? 'expense'),
    amountMinor: (data['amountMinor'] as num? ?? 0).toInt(),
    currency: data['currency'] as String? ?? 'COP',
    monthKey: data['monthKey'] as String? ?? '',
    occurredAt:
        FirestoreDateMapper.toDateTime(data['occurredAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    status: OperationStatus.values.byName(data['status'] as String? ?? 'confirmed'),
    idempotencyKey: data['idempotencyKey'] as String? ?? data['id'] as String,
    categoryId: data['categoryId'] as String?,
    accountId: data['accountId'] as String?,
    sourceAccountId: data['sourceAccountId'] as String?,
    destinationAccountId: data['destinationAccountId'] as String?,
    budgetId: data['budgetId'] as String?,
    budgetItemId: data['budgetItemId'] as String?,
    description: data['description'] as String? ?? '',
    debtCommandId: data['debtCommandId'] as String?,
    debtAccountId: data['debtAccountId'] as String?,
    debtKind: data['debtKind'] as String?,
    originalOperationId: data['originalOperationId'] as String?,
    reversalOf: data['reversalOf'] as String?,
    projectionDirection: (data['projectionDirection'] as num? ?? 1).toInt(),
    principalDeltaMinor: (data['principalDeltaMinor'] as num? ?? 0).toInt(),
    chargesDeltaMinor: (data['chargesDeltaMinor'] as num? ?? 0).toInt(),
    balanceDeltaMinor: (data['balanceDeltaMinor'] as num?)?.toInt(),
    previousBalanceMinor: (data['previousBalanceMinor'] as num?)?.toInt(),
    targetBalanceMinor: (data['targetBalanceMinor'] as num?)?.toInt(),
    paymentId: data['paymentId'] as String?,
    allocationStatus: data['allocationStatus'] as String?,
    createdAt: FirestoreDateMapper.toDateTime(data['createdAt']),
    updatedAt: FirestoreDateMapper.toDateTime(data['updatedAt']),
  );

  LedgerEntry _ledgerEntry(Map<String, dynamic> data) => LedgerEntry(
    id: data['id'] as String,
    operationId: data['operationId'] as String,
    accountId: data['accountId'] as String,
    deltaMinor: (data['deltaMinor'] as num? ?? 0).toInt(),
    currency: data['currency'] as String? ?? 'COP',
  );

  Budget _budget(Map<String, dynamic> data) => Budget(
    id: data['id'] as String,
    categoryId: data['categoryId'] as String,
    flowType: BudgetFlowTypeValue.fromValue(data['flowType'] as String?),
    monthKey: data['monthKey'] as String,
    currency: data['currency'] as String,
    plannedAmountMinor: (data['plannedAmountMinor'] as num? ?? 0).toInt(),
    status: data['status'] as String? ?? 'active',
  );

  BudgetItem _budgetItem(Map<String, dynamic> data) => BudgetItem(
    id: data['id'] as String,
    description: data['description'] as String? ?? '',
    amountMinor: (data['amountMinor'] as num? ?? 0).toInt(),
    dayOfMonth: (data['dayOfMonth'] as num? ?? 1).toInt(),
    actualAmountMinor: (data['actualAmountMinor'] as num? ?? 0).toInt(),
    status: data['status'] as String? ?? 'active',
    createdAt: FirestoreDateMapper.toDateTime(data['createdAt']),
    updatedAt: FirestoreDateMapper.toDateTime(data['updatedAt']),
    archivedAt: FirestoreDateMapper.toDateTime(data['archivedAt']),
  );
}
