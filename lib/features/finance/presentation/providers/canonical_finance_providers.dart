import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/monthly_summary.dart';
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
  (ref) => CanonicalFinanceActions(getIt<CanonicalFinanceRepository>()),
);

class CanonicalFinanceActions {
  const CanonicalFinanceActions(this._repository);

  final CanonicalFinanceRepository _repository;

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

  Future<void> createOperation(
    String userId,
    FinancialOperationDraft draft,
  ) async {
    final result = await _repository.createOperation(userId, draft);
    result.match((failure) => throw Exception(failure.message), (_) {});
  }

  Future<void> createTransfer(String userId, TransferDraft draft) async {
    final result = await _repository.createTransfer(userId, draft);
    result.match((failure) => throw Exception(failure.message), (_) {});
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
}
