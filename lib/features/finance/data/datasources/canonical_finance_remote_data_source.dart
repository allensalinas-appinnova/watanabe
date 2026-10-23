import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/money_parser.dart';
import '../../../../core/utils/request_id.dart';
import '../../domain/entities/appearance_preferences.dart';
import '../../domain/entities/balance_adjustment.dart';
import '../../domain/entities/budget_item.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/home_dashboard_preferences.dart';
import '../../domain/entities/operation_page.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import 'balance_adjustment_service.dart';
import 'budget_command_service.dart';

class RemoteOperationPage {
  const RemoteOperationPage({required this.records, this.nextCursor});

  final List<Map<String, dynamic>> records;
  final OperationPageCursor? nextCursor;
}

abstract interface class CanonicalFinanceRemoteDataSource {
  Stream<Map<String, dynamic>?> watchUserProfile(String userId);

  Future<void> updateHomeDashboardPreferences(
    String userId,
    HomeDashboardPreferences preferences,
  );

  Future<void> updateAppearancePreferences(String userId, AppearancePreferences preferences);

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
  Stream<Map<String, dynamic>?> watchAccount(String userId, String accountId);

  Future<Map<String, dynamic>> createAccount(
    String userId, {
    required String name,
    required String type,
    required String currency,
    required int openingBalanceMinor,
  });

  Future<void> updateAccount(String userId, FinanceAccount account);

  Future<void> archiveAccount(String userId, String accountId);

  Stream<List<Map<String, dynamic>>> watchBalanceAdjustments(String userId);

  Future<Map<String, Object?>> adjustAccountBalances({
    required String userId,
    required String requestId,
    required List<BalanceAdjustmentDraft> adjustments,
    String? reason,
  });

  Stream<List<Map<String, dynamic>>> watchOperations(String userId);

  Future<RemoteOperationPage> fetchOperationsPage(
    String userId, {
    OperationPageCursor? cursor,
    String? monthKey,
    String? currency,
    OperationType? type,
    String? accountId,
    List<String>? accountIds,
    DateTime? startAt,
    DateTime? endAtExclusive,
    int pageSize = 100,
  });

  Stream<List<Map<String, dynamic>>> watchLedgerEntries(String userId, String accountId);

  Future<Map<String, dynamic>> createOperation(
    String userId,
    FinancialOperationDraft draft,
  );

  Future<Map<String, dynamic>> createTransfer(String userId, TransferDraft draft);

  Future<void> updateOperation(String userId, FinancialOperation operation);

  Future<void> deleteOperation(String userId, String operationId);

  Stream<List<Map<String, dynamic>>> watchBudgets(String userId, String monthKey);

  Stream<Map<String, dynamic>?> watchBudget(String userId, String budgetId);

  Future<Map<String, dynamic>> createBudgetWithItems(
    String userId, {
    required String categoryId,
    required String flowType,
    required String monthKey,
    required String currency,
    required List<CanonicalBudgetItemDraft> items,
    String? requestId,
  });

  Stream<Map<String, dynamic>?> watchMonthlySummary(
    String userId,
    String monthKey,
    String currency,
  );

  Stream<List<Map<String, dynamic>>> watchBudgetItems(String userId, String budgetId);

  Stream<List<Map<String, dynamic>>> watchBudgetItemOperations(
    String userId,
    String budgetId,
    String itemId,
  );

  Future<Map<String, dynamic>> addBudgetItem(
    String userId,
    String budgetId,
    CanonicalBudgetItemDraft item, {
    String? requestId,
  });

  Future<void> updateBudgetItem(
    String userId,
    String budgetId,
    BudgetItem item, {
    String? requestId,
  });

  Future<void> deleteBudgetItem(String userId, String budgetId, String itemId, {String? requestId});

  Future<void> archiveBudget(String userId, String budgetId, {String? requestId});
}

class FirestoreCanonicalFinanceRemoteDataSource implements CanonicalFinanceRemoteDataSource {
  const FirestoreCanonicalFinanceRemoteDataSource({
    required FirebaseFirestore firestore,
    required BudgetCommandService budgetCommands,
    BalanceAdjustmentService? balanceAdjustments,
  }) : _firestore = firestore,
       _budgetCommands = budgetCommands,
       _balanceAdjustments = balanceAdjustments;

  final FirebaseFirestore _firestore;
  final BudgetCommandService _budgetCommands;
  final BalanceAdjustmentService? _balanceAdjustments;

  CollectionReference<Map<String, dynamic>> _userCollection(String userId, String name) =>
      _firestore.collection('users').doc(userId).collection(name);

  DocumentReference<Map<String, dynamic>> _userDocument(String userId) =>
      _firestore.collection('users').doc(userId);

