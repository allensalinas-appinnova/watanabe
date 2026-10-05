import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../data/datasources/receipt_image_picker.dart';
import '../../domain/entities/category_budget.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../domain/usecases/update_budget_limits.dart';

final financeAccountsProvider = StreamProvider.family<List<FinanceAccount>, String>(
  (ref, userId) => getIt<FinanceRepository>().watchAccounts(userId),
);

final financeTransactionsProvider = StreamProvider.family<List<FinanceTransaction>, String>(
  (ref, userId) => getIt<FinanceRepository>().watchTransactions(userId),
);

final financeBudgetsProvider = StreamProvider.family<List<CategoryBudget>, String>(
  (ref, userId) => getIt<FinanceRepository>().watchBudgets(userId),
);

final saveExpenseProvider = Provider<SaveExpense>(
  (ref) => SaveExpense(getIt<FinanceRepository>()),
);

final createAccountProvider = Provider<CreateAccount>(
  (ref) => CreateAccount(getIt<FinanceRepository>()),
);

final manageAccountsProvider = Provider<ManageAccounts>(
  (ref) => ManageAccounts(getIt<FinanceRepository>()),
);

final updateBudgetLimitsProvider = Provider<UpdateBudgetLimits>(
  (ref) => UpdateBudgetLimits(getIt<FinanceRepository>()),
);

final receiptImagePickerProvider = Provider<ReceiptImagePicker>(
  (ref) => getIt<ReceiptImagePicker>(),
);

class SaveExpense {
  const SaveExpense(this._repository);

  final FinanceRepository _repository;

  Future<void> call(String userId, ExpenseDraft expense) async {
    final result = await _repository.addExpense(userId, expense);
    result.match((failure) => throw Exception(failure.message), (_) {});
  }
}

class CreateAccount {
  const CreateAccount(this._repository);

  final FinanceRepository _repository;

  Future<void> call(String userId, AccountDraft account) async {
    final result = await _repository.addAccount(userId, account);
    result.match((failure) => throw Exception(failure.message), (_) {});
  }
}

class ManageAccounts {
  const ManageAccounts(this._repository);

  final FinanceRepository _repository;

  Future<void> update(String userId, FinanceAccount account) async {
    final result = await _repository.updateAccount(userId, account);
    result.match((failure) => throw Exception(failure.message), (_) {});
  }

  Future<void> delete(String userId, String accountId) async {
    final result = await _repository.deleteAccount(userId, accountId);
    result.match((failure) => throw Exception(failure.message), (_) {});
  }
}
