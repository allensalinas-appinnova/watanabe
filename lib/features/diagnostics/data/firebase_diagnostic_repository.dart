import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import '../../commitments/domain/debt_commitment.dart';
import '../../finance/data/mappers/financial_operation_firestore_mapper.dart';
import '../../finance/domain/entities/finance_account.dart';
import '../../finance/domain/entities/ledger_entry.dart';
import '../../finance/domain/entities/planning_agenda_entry.dart';
import '../domain/diagnostic_engine.dart';
import '../domain/diagnostic_record.dart';
import '../domain/diagnostic_repository.dart';

class FirebaseDiagnosticRepository implements DiagnosticRepository {
  FirebaseDiagnosticRepository(this.firestore, this.functions, this.auth);
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final FirebaseAuth auth;

  @override
  Stream<DiagnosticSnapshot> watch(String uid, DateTime today, DateTime historyStartUtc) =>
      Stream.multi((controller) {
        final root = firestore.collection('users').doc(uid);
        final snapshots = <String, QuerySnapshot<Map<String, dynamic>>>{};
        final subscriptions = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
        const base = [
          'accounts',
          'operations',
          'ledgerEntries',
          'budgets',
          'debtCommitments',
          'debtPaymentLinks',
          'debtPayments',
          'diagnosticRecords',
        ];
        var cancelled = false;
        void emit() {
          if (cancelled ||
              base.any((k) => !snapshots.containsKey(k)) ||
              subscriptions.keys.any((k) => !snapshots.containsKey(k))) {
            return;
          }
          try {
            final accountDocs = snapshots['accounts']!.docs;
            final accounts = accountDocs.map((doc) {
              final d = doc.data();
              return FinanceAccount(
                id: doc.id,
                name: d['name'] as String,
                type: d['type'] as String? ?? 'cash',
                currency: d['currency'] as String,
                currentBalanceMinor: (d['currentBalanceMinor'] as num? ?? 0).toInt(),
                nature: d['nature'] as String? ?? 'money',
                status: d['status'] as String? ?? 'active',
                includeInDashboard: d['includeInDashboard'] as bool? ?? true,
                principalMinor: (d['principalMinor'] as num? ?? 0).toInt(),
                chargesMinor: (d['chargesMinor'] as num? ?? 0).toInt(),
                limitMinor: (d['limitMinor'] as num?)?.toInt(),
              );
            }).toList();
            final operations = snapshots['operations']!.docs
                .map(
                  (d) =>
                      FinancialOperationFirestoreMapper.fromMap(d.id, d.data(), requireDate: true),
                )
                .toList();
            final entries = snapshots['ledgerEntries']!.docs.map((doc) {
              final d = doc.data();
              return LedgerEntry(
                id: doc.id,
                operationId: d['operationId'] as String,
                accountId: d['accountId'] as String,
                deltaMinor: (d['deltaMinor'] as num).toInt(),
                currency: d['currency'] as String,
              );
            }).toList();
            final records = snapshots['diagnosticRecords']!.docs
                .map(
                  (d) => DiagnosticRecord(
                    d.id,
                    d.data()['kind'] as String,
                    Map<String, Object>.from(d.data()['values'] as Map),
                    paymentBaselineMinor: (d.data()['paymentBaselineMinor'] as num? ?? 0).toInt(),
                  ),
                )
                .toList();
            final referencedPlans = records
                .map((r) => r.text('entryId'))
                .where((id) => id.isNotEmpty)
                .toSet();
            final plan = <PlanningAgendaEntry>[];
            for (final doc in snapshots['budgets']!.docs) {
              final budget = doc.data();
              if (budget['status'] != 'active' &&
                  !referencedPlans.any((id) => id.startsWith('budget:${doc.id}:'))) {
                continue;
              }
              final key = budget['monthKey'] as String;
              final month = DateTime.parse('$key-01');
              final items = snapshots['items:${doc.id}'];
              if (items == null) return;
              for (final itemDoc in items.docs) {
                final item = itemDoc.data();
                final id = 'budget:${doc.id}:${itemDoc.id}';
                if (item['status'] == 'archived' && !referencedPlans.contains(id)) continue;
                final amount = (item['amountMinor'] as num).toInt();
                final actual = (item['actualAmountMinor'] as num? ?? 0).toInt();
                plan.add(
                  PlanningAgendaEntry(
                    id: 'budget:${doc.id}:${itemDoc.id}',
                    kind: budget['flowType'] == 'income'
                        ? PlanningEntryKind.income
                        : PlanningEntryKind.expense,
                    date: DateTime(
                      month.year,
                      month.month,
                      (item['dayOfMonth'] as int).clamp(
                        1,
                        DateTime(month.year, month.month + 1, 0).day,
                      ),
                    ),
                    title: item['description'] as String,
                    currency: budget['currency'] as String,
                    plannedMinor: amount,
                    recordedMinor: actual,
                    pendingMinor: item['status'] == 'archived' || budget['status'] != 'active'
                        ? 0
                        : (amount - actual).clamp(0, amount),
                    monthKey: key,
                    categoryId: budget['categoryId'] as String,
                    budgetId: doc.id,
                    itemId: itemDoc.id,
                  ),
                );
              }
            }
            final end = DateTime(today.year, today.month, today.day + 90);
            for (final doc in snapshots['debtCommitments']!.docs) {
              final d = doc.data();
              if (d['status'] != 'active' &&
                  !referencedPlans.any((id) => id.startsWith('debt:${doc.id}:'))) {
                continue;
              }
              final months = <String>{
                for (final id in referencedPlans.where((id) => id.startsWith('debt:${doc.id}:')))
                  id.split(':').last,
              };
              for (
                var month = DateTime(today.year, today.month);
                month.isBefore(end);
                month = DateTime(month.year, month.month + 1)
              ) {
                months.add(diagnosticMonth(month));
              }
              for (final key in months) {
                final versions =
                    (snapshots['versions:${doc.id}']?.docs
                              .map((v) => v.data())
                              .where((v) => (v['effectiveFromMonth'] as String).compareTo(key) <= 0)
                              .toList() ??
                          <Map<String, dynamic>>[])
                      ..sort((a, b) {
                        final byMonth = (a['effectiveFromMonth'] as String).compareTo(
                          b['effectiveFromMonth'] as String,
                        );
                        return byMonth != 0
                            ? byMonth
                            : (a['version'] as int).compareTo(b['version'] as int);
                      });
                final effective = versions.lastOrNull;
                if (effective == null && snapshots['versions:${doc.id}']?.docs.isNotEmpty == true) {
                  continue;
                }
                final commitment = diagnosticCommitment(doc.id, {
                  ...d,
                  ...?effective,
                  'pauseRanges': d['pauseRanges'],
                  'pausedFromMonth': d['pausedFromMonth'],
                  'skippedMonths': d['skippedMonths'],
                });
                final due = commitment.dueDateFor(key);
                if (due == null || commitment.isSkipped(key)) continue;
                final paid = snapshots['debtPaymentLinks']!.docs
                    .where(
                      (link) =>
                          link.data()['commitmentId'] == doc.id && link.data()['monthKey'] == key,
                    )
                    .fold<int>(0, (s, l) => s + (l.data()['amountMinor'] as num).toInt());
                plan.add(
                  PlanningAgendaEntry(
                    id: 'debt:${doc.id}:$key',
                    kind: PlanningEntryKind.debt,
                    date: due,
                    title:
                        accounts.where((a) => a.id == commitment.debtAccountId).firstOrNull?.name ??
                        commitment.debtAccountId,
                    currency: commitment.currency,
                    plannedMinor: commitment.amountMinor,
                    recordedMinor: paid,
                    pendingMinor: d['status'] != 'active'
                        ? 0
                        : (commitment.amountMinor - paid).clamp(0, commitment.amountMinor),
                    monthKey: key,
                    debtAccountId: commitment.debtAccountId,
                    bankAccountId: commitment.bankAccountId,
                    commitmentId: doc.id,
                  ),
                );
              }
            }
            final cached = snapshots.values.any((s) => s.metadata.isFromCache);
            final pending =
                snapshots.values.any((s) => s.metadata.hasPendingWrites) ||
                operations.any(
                  (o) => o.status.name == 'confirmed' && !entries.any((e) => e.operationId == o.id),
                );
            final valuations = <DiagnosticRecord>[];
            for (final e in snapshots.entries.where((e) => e.key.startsWith('valuations:'))) {
              for (final d in e.value.docs) {
                valuations.add(
                  DiagnosticRecord(
                    '${e.key}:${d.id}',
                    'asset',
                    Map<String, Object>.from(d.data()['values'] as Map),
                  ),
                );
              }
            }
            controller.add(
              DiagnosticSnapshot(
                DiagnosticInput(
                  today: today,
                  accounts: accounts,
                  operations: operations,
                  entries: entries,
                  plan: plan,
                  records: records,
                  allocationIncomplete: snapshots['debtPayments']!.docs.any(
                    (d) => d.data()['status'] == 'unallocated',
                  ),
                  cached: cached,
                  pending: pending,
                ),
                {
                  for (final d in snapshots['diagnosticRecords']!.docs)
                    d.id: (d.data()['revision'] as num).toInt(),
                },
                valuations: valuations,
              ),
            );
          } catch (error, stack) {
            controller.addError(error, stack);
          }
        }

        void subscribe(String key, Query<Map<String, dynamic>> query) {
          subscriptions[key] = query.snapshots(includeMetadataChanges: true).listen((snapshot) {
            if (cancelled) return;
            snapshots[key] = snapshot;
            if (key == 'budgets' || key == 'diagnosticRecords' || key == 'debtCommitments') {
              final desired = <String, Query<Map<String, dynamic>>>{};
              final referenced =
                  snapshots['diagnosticRecords']?.docs
                      .map((d) => (d.data()['values'] as Map)['entryId'])
                      .whereType<String>()
                      .toSet() ??
                  <String>{};
              if (snapshots['debtCommitments'] != null) {
                for (final d in snapshots['debtCommitments']!.docs.where(
                  (d) =>
                      d.data()['status'] == 'active' ||
                      referenced.any((id) => id.startsWith('debt:${d.id}:')),
                )) {
                  desired['versions:${d.id}'] = d.reference.collection('versions');
                }
              }
              if (snapshots['budgets'] != null) {
                for (final d in snapshots['budgets']!.docs.where(
                  (d) =>
                      d.data()['status'] == 'active' ||
                      referenced.any((id) => id.startsWith('budget:${d.id}:')),
                )) {
                  desired['items:${d.id}'] = d.reference.collection('items');
                }
              }
              if (snapshots['diagnosticRecords'] != null) {
                for (final d in snapshots['diagnosticRecords']!.docs.where(
                  (d) => d.data()['kind'] == 'asset',
                )) {
                  desired['valuations:${d.id}'] = d.reference.collection('valuations');
                }
              }
              for (final old
                  in subscriptions.keys
                      .where(
                        (k) =>
                            (k.startsWith('items:') ||
                                k.startsWith('valuations:') ||
                                k.startsWith('versions:')) &&
                            !desired.containsKey(k),
                      )
                      .toList()) {
                unawaited(subscriptions.remove(old)!.cancel());
                snapshots.remove(old);
              }
              for (final e in desired.entries) {
                if (!subscriptions.containsKey(e.key)) subscribe(e.key, e.value);
              }
            }
            emit();
          }, onError: controller.addError);
        }

        for (final name in base) {
          Query<Map<String, dynamic>> query = root.collection(name);
          // Complete range queries, with no UI pagination limit or recent sample.
          if (name == 'operations' || name == 'ledgerEntries') {
            query = query.where(
              'occurredAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(historyStartUtc),
            );
          }
          subscribe(name, query);
        }
        controller.onCancel = () async {
          cancelled = true;
          await Future.wait(subscriptions.values.map((s) => s.cancel()));
        };
      });