  @override
  Stream<Map<String, dynamic>?> watchUserProfile(String userId) =>
      _userDocument(userId).snapshots().map((snapshot) => snapshot.exists ? snapshot.data() : null);

  @override
  Future<void> updateHomeDashboardPreferences(
    String userId,
    HomeDashboardPreferences preferences,
  ) => _userDocument(userId).update({
    'homePreferences': preferences.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> updateAppearancePreferences(String userId, AppearancePreferences preferences) =>
      _userDocument(userId).update({
        'appearancePreferences': preferences.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
    final categoryBatch = _firestore.batch();
    for (final document in catalog.docs) {
      if (existingIds.contains(document.id)) continue;
      final data = document.data();
      final labels = Map<String, dynamic>.from(data['labels'] as Map? ?? const {});
      final localizedName = labels[locale.split('-').first] as String? ?? labels['en'] as String?;
      categoryBatch.set(_userCollection(userId, 'categories').doc(document.id), {
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
    if (catalog.docs.any((document) => !existingIds.contains(document.id))) {
      await categoryBatch.commit();
    }

    final profile = _userDocument(userId);
    final profileData = {
      'locale': locale,
      'countryCode': countryCode,
      'timeZone': timeZone,
      'defaultCurrency': defaultCurrency,
      'onboardingStatus': 'complete',
      'categoryCatalogVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if ((await profile.get()).exists) {
      await profile.update(profileData);
    } else {
      await profile.set({
        ...profileData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
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
  ).orderBy('occurredAt', descending: true).limit(100).snapshots().map(_records);

  @override
  Future<RemoteOperationPage> fetchOperationsPage(
    String userId, {
    OperationPageCursor? cursor,
    String? monthKey,
    String? currency,
    OperationType? type,
    String? accountId,
    List<String>? accountIds,
    DateTime? startAt,
    DateTime? endAtExclusive,
    int pageSize = 100,
  }) async {
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError.value(pageSize, 'pageSize', 'must be between 1 and 100');
    }
    Query<Map<String, dynamic>> query = _userCollection(userId, 'operations');
    if (monthKey != null) query = query.where('monthKey', isEqualTo: monthKey);
    if (currency != null) query = query.where('currency', isEqualTo: currency);
    if (type != null && type != OperationType.expense) {
      query = query.where('type', isEqualTo: type.name);
    }
    final selectedAccountIds = {
      ?accountId,
      ...?accountIds,
    }.toList(growable: false);
    if (selectedAccountIds.length > 10) {
      throw ArgumentError.value(
        selectedAccountIds.length,
        'accountIds',
        'Firestore account filtering supports up to 10 selected accounts.',
      );
    }
    if (selectedAccountIds.isNotEmpty) {
      final accountFilters = [
        for (final selectedId in selectedAccountIds) ...[
          Filter('accountId', isEqualTo: selectedId),
          Filter('sourceAccountId', isEqualTo: selectedId),
          Filter('destinationAccountId', isEqualTo: selectedId),
        ],
      ];
      final accountFilter = accountFilters.reduce(Filter.or);
      query = query.where(accountFilter);
    }
    if (startAt != null) {
      query = query.where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startAt));
    }
    if (endAtExclusive != null) {
      query = query.where('occurredAt', isLessThan: Timestamp.fromDate(endAtExclusive));
    }
    query = query
        .orderBy('occurredAt', descending: true)
        // Keep the document key direction aligned with the implicit __name__
        // direction in Firestore's occurredAt DESCENDING index. Without this,
        // the default ascending key order requires an undeclared composite
        // index and makes even unfiltered activity queries fail precondition.
        .orderBy(FieldPath.documentId, descending: true)
        .limit(pageSize);
    if (cursor != null) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.occurredAt),
        cursor.operationId,
      ]);
    }
    final records = <Map<String, dynamic>>[];
    OperationPageCursor? nextCursor;
    // Scan to fill an expense page, including refunds. A type OR combined with
    // ten selected accounts would exceed Firestore's 30-disjunction limit.
    // The cursor always advances over scanned rows, never filtered positions.
    for (;;) {
      final remaining = pageSize - records.length;
      final snapshot = await query.limit(remaining).get();
      records.addAll(
        _records(snapshot).where(
          (record) =>
              type != OperationType.expense ||
              ['expense', 'expenseRefund'].contains(record['type']),
        ),
      );
      final last = snapshot.docs.isEmpty ? null : snapshot.docs.last;
      final occurredAt = last?.data()['occurredAt'];
      if (last == null || occurredAt is! Timestamp || snapshot.size < remaining) {
        nextCursor = null;
        break;
      }
      nextCursor = OperationPageCursor(occurredAt: occurredAt.toDate(), operationId: last.id);
      if (records.length == pageSize) break;
      query = query.startAfter([occurredAt, last.id]);
    }
    // Keep the adjacent components of a payment together at a page boundary.
    // Receipts cap a command at four source rows (reversal + replacement).
    final commandId = records.lastOrNull?['debtCommandId'];
    if (commandId is String && nextCursor != null) {
      for (var tail = 0; tail < 4 && nextCursor != null; tail++) {
        final cursor = nextCursor;
        final extra = await query
            .startAfter([Timestamp.fromDate(cursor.occurredAt), cursor.operationId])
            .limit(1)
            .get();
        if (extra.docs.isEmpty) {
          nextCursor = null;
          break;
        }
        final doc = extra.docs.single;
        if (doc.data()['debtCommandId'] != commandId) break;
        final occurredAt = doc.data()['occurredAt'];
        if (occurredAt is! Timestamp) break;
        if (type != OperationType.expense ||
            ['expense', 'expenseRefund'].contains(doc.data()['type'])) {
          records.add({...doc.data(), 'id': doc.id});
        }
        nextCursor = OperationPageCursor(occurredAt: occurredAt.toDate(), operationId: doc.id);
      }
    }
    return RemoteOperationPage(records: records, nextCursor: nextCursor);
  }

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
        'colorValue': category.colorValue ?? FieldValue.delete(),
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
  Stream<Map<String, dynamic>?> watchAccount(String userId, String accountId) =>
      _userCollection(userId, 'accounts')
          .doc(accountId)
          .snapshots()
          .map((snapshot) => snapshot.exists ? {...snapshot.data()!, 'id': snapshot.id} : null);

  @override
  Stream<List<Map<String, dynamic>>> watchBalanceAdjustments(String userId) => _userCollection(
    userId,
    'balanceAdjustments',
  ).orderBy('adjustedAt', descending: true).snapshots().map(_records);

  @override
  Future<Map<String, dynamic>> createAccount(
    String userId, {
    required String name,
    required String type,
    required String currency,
    required int openingBalanceMinor,
  }) async {
    if (name.trim().isEmpty ||
        openingBalanceMinor < 0 ||
        openingBalanceMinor > MoneyParser.maxMinorUnits(currency) ||
        !_validCurrency(currency)) {
      throw ArgumentError('Invalid account data.');
    }
    final ref = _userCollection(userId, 'accounts').doc();
    final data = {
      'name': name.trim(),
      'type': type,
      'nature': 'money',
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
  Future<Map<String, Object?>> adjustAccountBalances({
    required String userId,
    required String requestId,
    required List<BalanceAdjustmentDraft> adjustments,
    String? reason,
  }) {
    final service = _balanceAdjustments;
    if (service == null) {
      return Future.error(StateError('Balance adjustment service is unavailable'));
    }
    return service.adjust(requestId: requestId, adjustments: adjustments, reason: reason);
  }

  @override
  Future<Map<String, dynamic>> createOperation(
    String userId,
    FinancialOperationDraft draft,
  ) async {
    _validateOperation(draft.type, draft.amountMinor, draft.currency, draft.idempotencyKey);
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
      budgetId: draft.budgetId,
      budgetItemId: draft.budgetItemId,
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
      if (account.data()?['nature'] == 'debt') throw StateError('debt-command-required');
      if (draft.budgetId != null || draft.budgetItemId != null) {
        if (draft.budgetId == null ||
            draft.budgetItemId == null ||
            draft.type == OperationType.transfer ||
            draft.categoryId == null) {
          throw ArgumentError('Budget operation references must be supplied as a compatible pair.');
        }
        final budgetRef = _userCollection(userId, 'budgets').doc(draft.budgetId);
        final itemRef = budgetRef.collection('items').doc(draft.budgetItemId);
        final budget = await transaction.get(budgetRef);
        final item = await transaction.get(itemRef);
        final budgetData = budget.data();
        if (!budget.exists ||
            !item.exists ||
            budgetData == null ||
            budgetData['categoryId'] != draft.categoryId ||
            budgetData['flowType'] != draft.type.name ||
            budgetData['currency'] != draft.currency) {
          throw StateError('Budget item reference is missing or incompatible.');
        }
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
    _validateOperation(
      OperationType.transfer,
      draft.amountMinor,
      draft.currency,
      draft.idempotencyKey,
    );
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
      if (source.data()?['nature'] == 'debt' || destination.data()?['nature'] == 'debt') {
        throw StateError('debt-command-required');
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
  Stream<Map<String, dynamic>?> watchBudget(String userId, String budgetId) =>
      _userCollection(userId, 'budgets')
          .doc(budgetId)
          .snapshots()
          .map(
            (snapshot) => snapshot.exists ? {...snapshot.data()!, 'id': snapshot.id} : null,
          );

  @override
  Stream<List<Map<String, dynamic>>> watchBudgetItems(String userId, String budgetId) =>
      _userCollection(
        userId,
        'budgets',
      ).doc(budgetId).collection('items').snapshots().map(_records);

  @override
  Stream<List<Map<String, dynamic>>> watchBudgetItemOperations(
    String userId,
    String budgetId,
    String itemId,
  ) => _userCollection(userId, 'operations')
      .where('budgetId', isEqualTo: budgetId)
      .snapshots()
      .map(_records)
      .map((records) => records.where((record) => record['budgetItemId'] == itemId).toList());

  Map<String, dynamic> _itemPayload(CanonicalBudgetItemDraft item) => {
    'description': item.description.trim(),
    'amountMinor': item.amountMinor,
    'dayOfMonth': item.dayOfMonth,
  };

  Future<Map<String, dynamic>> _budgetCommand(
    String userId,
    String action,
    Map<String, dynamic> payload,
    String? requestId,
  ) => _budgetCommands.execute(userId, {
    'action': action,
    'requestId': requestId ?? newRequestId(),
    ...payload,
  });

  @override
  Future<Map<String, dynamic>> addBudgetItem(
    String userId,
    String budgetId,
    CanonicalBudgetItemDraft item, {
    String? requestId,
  }) async {
    final result = await _budgetCommand(userId, 'addItem', {
      'budgetId': budgetId,
      'item': _itemPayload(item),
    }, requestId);
    return Map<String, dynamic>.from(result['item'] as Map);
  }

  @override
  Future<void> updateBudgetItem(
    String userId,
    String budgetId,
    BudgetItem item, {
    String? requestId,
  }) async {
    await _budgetCommand(userId, 'updateItem', {
      'budgetId': budgetId,
      'itemId': item.id,
      'item': _itemPayload(
        CanonicalBudgetItemDraft(
          description: item.description,
          amountMinor: item.amountMinor,
          dayOfMonth: item.dayOfMonth,
        ),
      ),
    }, requestId);
  }

  @override
  Future<void> deleteBudgetItem(
    String userId,
    String budgetId,
    String itemId, {
    String? requestId,
  }) async {
    await _budgetCommand(userId, 'archiveItem', {
      'budgetId': budgetId,
      'itemId': itemId,
    }, requestId);
  }

  @override
  Future<void> archiveBudget(String userId, String budgetId, {String? requestId}) async {
    await _budgetCommand(userId, 'archiveBudget', {'budgetId': budgetId}, requestId);
  }

  @override
  Future<Map<String, dynamic>> createBudgetWithItems(
    String userId, {
    required String categoryId,
    required String flowType,
    required String monthKey,
    required String currency,
    required List<CanonicalBudgetItemDraft> items,
    String? requestId,
  }) async {
    final result = await _budgetCommand(userId, 'create', {
      'categoryId': categoryId,
      'flowType': flowType,
      'monthKey': monthKey,
      'currency': currency,
      'items': items.map(_itemPayload).toList(),
    }, requestId);
    return Map<String, dynamic>.from(result['budget'] as Map);
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
    String? budgetId,
    String? budgetItemId,
  }) => {
    'type': type.name,
    'amountMinor': amountMinor,
    'currency': currency,
    'categoryId': ?categoryId,
    'accountId': ?accountId,
    'sourceAccountId': ?sourceAccountId,
    'destinationAccountId': ?destinationAccountId,
    'budgetId': ?budgetId,
    'budgetItemId': ?budgetItemId,
    'monthKey': monthKey ?? _monthKey(occurredAt),
    'occurredAt': Timestamp.fromDate(occurredAt),
    'description': description.trim(),
    'status': 'confirmed',
    'idempotencyKey': idempotencyKey,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  void _validateOperation(
    OperationType type,
    int amountMinor,
    String currency,
    String idempotencyKey,
  ) {
    if (amountMinor <= 0 ||
        amountMinor > MoneyParser.maxMinorUnits(currency) ||
        !RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(idempotencyKey)) {
      throw ArgumentError('Invalid amount or idempotency key.');
    }
    if (type != OperationType.transfer &&
        type != OperationType.income &&
        type != OperationType.expense) {
      throw ArgumentError('Invalid operation type.');
    }
  }

  bool _validCurrency(String currency) => RegExp(r'^[A-Z]{3}$').hasMatch(currency);

  String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
}
