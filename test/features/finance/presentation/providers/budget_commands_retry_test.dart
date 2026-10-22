import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/firebase/firebase_observability.dart';
import 'package:personal_finance/core/offline/pending_operation_queue.dart';
import 'package:personal_finance/core/offline/pending_operation_sync_service.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_item.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';

class _Repository extends Mock implements CanonicalFinanceRepository {}

class _Sync extends Mock implements PendingOperationSyncService {}

class _Database extends Mock implements PendingOperationDatabase {}

class _Observability extends FirebaseObservability {
  _Observability() : super(AppEnvironment.dev);
}

void main() {
  test(
    'retry preserves request ID, while a later intentional identical addition gets a new ID',
    () async {
      final repository = _Repository();
      const draft = CanonicalBudgetItemDraft(description: 'Item', amountMinor: 100, dayOfMonth: 1);
      final requests = <String>[];
      when(
        () => repository.addBudgetItem('user', 'budget', draft, requestId: any(named: 'requestId')),
      ).thenAnswer((invocation) async {
        requests.add(invocation.namedArguments[#requestId] as String);
        if (requests.length == 1) return const Left(NetworkFailure('budget-connection-required'));
        return const Right(
          BudgetItem(id: 'item', description: 'Item', amountMinor: 100, dayOfMonth: 1),
        );
      });
      final actions = CanonicalFinanceActions(repository, _Sync(), _Database(), _Observability());
      await expectLater(actions.addBudgetItem('user', 'budget', draft), throwsA(anything));
      await actions.addBudgetItem('user', 'budget', draft);
      await actions.addBudgetItem('user', 'budget', draft);
      expect(requests[0], requests[1]);
      expect(requests[2], isNot(requests[1]));
    },
  );
}
