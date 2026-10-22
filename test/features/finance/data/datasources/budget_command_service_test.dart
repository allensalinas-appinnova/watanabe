import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/finance/data/datasources/budget_command_service.dart';
import 'package:personal_finance/features/finance/data/datasources/canonical_finance_remote_data_source.dart';
import 'package:personal_finance/features/finance/data/repositories/canonical_finance_repository_impl.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';

class _Firestore extends Mock implements FirebaseFirestore {}

class _Functions extends Mock implements FirebaseFunctions {}

class _Auth extends Mock implements FirebaseAuth {}

class _User extends Mock implements User {}

class _Commands implements BudgetCommandService {
  final calls = <Map<String, dynamic>>[];
  Object? error;

  @override
  Future<Map<String, dynamic>> execute(String userId, Map<String, dynamic> command) async {
    calls.add(command);
    if (error != null) throw error!;
    return {
      'budget': {
        'id': 'budget',
        'categoryId': 'food',
        'flowType': 'expense',
        'monthKey': '2026-10',
        'currency': 'COP',
        'plannedAmountMinor': 100,
        'status': 'active',
      },
      'item': {'id': 'item', 'description': 'Item', 'amountMinor': 100, 'dayOfMonth': 1},
    };
  }
}

void main() {
  test('callable refuses a missing or changed session before sending a command', () async {
    final functions = _Functions();
    final auth = _Auth();
    final service = FirebaseBudgetCommandService(functions: functions, auth: auth);
    when(() => auth.currentUser).thenReturn(null);
    await expectLater(
      service.execute('alice', {'requestId': 'stable-request'}),
      throwsA(
        isA<FirebaseFunctionsException>().having((error) => error.code, 'code', 'unauthenticated'),
      ),
    );
    final user = _User();
    when(() => user.uid).thenReturn('bob');
    when(() => auth.currentUser).thenReturn(user);
    await expectLater(
      service.execute('alice', {'requestId': 'stable-request'}),
      throwsA(
        isA<FirebaseFunctionsException>().having((error) => error.code, 'code', 'unauthenticated'),
      ),
    );
    verifyZeroInteractions(functions);
  });

  test(
    'budget repository delegates to callable with explicit request ID and sends no client aggregates',
    () async {
      final commands = _Commands();
      final firestore = _Firestore();
      final repository = CanonicalFinanceRepositoryImpl(
        remoteDataSource: FirestoreCanonicalFinanceRemoteDataSource(
          firestore: firestore,
          budgetCommands: commands,
        ),
      );
      final result = await repository.createBudgetWithItems(
        'user',
        categoryId: 'food',
        flowType: 'expense',
        monthKey: '2026-10',
        currency: 'COP',
        requestId: 'stable-request',
        items: [
          const CanonicalBudgetItemDraft(description: 'Item', amountMinor: 100, dayOfMonth: 1),
        ],
      );
      expect(result.isRight(), isTrue);
      expect(commands.calls.single['requestId'], 'stable-request');
      expect(commands.calls.single.keys, isNot(contains('plannedAmountMinor')));
      expect(commands.calls.single.keys, isNot(contains('userId')));
      verifyZeroInteractions(firestore);
    },
  );

  test('callable business and network failures map to sanitized repository failures', () async {
    final commands = _Commands();
    final repository = CanonicalFinanceRepositoryImpl(
      remoteDataSource: FirestoreCanonicalFinanceRemoteDataSource(
        firestore: _Firestore(),
        budgetCommands: commands,
      ),
    );
    commands.error = FirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'PRIVATE',
      details: {'issue': 'budget-last-item'},
    );
    final result = await repository.deleteBudgetItem(
      'user',
      'budget',
      'item',
      requestId: 'delete-request',
    );
    result.match((failure) {
      expect(failure, isA<ConflictFailure>());
      expect(failure.technicalCode, 'budget-last-item');
      expect(failure.message, isNot(contains('PRIVATE')));
    }, (_) => fail('Expected conflict'));
    commands.error = FirebaseFunctionsException(code: 'deadline-exceeded', message: 'PRIVATE');
    (await repository.archiveBudget('user', 'budget')).match((failure) {
      expect(failure, isA<NetworkFailure>());
      expect(failure.message, isNot(contains('pendiente')));
      expect(failure.message, isNot(contains('PRIVATE')));
    }, (_) => fail('Expected network failure'));
  });
}
