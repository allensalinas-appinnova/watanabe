import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/entities/finance_account.dart';
import '../../domain/repositories/finance_repository.dart';

abstract interface class FinanceRemoteDataSource {
  Stream<List<Map<String, dynamic>>> watchAccounts(String userId);

  Stream<List<Map<String, dynamic>>> watchTransactions(String userId);

  Stream<List<Map<String, dynamic>>> watchBudgets(String userId);

  Future<String> addAccount(String userId, AccountDraft account);

  Future<void> updateAccount(String userId, FinanceAccount account);

  Future<void> deleteAccount(String userId, String accountId);

  Future<String> addExpense(String userId, ExpenseDraft expense);

  Future<void> updateBudgetLimits(
    String userId,
    Map<String, double> limitsByBudgetId,
  );
}

class FirestoreFinanceRemoteDataSource implements FinanceRemoteDataSource {
  const FirestoreFinanceRemoteDataSource({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  }) : _firestore = firestore,
       _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _collection(
    String userId,
    String name,
  ) => _firestore.collection('users').doc(userId).collection(name);

  @override
  Stream<List<Map<String, dynamic>>> watchAccounts(String userId) =>
      _collection(userId, 'accounts').snapshots().map((snapshot) {
        final documents = snapshot.docs.toList()
          ..sort(
            (a, b) =>
                (a.data()['sortOrder'] as num? ?? 0).compareTo(b.data()['sortOrder'] as num? ?? 0),
          );
        return documents.map((document) => {...document.data(), 'id': document.id}).toList();
      });

  @override
  Stream<List<Map<String, dynamic>>> watchTransactions(String userId) =>
      _collection(userId, 'cashflow').snapshots().map((snapshot) {
        final documents = snapshot.docs.toList()
          ..sort((a, b) {
            final left = a.data()['date'] as Timestamp?;
            final right = b.data()['date'] as Timestamp?;
            return (right?.millisecondsSinceEpoch ?? 0).compareTo(
              left?.millisecondsSinceEpoch ?? 0,
            );
          });
        return documents.map((document) => {...document.data(), 'id': document.id}).toList();
      });

  @override
  Stream<List<Map<String, dynamic>>> watchBudgets(String userId) =>
      _collection(userId, 'budgets').snapshots().map(
        (snapshot) =>
            snapshot.docs.map((document) => {...document.data(), 'id': document.id}).toList(),
      );

  @override
  Future<String> addAccount(String userId, AccountDraft account) async {
    final document = await _collection(userId, 'accounts').add({
      'name': account.name,
      'type': account.type,
      'balance': account.balance,
      'includeInDashboard': true,
      'sortOrder': DateTime.now().microsecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return document.id;
  }

  @override
  Future<void> updateAccount(String userId, FinanceAccount account) =>
      _collection(userId, 'accounts').doc(account.id).update({
        'name': account.name,
        'type': account.type,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deleteAccount(String userId, String accountId) async {
    final movements = await _collection(
      userId,
      'cashflow',
    ).where('accountId', isEqualTo: accountId).get();
    var offset = 0;
    while (movements.docs.length - offset > 499) {
      final batch = _firestore.batch();
      for (final movement in movements.docs.skip(offset).take(499)) {
        batch.delete(movement.reference);
      }
      await batch.commit();
      offset += 499;
    }
    final finalBatch = _firestore.batch();
    for (final movement in movements.docs.skip(offset)) {
      finalBatch.delete(movement.reference);
    }
    finalBatch.delete(_collection(userId, 'accounts').doc(accountId));
    await finalBatch.commit();

    for (final receiptPath
        in movements.docs.map((movement) => movement.data()['receiptPath']).whereType<String>()) {
      try {
        await _storage.ref(receiptPath).delete();
      } on FirebaseException catch (_) {
        // Firestore deletion is authoritative; stale objects can be cleaned later.
      }
    }
  }

  @override
  Future<String> addExpense(String userId, ExpenseDraft expense) async {
    final accounts = _collection(userId, 'accounts');
    final accountRef = accounts.doc(expense.accountId);
    final transactionRef = _collection(userId, 'cashflow').doc();
    final budgets = _collection(userId, 'budgets');
    final matchingBudgets = await budgets
        .where('category', isEqualTo: expense.category)
        .limit(1)
        .get();
    final budgetRef = matchingBudgets.docs.isEmpty ? null : matchingBudgets.docs.first.reference;
    String? receiptPath;
    if (expense.receiptAttachment case final receipt?) {
      receiptPath = 'users/$userId/receipts/${transactionRef.id}.${receipt.fileExtension}';
      await _storage
          .ref(receiptPath)
          .putData(
            receipt.bytes,
            SettableMetadata(contentType: receipt.contentType),
          );
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final accountSnapshot = await transaction.get(accountRef);
        final budgetSnapshot = budgetRef == null ? null : await transaction.get(budgetRef);
        if (!accountSnapshot.exists) {
          throw StateError('The selected account no longer exists.');
        }

        final currentBalance = (accountSnapshot.data()?['balance'] as num?) ?? 0;
        final transactionData = <String, Object>{
          'description': expense.description,
          'category': expense.category,
          'accountId': expense.accountId,
          'amount': expense.amount,
          'type': 'expense',
          'date': Timestamp.fromDate(expense.date),
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (receiptPath != null) transactionData['receiptPath'] = receiptPath;
        transaction
          ..update(accountRef, {
            'balance': currentBalance - expense.amount,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(transactionRef, transactionData);

        if (budgetRef != null && budgetSnapshot != null) {
          final spent = (budgetSnapshot.data()?['spent'] as num?) ?? 0;
          transaction.update(budgetRef, {'spent': spent + expense.amount});
        }
      });
    } catch (error, stackTrace) {
      if (receiptPath != null) {
        try {
          await _storage.ref(receiptPath).delete();
        } on Object catch (_) {
          Error.throwWithStackTrace(error, stackTrace);
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    return transactionRef.id;
  }

  @override
  Future<void> updateBudgetLimits(
    String userId,
    Map<String, double> limitsByBudgetId,
  ) async {
    if (limitsByBudgetId.isEmpty) return;
    final batch = _firestore.batch();
    final budgets = _collection(userId, 'budgets');
    for (final entry in limitsByBudgetId.entries) {
      batch.update(budgets.doc(entry.key), {
        'limit': entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
