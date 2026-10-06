import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/budget_item.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/repositories/canonical_finance_repository.dart';

abstract interface class CanonicalFinanceRemoteDataSource {
  Stream<Map<String, dynamic>?> watchUserProfile(String userId);

  Future<void> ensureDefaultCategories(
    String userId, {
    required String locale,
    required String countryCode,
    String timeZone = 'UTC',
    String defaultCurrency = 'COP',
  });

  Stream<List<Map<String, dynamic>>> watchCategories(String userId);

  Future<Map<String, dynamic>> createCategory(
    String userId, {
    required String name,
    required CategoryType type,
    required String icon,
    int? colorValue,
  });

  Future<void> updateCategory(String userId, FinanceCategory category);

  Future<void> archiveCategory(String userId, String categoryId);

  Stream<List<Map<String, dynamic>>> watchAccounts(String userId);

  Future<Map<String, dynamic>> createAccount(
    String userId, {
    required String name,
    required String type,
    required String currency,
    required int openingBalanceMinor,
  });

  Future<void> updateAccount(String userId, FinanceAccount account);

  Future<void> archiveAccount(String userId, String accountId);

  Stream<List<Map<String, dynamic>>> watchOperations(String userId);

  Stream<List<Map<String, dynamic>>> watchLedgerEntries(String userId, String accountId);

  Future<Map<String, dynamic>> createOperation(
    String userId,
    FinancialOperationDraft draft,
  );

  Future<Map<String, dynamic>> createTransfer(String userId, TransferDraft draft);

  Future<void> updateOperation(String userId, FinancialOperation operation);

  Future<void> deleteOperation(String userId, String operationId);

  Stream<List<Map<String, dynamic>>> watchBudgets(String userId, String monthKey);

  Future<Map<String, dynamic>> createBudgetWithItems(
    String userId, {
    required String categoryId,
    required String flowType,
    required String monthKey,
    required String currency,
    required List<CanonicalBudgetItemDraft> items,
  });

  Stream<Map<String, dynamic>?> watchMonthlySummary(
    String userId,
    String monthKey,
    String currency,
  );

  Stream<List<Map<String, dynamic>>> watchBudgetItems(String userId, String budgetId);

  Future<Map<String, dynamic>> addBudgetItem(
    String userId,
    String budgetId,
    CanonicalBudgetItemDraft item,
  );

  Future<void> updateBudgetItem(String userId, String budgetId, BudgetItem item);

  Future<void> deleteBudgetItem(String userId, String budgetId, String itemId);

  Future<void> archiveBudget(String userId, String budgetId);
}

