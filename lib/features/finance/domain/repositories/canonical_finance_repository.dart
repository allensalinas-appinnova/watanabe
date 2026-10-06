import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/budget.dart';
import '../entities/budget_item.dart';
import '../entities/finance_account.dart';
import '../entities/finance_category.dart';
import '../entities/financial_operation.dart';
import '../entities/ledger_entry.dart';
import '../entities/monthly_summary.dart';
import '../entities/operation_page.dart';
import '../entities/user_profile.dart';

class FinancialOperationDraft {
  const FinancialOperationDraft({
    required this.type,
    required this.amountMinor,
    required this.currency,
    required this.accountId,
    required this.occurredAt,
    this.monthKey,
    required this.description,
    required this.idempotencyKey,
    this.categoryId,
  });

  final OperationType type;
  final int amountMinor;
  final String currency;
  final String accountId;
  final DateTime occurredAt;
  final String? monthKey;
  final String description;
  final String idempotencyKey;
  final String? categoryId;
}

class TransferDraft {
  const TransferDraft({
    required this.amountMinor,
    required this.currency,
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.occurredAt,
    required this.description,
    required this.idempotencyKey,
    this.monthKey,
  });

  final int amountMinor;
  final String currency;
  final String sourceAccountId;
  final String destinationAccountId;
  final DateTime occurredAt;
  final String? monthKey;
  final String description;
  final String idempotencyKey;
}

class CanonicalBudgetItemDraft {
  const CanonicalBudgetItemDraft({
    required this.description,
    required this.amountMinor,
    required this.dayOfMonth,
  });

  final String description;
  final int amountMinor;
  final int dayOfMonth;
}

abstract interface class CanonicalFinanceRepository {
  Stream<UserProfile?> watchUserProfile(String userId);

  Future<Either<Failure, Unit>> ensureDefaultCategories(
    String userId, {
    required String locale,
    required String countryCode,
    String timeZone = 'UTC',
    String defaultCurrency = 'COP',
  });

  Stream<List<FinanceCategory>> watchCategories(String userId);

  Future<Either<Failure, FinanceCategory>> createCategory(
    String userId, {
    required String name,
    required CategoryType type,
    required String icon,
    int? colorValue,
  });

  Future<Either<Failure, Unit>> updateCategory(
    String userId,
    FinanceCategory category,
  );

  Future<Either<Failure, Unit>> archiveCategory(String userId, String categoryId);

  Stream<List<FinanceAccount>> watchAccounts(String userId);

  Future<Either<Failure, FinanceAccount>> createAccount(
    String userId, {
    required String name,
    required String type,
    required String currency,
    required int openingBalanceMinor,
  });

  Future<Either<Failure, Unit>> updateAccount(String userId, FinanceAccount account);

  Future<Either<Failure, Unit>> archiveAccount(String userId, String accountId);

  Stream<List<FinancialOperation>> watchOperations(String userId);

  Future<Either<Failure, OperationPage>> fetchOperationsPage(
    String userId, {
    OperationPageCursor? cursor,
    String? monthKey,
    String? currency,
    int pageSize = 100,
  });

  Stream<List<LedgerEntry>> watchLedgerEntries(String userId, String accountId);

  Future<Either<Failure, FinancialOperation>> createOperation(
    String userId,
    FinancialOperationDraft draft,
  );

  Future<Either<Failure, FinancialOperation>> createTransfer(
    String userId,
    TransferDraft draft,
  );

  Future<Either<Failure, Unit>> updateOperation(
    String userId,
    FinancialOperation operation,
  );

  Future<Either<Failure, Unit>> deleteOperation(String userId, String operationId);

  Stream<List<Budget>> watchBudgets(String userId, String monthKey);

  Future<Either<Failure, Budget>> createBudgetWithItems(
    String userId, {
    required String categoryId,
    required String flowType,
    required String monthKey,
    required String currency,
    required List<CanonicalBudgetItemDraft> items,
  });

  Stream<MonthlySummary?> watchMonthlySummary(
    String userId,
    String monthKey,
    String currency,
  );

  Stream<List<BudgetItem>> watchBudgetItems(String userId, String budgetId);

  Future<Either<Failure, BudgetItem>> addBudgetItem(
    String userId,
    String budgetId,
    CanonicalBudgetItemDraft item,
  );

  Future<Either<Failure, Unit>> updateBudgetItem(
    String userId,
    String budgetId,
    BudgetItem item,
  );

  Future<Either<Failure, Unit>> deleteBudgetItem(
    String userId,
    String budgetId,
    String itemId,
  );

  Future<Either<Failure, Unit>> archiveBudget(String userId, String budgetId);
}