  @override
  Future<Either<Failure, int>> save(
    String uid,
    DiagnosticRecord record, {
    required int generation,
    required int revision,
    required String requestId,
    bool delete = false,
  }) async {
    if (auth.currentUser?.uid != uid) return const Left(AuthFailure('diagnostic-session-expired'));
    try {
      final result = await functions.httpsCallable('mutateDiagnostic').call<Map<String, dynamic>>({
        'requestId': requestId,
        'expectedGeneration': generation,
        'revision': revision,
        'recordId': record.id,
        'kind': record.kind,
        'values': record.values,
        'action': delete ? 'delete' : 'save',
      });
      return Right((result.data['revision'] as num).toInt());
    } on FirebaseFunctionsException catch (error) {
      return Left(switch (error.code) {
        'unauthenticated' => const AuthFailure('diagnostic-session-expired'),
        'unavailable' ||
        'deadline-exceeded' => const NetworkFailure('diagnostic-connection-required'),
        'failed-precondition' ||
        'already-exists' => const ConflictFailure('diagnostic-reload-required'),
        _ => const UnknownFailure('diagnostic-validation-failed'),
      });
    } catch (_) {
      return const Left(UnknownFailure('diagnostic-save-failed'));
    }
  }
}

DebtCommitment diagnosticCommitment(String id, Map<String, dynamic> d) {
  return DebtCommitment(
    id: id,
    debtAccountId: d['debtAccountId'] as String,
    currency: d['currency'] as String,
    amountMinor: (d['amountMinor'] as num).toInt(),
    firstDueMonth: d['firstDueMonth'] as String,
    dueDay: d['dueDay'] as int,
    lastDueMonth: d['lastDueMonth'] as String?,
    bankAccountId: d['bankAccountId'] as String?,
    pausedFromMonth: d['pausedFromMonth'] as String?,
    skippedMonths: (d['skippedMonths'] as List?)?.cast<String>().toSet() ?? {},
    pauseRanges:
        (d['pauseRanges'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map(
              (r) => (
                fromMonth: r['fromMonth'] as String,
                untilMonth: r['untilMonth'] as String?,
              ),
            )
            .toList() ??
        [],
  );
}
