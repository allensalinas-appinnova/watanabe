import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/category_budget.dart';
import '../entities/finance_account.dart';
import '../entities/finance_transaction.dart';
import '../entities/receipt_attachment.dart';

class ExpenseDraft {
  const ExpenseDraft({
    required this.description,
    required this.category,
    required this.accountId,
    required this.amount,
    required this.date,
    this.receiptAttachment,
  });

  final String description;
  final String category;
  final String accountId;
  final double amount;
  final DateTime date;
  final ReceiptAttachment? receiptAttachment;
}

class AccountDraft {
  const AccountDraft({required this.name, required this.type, required this.balance});

  final String name;
  final String type;
  final double balance;
}

abstract interface class FinanceRepository {
  Stream<List<FinanceAccount>> watchAccounts(String userId);

  Stream<List<FinanceTransaction>> watchTransactions(String userId);

  Stream<List<CategoryBudget>> watchBudgets(String userId);

  Future<Either<Failure, FinanceAccount>> addAccount(
    String userId,
    AccountDraft account,
  );

  Future<Either<Failure, Unit>> updateAccount(String userId, FinanceAccount account);

  Future<Either<Failure, Unit>> deleteAccount(String userId, String accountId);

  Future<Either<Failure, FinanceTransaction>> addExpense(
    String userId,
    ExpenseDraft expense,
  );

  Future<Either<Failure, Unit>> updateBudgetLimits(
    String userId,
    Map<String, double> limitsByBudgetId,
  );
}
