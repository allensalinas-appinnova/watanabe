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
import 'operation_correction_service.dart';

// Each category write evaluates the user profile and its global catalog entry
// in Firestore Rules. Keep batches well below the 20-call atomic-write limit.
const _categoryWriteBatchSize = 8;

Iterable<List<T>> _chunked<T>(List<T> values, int size) sync* {
  for (var start = 0; start < values.length; start += size) {
    final end = (start + size < values.length) ? start + size : values.length;
    yield values.sublist(start, end);
  }
}

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

  Future<void> syncDefaultCategories(
    String userId, {
    required String locale,
    required String countryCode,
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
    String? accountId,
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
    bool debtPaymentsOnly = false,
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

  Future<void> updateOperation(
    String userId,
    FinancialOperation operation, {
    required String requestId,
  });

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
    FirebaseOperationCorrectionService? operationCorrections,
  }) : _firestore = firestore,
       _budgetCommands = budgetCommands,
       _balanceAdjustments = balanceAdjustments,
       _operationCorrections = operationCorrections;

  final FirebaseFirestore _firestore;
  final BudgetCommandService _budgetCommands;
  final BalanceAdjustmentService? _balanceAdjustments;
  final FirebaseOperationCorrectionService? _operationCorrections;

  CollectionReference<Map<String, dynamic>> _userCollection(String userId, String name) =>
      _firestore.collection('users').doc(userId).collection(name);

  DocumentReference<Map<String, dynamic>> _userDocument(String userId) =>
      _firestore.collection('users').doc(userId);

  Future<int> _currentGeneration(String userId) async {
    final profile = await _userDocument(userId).get();
    final data = profile.data();
    if (data?['resetStatus'] == 'resetting') throw StateError('user-reset-in-progress');
    return (data?['dataGeneration'] as num? ?? 0).toInt();
  }

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
    final generation = await _currentGeneration(userId);
    final profile = _userDocument(userId);
    final initialProfile = await profile.get();
    if (!initialProfile.exists) {
      await profile.set({
        'locale': locale,
        'countryCode': countryCode,
        'timeZone': timeZone,
        'defaultCurrency': defaultCurrency,
        'onboardingStatus': 'in_progress',
        'categoryCatalogVersion': currentCategoryCatalogVersion,
        'dataGeneration': generation,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final catalog = await _firestore
        .collection('categoryCatalog')
        .where('isActive', isEqualTo: true)
        .where('supportedCountries', arrayContains: countryCode)
        .get();
    final existing = await _userCollection(userId, 'categories').get();
    final existingIds = existing.docs.map((doc) => doc.id).toSet();
    final categoryWrites = <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];
    for (final document in catalog.docs) {
      if (existingIds.contains(document.id)) continue;
      final data = document.data();
      final labels = Map<String, dynamic>.from(data['labels'] as Map? ?? const {});
      final localizedName = labels[locale.split('-').first] as String? ?? labels['en'] as String?;
      categoryWrites.add((
        _userCollection(userId, 'categories').doc(document.id),
        {
          'catalogId': document.id,
          'type': data['type'],
          'name': localizedName ?? data['translationKey'],
          'icon': data['icon'],
          'sortOrder': data['sortOrder'] ?? 0,
          'isSystem': true,
          'isArchived': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'dataGeneration': generation,
        },
      ));
    }
    for (final chunk in _chunked(categoryWrites, _categoryWriteBatchSize)) {
      final categoryBatch = _firestore.batch();
      for (final (reference, data) in chunk) {
        categoryBatch.set(reference, data);
      }
      await categoryBatch.commit();
    }

    final profileData = {
      'locale': locale,
      'countryCode': countryCode,
      'timeZone': timeZone,
      'defaultCurrency': defaultCurrency,
      'onboardingStatus': 'complete',
      'categoryCatalogVersion': currentCategoryCatalogVersion,
      'updatedAt': FieldValue.serverTimestamp(),
      'dataGeneration': generation,
    };
    await profile.update(profileData);
  }

  @override
  Future<void> syncDefaultCategories(
    String userId, {
    required String locale,
    required String countryCode,
  }) async {
    const catalogVersion = currentCategoryCatalogVersion;
    final catalog = await _firestore
        .collection('categoryCatalog')
        .where('isActive', isEqualTo: true)
        .where('supportedCountries', arrayContains: countryCode)
        .get();
    final categories = _userCollection(userId, 'categories');
    final profile = _userDocument(userId);
    final documents = catalog.docs;

    // A single transaction for the full catalog can exceed Firestore Rules'
    // access-call budget. Commit bounded, idempotent chunks and advance the
    // catalog version only after every chunk has succeeded.
    for (final chunk in _chunked(documents, _categoryWriteBatchSize)) {
      await _firestore.runTransaction((transaction) async {
        final profileSnapshot = await transaction.get(profile);
        final profileData = profileSnapshot.data();
        if (!profileSnapshot.exists) throw StateError('user-profile-missing');
        if (profileData?['resetStatus'] == 'resetting') {
          throw StateError('user-reset-in-progress');
        }
        final generation = (profileData?['dataGeneration'] as num? ?? 0).toInt();
        final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final document in chunk) {
          snapshots.add(await transaction.get(categories.doc(document.id)));
        }
        for (var index = 0; index < chunk.length; index++) {
          if (snapshots[index].exists) continue;
          final data = chunk[index].data();
          final labels = Map<String, dynamic>.from(data['labels'] as Map? ?? const {});
          final name = labels[locale.split('-').first] as String? ?? labels['en'] as String?;
          transaction.set(categories.doc(chunk[index].id), {
            'catalogId': chunk[index].id,
            'type': data['type'],
            'name': name ?? data['translationKey'],
            'icon': data['icon'],
            'sortOrder': data['sortOrder'] ?? 0,
            'isSystem': true,
            'isArchived': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'dataGeneration': generation,
          });
        }
      });
    }

    await _firestore.runTransaction((transaction) async {
      final profileSnapshot = await transaction.get(profile);
      final profileData = profileSnapshot.data();
      if (!profileSnapshot.exists) throw StateError('user-profile-missing');
      if (profileData?['resetStatus'] == 'resetting') {
        throw StateError('user-reset-in-progress');
      }
      final currentVersion = (profileData?['categoryCatalogVersion'] as num? ?? 1).toInt();
      if (currentVersion < catalogVersion) {
        transaction.update(profile, {
          'categoryCatalogVersion': catalogVersion,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
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
    bool debtPaymentsOnly = false,
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
    if (!debtPaymentsOnly && type != null && type != OperationType.expense) {
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
    // Scan to fill expense and debt-payment pages, including linked rows. A
    // type OR combined with ten selected accounts would exceed Firestore's
    // 30-disjunction limit.
    // The cursor always advances over scanned rows, never filtered positions.
    for (;;) {
      final remaining = pageSize - records.length;
      final snapshot = await query.limit(remaining).get();
      records.addAll(
        _records(snapshot).where(
          (record) => (debtPaymentsOnly
              ? _isDebtPaymentRecord(record)
              : type != OperationType.expense ||
                    ['expense', 'expenseRefund'].contains(record['type'])),
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
    final paymentId = records.lastOrNull?['paymentId'];
    if ((paymentId is String || commandId is String) && nextCursor != null) {
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
        if (paymentId is String
            ? doc.data()['paymentId'] != paymentId
            : doc.data()['debtCommandId'] != commandId) {
          break;
        }
        final occurredAt = doc.data()['occurredAt'];
        if (occurredAt is! Timestamp) break;
        final data = doc.data();
        if (debtPaymentsOnly
            ? _isDebtPaymentRecord(data)
            : type != OperationType.expense ||
                  ['expense', 'expenseRefund'].contains(data['type'])) {
          records.add({...data, 'id': doc.id});
        }
        nextCursor = OperationPageCursor(occurredAt: occurredAt.toDate(), operationId: doc.id);
      }
    }
    return RemoteOperationPage(records: records, nextCursor: nextCursor);
  }

  bool _isDebtPaymentRecord(Map<String, dynamic> record) =>
      (record['debtCommandId'] is String &&
          const {'pay', 'newChargePaid'}.contains(record['debtKind'])) ||
      record['type'] == 'unallocatedDebtPayment';

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
    final generation = await _currentGeneration(userId);
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
      'dataGeneration': generation,
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
    String? accountId,
    required String name,
    required String type,
    required String currency,
    required int openingBalanceMinor,
  }) async {
    final generation = await _currentGeneration(userId);
    if (name.trim().isEmpty ||
        openingBalanceMinor < 0 ||
        openingBalanceMinor > MoneyParser.maxMinorUnits(currency) ||
        !_validCurrency(currency)) {
      throw ArgumentError('Invalid account data.');
    }
    final ref = _userCollection(userId, 'accounts').doc(accountId);
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
      'dataGeneration': generation,
    };
    if (accountId == null) {
      await ref.set(data);
      return {...data, 'id': ref.id};
    }
    return _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) return {...existing.data()!, 'id': ref.id};
      transaction.set(ref, data);
      return {...data, 'id': ref.id};
    });
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
      _operationCorrections?.archiveAccount(userId, accountId) ??
      Future.error(StateError('operation-command-service-not-configured'));

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
    return service.adjust(
      userId: userId,
      requestId: requestId,
      adjustments: adjustments,
      reason: reason,
    );
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
    final monthKey = draft.monthKey ?? _monthKey(draft.occurredAt);
    final data = _operationData(
      type: draft.type,
      amountMinor: draft.amountMinor,
      currency: draft.currency,
      occurredAt: draft.occurredAt,
      monthKey: monthKey,
      description: draft.description,
      idempotencyKey: draft.idempotencyKey,
      categoryId: draft.categoryId,
      accountId: draft.accountId,
      budgetId: draft.budgetId,
      budgetItemId: draft.budgetItemId,
      dataGeneration: draft.dataGeneration ?? 0,
    );
    final service = _operationCorrections;
    if (service == null) throw StateError('operation-command-service-not-configured');
    await service.create(userId, {
      'type': draft.type.name,
      'amountMinor': draft.amountMinor,
      'currency': draft.currency,
      'accountId': draft.accountId,
      'categoryId': draft.categoryId,
      'occurredAt': draft.occurredAt.toUtc().toIso8601String(),
      'monthKey': monthKey,
      'description': draft.description,
      'idempotencyKey': draft.idempotencyKey,
      'budgetId': draft.budgetId,
      'budgetItemId': draft.budgetItemId,
      'dataGeneration': draft.dataGeneration,
    });
    return {...data, 'id': draft.idempotencyKey, 'status': 'confirmed', 'revision': 0};
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
    final monthKey = draft.monthKey ?? _monthKey(draft.occurredAt);
    final data = _operationData(
      type: OperationType.transfer,
      amountMinor: draft.amountMinor,
      currency: draft.currency,
      occurredAt: draft.occurredAt,
      description: draft.description,
      idempotencyKey: draft.idempotencyKey,
      sourceAccountId: draft.sourceAccountId,
      destinationAccountId: draft.destinationAccountId,
      monthKey: monthKey,
      dataGeneration: draft.dataGeneration ?? 0,
    );
    final service = _operationCorrections;
    if (service == null) throw StateError('operation-command-service-not-configured');
    await service.create(userId, {
      'type': OperationType.transfer.name,
      'amountMinor': draft.amountMinor,
      'currency': draft.currency,
      'sourceAccountId': draft.sourceAccountId,
      'destinationAccountId': draft.destinationAccountId,
      'occurredAt': draft.occurredAt.toUtc().toIso8601String(),
      'monthKey': monthKey,
      'description': draft.description,
      'idempotencyKey': draft.idempotencyKey,
      'dataGeneration': draft.dataGeneration,
    });
    return {...data, 'id': draft.idempotencyKey, 'status': 'confirmed', 'revision': 0};
  }

  @override
  Future<void> updateOperation(
    String userId,
    FinancialOperation operation, {
    required String requestId,
  }) {
    final service = _operationCorrections;
    if (service == null) throw StateError('operation-correction-service-not-configured');
    return service.execute(userId, {
      'requestId': requestId,
      'expectedRevision': operation.revision,
      'operationId': operation.id,
      'amountMinor': operation.amountMinor,
      'currency': operation.currency,
      'accountId': operation.accountId,
      'categoryId': operation.categoryId,
      'monthKey': operation.monthKey,
      'occurredAt': operation.occurredAt.toUtc().toIso8601String(),
      'description': operation.description,
    });
  }

  @override
  Future<void> deleteOperation(String userId, String operationId) {
    final service = _operationCorrections;
    if (service == null) {
      return Future.error(StateError('operation-command-service-not-configured'));
    }
    return service.cancel(userId, operationId);
  }

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
    int dataGeneration = 0,
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
    // This map is returned to the caller after the callable commits. It is not
    // written to Firestore, so use concrete client values rather than server
    // timestamp sentinels that cannot be parsed into the domain model.
    'createdAt': Timestamp.fromDate(DateTime.now()),
    'updatedAt': Timestamp.fromDate(DateTime.now()),
    'dataGeneration': dataGeneration,
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