class FirestoreCanonicalFinanceRemoteDataSource implements CanonicalFinanceRemoteDataSource {
  const FirestoreCanonicalFinanceRemoteDataSource({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userCollection(String userId, String name) =>
      _firestore.collection('users').doc(userId).collection(name);

  DocumentReference<Map<String, dynamic>> _userDocument(String userId) =>
      _firestore.collection('users').doc(userId);

  @override
  Stream<Map<String, dynamic>?> watchUserProfile(String userId) =>
      _userDocument(userId).snapshots().map((snapshot) => snapshot.exists ? snapshot.data() : null);

  @override
  Future<void> ensureDefaultCategories(
    String userId, {
    required String locale,
    required String countryCode,
    String timeZone = 'UTC',
    String defaultCurrency = 'COP',
  }) async {
    final catalog = await _firestore
        .collection('categoryCatalog')
        .where('isActive', isEqualTo: true)
        .where('supportedCountries', arrayContains: countryCode)
        .get();
    final existing = await _userCollection(userId, 'categories').get();
    final existingIds = existing.docs.map((doc) => doc.id).toSet();
    final batch = _firestore.batch();
    for (final document in catalog.docs) {
      if (existingIds.contains(document.id)) continue;
      final data = document.data();
      final labels = Map<String, dynamic>.from(data['labels'] as Map? ?? const {});
      final localizedName = labels[locale.split('-').first] as String? ?? labels['en'] as String?;
      batch.set(_userCollection(userId, 'categories').doc(document.id), {
        'catalogId': document.id,
        'type': data['type'],
        'name': localizedName ?? data['translationKey'],
        'icon': data['icon'],
        'sortOrder': data['sortOrder'] ?? 0,
        'isSystem': true,
        'isArchived': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(
      _userDocument(userId),
      {
        'locale': locale,
        'countryCode': countryCode,
        'timeZone': timeZone,
        'defaultCurrency': defaultCurrency,
        'onboardingStatus': 'complete',
        'categoryCatalogVersion': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchCategories(String userId) => _userCollection(
    userId,
    'categories',
  ).orderBy('sortOrder').snapshots().map(_records);

  @override
  Stream<List<Map<String, dynamic>>> watchOperations(String userId) => _userCollection(
    userId,
    'operations',
  ).orderBy('occurredAt', descending: true).snapshots().map(_records);

  @override
  Stream<List<Map<String, dynamic>>> watchLedgerEntries(String userId, String accountId) =>
      _userCollection(
            userId,
            'ledgerEntries',
          )
          .where('accountId', isEqualTo: accountId)
          .orderBy('occurredAt', descending: true)
          .snapshots()
          .map(_records);

  @override
  Future<Map<String, dynamic>> createCategory(
    String userId, {
    required String name,
    required CategoryType type,
    required String icon,
    int? colorValue,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Category name is required.');
    final ref = _userCollection(userId, 'categories').doc();
    final data = {
      'type': type.name,
      'name': name.trim(),
      'icon': icon,
      'colorValue': ?colorValue,
      'sortOrder': DateTime.now().microsecondsSinceEpoch,
      'isSystem': false,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await ref.set(data);
    return {...data, 'id': ref.id};
  }

  @override
  Future<void> updateCategory(String userId, FinanceCategory category) =>
      _userCollection(userId, 'categories').doc(category.id).update({
        'name': category.customName,
        'icon': category.icon,
        'colorValue': ?category.colorValue,
        'sortOrder': category.sortOrder,
        'isArchived': category.isArchived,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> archiveCategory(String userId, String categoryId) =>
      _userCollection(userId, 'categories').doc(categoryId).update({
        'isArchived': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Stream<List<Map<String, dynamic>>> watchAccounts(String userId) => _userCollection(
    userId,
    'accounts',
  ).where('status', isEqualTo: 'active').snapshots().map(_records);

  @override
  Future<Map<String, dynamic>> createAccount(
    String userId, {
    required String name,
    required String type,
    required String currency,
    required int openingBalanceMinor,
  }) async {
    if (name.trim().isEmpty || openingBalanceMinor < 0 || !_validCurrency(currency)) {
      throw ArgumentError('Invalid account data.');
    }
    final ref = _userCollection(userId, 'accounts').doc();
    final data = {
      'name': name.trim(),
      'type': type,
      'currency': currency,
      'openingBalanceMinor': openingBalanceMinor,
      'currentBalanceMinor': openingBalanceMinor,
      'includeInDashboard': true,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await ref.set(data);
    return {...data, 'id': ref.id};
  }

  @override
  Future<void> updateAccount(String userId, FinanceAccount account) =>
      _userCollection(userId, 'accounts').doc(account.id).update({
        'name': account.name,
        'includeInDashboard': account.includeInDashboard,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> archiveAccount(String userId, String accountId) =>
      _userCollection(userId, 'accounts').doc(accountId).update({
        'status': 'archived',
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<Map<String, dynamic>> createOperation(
    String userId,
    FinancialOperationDraft draft,
  ) async {
    _validateOperation(draft.type, draft.amountMinor, draft.idempotencyKey);
    if (draft.type == OperationType.transfer) {
      throw ArgumentError('Use createTransfer for transfer operations.');
    }
    final operationRef = _userCollection(userId, 'operations').doc(draft.idempotencyKey);
    final entryRef = _userCollection(userId, 'ledgerEntries').doc();
    final nestedEntryRef = operationRef.collection('entries').doc(entryRef.id);
    final data = _operationData(
      type: draft.type,
      amountMinor: draft.amountMinor,
      currency: draft.currency,
      occurredAt: draft.occurredAt,
      monthKey: draft.monthKey,
      description: draft.description,
      idempotencyKey: draft.idempotencyKey,
      categoryId: draft.categoryId,
      accountId: draft.accountId,
    );
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(operationRef);
      if (existing.exists) return;
      final account = await transaction.get(
        _userCollection(userId, 'accounts').doc(draft.accountId),
      );
      if (!account.exists || account.data()?['currency'] != draft.currency) {
        throw StateError('The account does not exist or uses another currency.');
      }
      transaction
        ..set(operationRef, data)
        ..set(nestedEntryRef, {
          'operationId': operationRef.id,
          'accountId': draft.accountId,
          'deltaMinor': draft.type == OperationType.income ? draft.amountMinor : -draft.amountMinor,
          'currency': draft.currency,
          'occurredAt': Timestamp.fromDate(draft.occurredAt),
        })
        ..set(entryRef, {
          'operationId': operationRef.id,
          'accountId': draft.accountId,
          'deltaMinor': draft.type == OperationType.income ? draft.amountMinor : -draft.amountMinor,
          'currency': draft.currency,
          'occurredAt': Timestamp.fromDate(draft.occurredAt),
        });
    });
    return {...data, 'id': operationRef.id};
  }

  @override
  Future<Map<String, dynamic>> createTransfer(String userId, TransferDraft draft) async {
    _validateOperation(OperationType.transfer, draft.amountMinor, draft.idempotencyKey);
    if (draft.sourceAccountId == draft.destinationAccountId) {
      throw ArgumentError('Transfer accounts must be different.');
    }
    final operationRef = _userCollection(userId, 'operations').doc(draft.idempotencyKey);
    final sourceEntryRef = _userCollection(userId, 'ledgerEntries').doc();
    final destinationEntryRef = _userCollection(userId, 'ledgerEntries').doc();
    final sourceNestedEntryRef = operationRef.collection('entries').doc(sourceEntryRef.id);
    final destinationNestedEntryRef = operationRef
        .collection('entries')
        .doc(destinationEntryRef.id);
    final data = _operationData(
      type: OperationType.transfer,
      amountMinor: draft.amountMinor,
      currency: draft.currency,
      occurredAt: draft.occurredAt,
      description: draft.description,
      idempotencyKey: draft.idempotencyKey,
      sourceAccountId: draft.sourceAccountId,
      destinationAccountId: draft.destinationAccountId,
      monthKey: draft.monthKey,
    );
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(operationRef);
      if (existing.exists) return;
      final source = await transaction.get(
        _userCollection(userId, 'accounts').doc(draft.sourceAccountId),
      );
      final destination = await transaction.get(
        _userCollection(userId, 'accounts').doc(draft.destinationAccountId),
      );
      if (!source.exists ||
          !destination.exists ||
          source.data()?['currency'] != draft.currency ||
          destination.data()?['currency'] != draft.currency) {
        throw StateError('Transfer accounts must exist and use the same currency.');
      }
      transaction
        ..set(operationRef, data)
        ..set(sourceNestedEntryRef, {
          'operationId': operationRef.id,
          'accountId': draft.sourceAccountId,
          'deltaMinor': -draft.amountMinor,
          'currency': draft.currency,
          'occurredAt': Timestamp.fromDate(draft.occurredAt),
        })
        ..set(sourceEntryRef, {
          'operationId': operationRef.id,
          'accountId': draft.sourceAccountId,
          'deltaMinor': -draft.amountMinor,
          'currency': draft.currency,
          'occurredAt': Timestamp.fromDate(draft.occurredAt),
        })
        ..set(destinationNestedEntryRef, {
          'operationId': operationRef.id,
          'accountId': draft.destinationAccountId,
          'deltaMinor': draft.amountMinor,
          'currency': draft.currency,
          'occurredAt': Timestamp.fromDate(draft.occurredAt),
        })
        ..set(destinationEntryRef, {
          'operationId': operationRef.id,
          'accountId': draft.destinationAccountId,
          'deltaMinor': draft.amountMinor,
          'currency': draft.currency,
          'occurredAt': Timestamp.fromDate(draft.occurredAt),
        });
    });
    return {...data, 'id': operationRef.id};
  }

  @override
  Future<void> updateOperation(String userId, FinancialOperation operation) =>
      _userCollection(userId, 'operations').doc(operation.id).update({
        'description': operation.description.trim(),
        'status': operation.status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deleteOperation(String userId, String operationId) =>
      _userCollection(userId, 'operations').doc(operationId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Stream<List<Map<String, dynamic>>> watchBudgets(String userId, String monthKey) =>
      _userCollection(
            userId,
            'budgets',
          )
          .where('monthKey', isEqualTo: monthKey)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .map(_records);

  @override
  Stream<List<Map<String, dynamic>>> watchBudgetItems(String userId, String budgetId) =>
      _userCollection(
        userId,
        'budgets',
      ).doc(budgetId).collection('items').snapshots().map(_records);

  @override
  Future<Map<String, dynamic>> addBudgetItem(
    String userId,
    String budgetId,
    CanonicalBudgetItemDraft item,
  ) async {
    _validateBudgetItem(item);
    final budgetRef = _userCollection(userId, 'budgets').doc(budgetId);
    final itemRef = budgetRef.collection('items').doc();
    await _firestore.runTransaction((transaction) async {
      final budget = await transaction.get(budgetRef);
      if (!budget.exists) throw StateError('Budget not found.');
      final total = (budget.data()?['plannedAmountMinor'] as num? ?? 0).toInt();
      transaction
        ..set(itemRef, {
          'description': item.description.trim(),
          'amountMinor': item.amountMinor,
          'dayOfMonth': item.dayOfMonth,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        ..update(budgetRef, {
          'plannedAmountMinor': total + item.amountMinor,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    });
    return {
      'id': itemRef.id,
      'description': item.description.trim(),
      'amountMinor': item.amountMinor,
      'dayOfMonth': item.dayOfMonth,
    };
  }

  @override
  Future<void> updateBudgetItem(String userId, String budgetId, BudgetItem item) async {
    _validateBudgetItem(
      CanonicalBudgetItemDraft(
        description: item.description,
        amountMinor: item.amountMinor,
        dayOfMonth: item.dayOfMonth,
      ),
    );
    final budgetRef = _userCollection(userId, 'budgets').doc(budgetId);
    final itemRef = budgetRef.collection('items').doc(item.id);
    await _firestore.runTransaction((transaction) async {
      final budget = await transaction.get(budgetRef);
      final previous = await transaction.get(itemRef);
      if (!budget.exists || !previous.exists) throw StateError('Budget item not found.');
      final total = (budget.data()?['plannedAmountMinor'] as num? ?? 0).toInt();
      final oldAmount = (previous.data()?['amountMinor'] as num? ?? 0).toInt();
      transaction
        ..update(itemRef, {
          'description': item.description.trim(),
          'amountMinor': item.amountMinor,
          'dayOfMonth': item.dayOfMonth,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        ..update(budgetRef, {
          'plannedAmountMinor': total - oldAmount + item.amountMinor,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    });
  }

  @override
  Future<void> deleteBudgetItem(String userId, String budgetId, String itemId) async {
    final budgetRef = _userCollection(userId, 'budgets').doc(budgetId);
    final itemRef = budgetRef.collection('items').doc(itemId);
    await _firestore.runTransaction((transaction) async {
      final budget = await transaction.get(budgetRef);
      final item = await transaction.get(itemRef);
      if (!budget.exists || !item.exists) return;
      final total = (budget.data()?['plannedAmountMinor'] as num? ?? 0).toInt();
      final amount = (item.data()?['amountMinor'] as num? ?? 0).toInt();
      transaction
        ..delete(itemRef)
        ..update(budgetRef, {
          'plannedAmountMinor': (total - amount).clamp(0, 1 << 63),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    });
  }

  @override
  Future<void> archiveBudget(String userId, String budgetId) =>
      _userCollection(userId, 'budgets').doc(budgetId).update({
        'status': 'archived',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<Map<String, dynamic>> createBudgetWithItems(
    String userId, {
    required String categoryId,
    required String flowType,
    required String monthKey,
    required String currency,
    required List<CanonicalBudgetItemDraft> items,
  }) async {
    if (items.isEmpty) throw ArgumentError('A budget requires at least one item.');
    if (flowType != 'income' && flowType != 'expense') {
      throw ArgumentError('Invalid budget flow type.');
    }
    final budgetId = '${monthKey}_${flowType}_${categoryId}_$currency';
    final budgetRef = _userCollection(userId, 'budgets').doc(budgetId);
    final total = items.fold<int>(0, (totalSoFar, item) {
      _validateBudgetItem(item);
      return totalSoFar + item.amountMinor;
    });
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(budgetRef);
      if (existing.exists) throw StateError('A budget already exists for this category and month.');
      transaction.set(budgetRef, {
        'categoryId': categoryId,
        'flowType': flowType,
        'monthKey': monthKey,
        'currency': currency,
        'plannedAmountMinor': total,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final item in items) {
        final itemRef = budgetRef.collection('items').doc();
        transaction.set(itemRef, {
          'description': item.description.trim(),
          'amountMinor': item.amountMinor,
          'dayOfMonth': item.dayOfMonth,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    return {
      'id': budgetId,
      'categoryId': categoryId,
      'flowType': flowType,
      'monthKey': monthKey,
      'currency': currency,
      'plannedAmountMinor': total,
      'status': 'active',
      'items': items,
    };
  }

  @override
  Stream<Map<String, dynamic>?> watchMonthlySummary(
    String userId,
    String monthKey,
    String currency,
  ) => _userCollection(userId, 'monthlySummaries')
      .doc('${monthKey}_$currency')
      .snapshots()
      .map(
        (snapshot) => snapshot.exists ? {...snapshot.data()!, 'id': snapshot.id} : null,
      );

  List<Map<String, dynamic>> _records(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs.map((document) => {...document.data(), 'id': document.id}).toList();

  Map<String, dynamic> _operationData({
    required OperationType type,
    required int amountMinor,
    required String currency,
    required DateTime occurredAt,
    String? monthKey,
    required String description,
    required String idempotencyKey,
    String? categoryId,
    String? accountId,
    String? sourceAccountId,
    String? destinationAccountId,
  }) => {
    'type': type.name,
    'amountMinor': amountMinor,
    'currency': currency,
    'categoryId': ?categoryId,
    'accountId': ?accountId,
    'sourceAccountId': ?sourceAccountId,
    'destinationAccountId': ?destinationAccountId,
    'monthKey': monthKey ?? _monthKey(occurredAt),
    'occurredAt': Timestamp.fromDate(occurredAt),
    'description': description.trim(),
    'status': 'confirmed',
    'idempotencyKey': idempotencyKey,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  void _validateOperation(OperationType type, int amountMinor, String idempotencyKey) {
    if (amountMinor <= 0 || !RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(idempotencyKey)) {
      throw ArgumentError('Invalid amount or idempotency key.');
    }
    if (type != OperationType.transfer &&
        type != OperationType.income &&
        type != OperationType.expense) {
      throw ArgumentError('Invalid operation type.');
    }
  }

  bool _validCurrency(String currency) => RegExp(r'^[A-Z]{3}$').hasMatch(currency);

  void _validateBudgetItem(CanonicalBudgetItemDraft item) {
    if (item.description.trim().isEmpty ||
        item.amountMinor <= 0 ||
        item.dayOfMonth < 1 ||
        item.dayOfMonth > 31) {
      throw ArgumentError('Budget items require a description, positive amount and day 1-31.');
    }
  }

  String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
}
