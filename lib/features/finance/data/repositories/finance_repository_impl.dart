import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/category_budget.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/repositories/finance_repository.dart';
import '../datasources/finance_remote_data_source.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  const FinanceRepositoryImpl({required FinanceRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final FinanceRemoteDataSource _remoteDataSource;

  @override
  Stream<List<FinanceAccount>> watchAccounts(String userId) => _remoteDataSource
      .watchAccounts(userId)
      .map(
        (records) => records.map(_accountFromRecord).toList(),
      );

  @override
  Stream<List<FinanceTransaction>> watchTransactions(String userId) => _remoteDataSource
      .watchTransactions(userId)
      .map(
        (records) => records.map(_transactionFromRecord).toList(),
      );

  @override
  Stream<List<CategoryBudget>> watchBudgets(String userId) => _remoteDataSource
      .watchBudgets(userId)
      .map(
        (records) => records.map(_budgetFromRecord).toList(),
      );

  @override
  Future<Either<Failure, FinanceAccount>> addAccount(
    String userId,
    AccountDraft account,
  ) async {
    try {
      final id = await _remoteDataSource.addAccount(userId, account);
      return Right(
        FinanceAccount(
          id: id,
          name: account.name,
          type: account.type,
          balance: account.balance,
        ),
      );
    } catch (error) {
      return Left(UnknownFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateAccount(
    String userId,
    FinanceAccount account,
  ) async {
    try {
      await _remoteDataSource.updateAccount(userId, account);
      return const Right(unit);
    } catch (error) {
      return Left(UnknownFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteAccount(String userId, String accountId) async {
    try {
      await _remoteDataSource.deleteAccount(userId, accountId);
      return const Right(unit);
    } catch (error) {
      return Left(UnknownFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, FinanceTransaction>> addExpense(
    String userId,
    ExpenseDraft expense,
  ) async {
    try {
      final id = await _remoteDataSource.addExpense(userId, expense);
      return Right(
        FinanceTransaction(
          id: id,
          description: expense.description,
          category: expense.category,
          accountId: expense.accountId,
          amount: expense.amount,
          date: expense.date,
          type: 'expense',
        ),
      );
    } catch (error) {
      return Left(UnknownFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateBudgetLimits(
    String userId,
    Map<String, double> limitsByBudgetId,
  ) async {
    try {
      await _remoteDataSource.updateBudgetLimits(userId, limitsByBudgetId);
      return const Right(unit);
    } catch (error) {
      return Left(UnknownFailure(error.toString()));
    }
  }

  FinanceAccount _accountFromRecord(Map<String, dynamic> data) => FinanceAccount(
    id: data['id'] as String,
    name: data['name'] as String? ?? '',
    type: data['type'] as String? ?? 'account',
    balance: (data['balance'] as num? ?? 0).toDouble(),
  );

  FinanceTransaction _transactionFromRecord(Map<String, dynamic> data) {
    final date = data['date'];
    return FinanceTransaction(
      id: data['id'] as String,
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      accountId: data['accountId'] as String? ?? '',
      amount: (data['amount'] as num? ?? 0).toDouble(),
      date: date is Timestamp ? date.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
      type: data['type'] as String? ?? 'expense',
    );
  }

  CategoryBudget _budgetFromRecord(Map<String, dynamic> data) => CategoryBudget(
    id: data['id'] as String,
    category: data['category'] as String? ?? 'Other',
    spent: (data['spent'] as num? ?? 0).toDouble(),
    limit: (data['limit'] as num? ?? 0).toDouble(),
    colorValue: (data['color'] as num? ?? 0xFF1C61D1).toInt(),
  );
}
