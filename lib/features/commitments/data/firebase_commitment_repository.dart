import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import '../domain/commitment_repository.dart';
import '../domain/debt_commitment.dart';

class FirebaseCommitmentRepository implements CommitmentRepository {
  FirebaseCommitmentRepository({
    required this.firestore,
    required this.functions,
    required this.auth,
  });

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final FirebaseAuth auth;

  @override
  Stream<List<DebtCommitment>> watch(String userId) => firestore
      .collection('users')
      .doc(userId)
      .collection('debtCommitments')
      .where('status', isEqualTo: 'active')
      .snapshots()
      .asyncMap(
        (snapshot) => Future.wait(
          snapshot.docs
              .map((doc) async {
                final data = doc.data();
                final versions = await doc.reference.collection('versions').get();
                final occurrences = await doc.reference.collection('occurrences').get();
                DebtCommitmentTerms terms(Map<String, dynamic> value, String month) =>
                    DebtCommitmentTerms(
                      version: (value['version'] as num? ?? 0).toInt(),
                      effectiveFromMonth: month,
                      amountMinor: (value['amountMinor'] as num).toInt(),
                      dueDay: (value['dueDay'] as num).toInt(),
                      remindersEnabled: value['remindersEnabled'] as bool? ?? false,
                      lastDueMonth: value['lastDueMonth'] as String?,
                      bankAccountId: value['bankAccountId'] as String?,
                    );
                return DebtCommitment(
                  id: doc.id,
                  debtAccountId: data['debtAccountId'] as String,
                  currency: data['currency'] as String,
                  amountMinor: (data['amountMinor'] as num).toInt(),
                  firstDueMonth: data['firstDueMonth'] as String,
                  dueDay: (data['dueDay'] as num).toInt(),
                  lastDueMonth: data['lastDueMonth'] as String?,
                  bankAccountId: data['bankAccountId'] as String?,
                  remindersEnabled: data['remindersEnabled'] as bool? ?? false,
                  versions: versions.docs
                      .map(
                        (version) =>
                            terms(version.data(), version.data()['effectiveFromMonth'] as String),
                      )
                      .toList(),
                  occurrenceOverrides: {
                    for (final occurrence in occurrences.docs)
                      if (occurrence.data()['terms'] is Map<String, dynamic>)
                        occurrence.data()['monthKey'] as String: terms(
                          occurrence.data()['terms'] as Map<String, dynamic>,
                          occurrence.data()['monthKey'] as String,
                        ),
                  },
                  pausedFromMonth: data['pausedFromMonth'] as String?,
                  skippedMonths:
                      (data['skippedMonths'] as List?)?.whereType<String>().toSet() ?? const {},
                  pauseRanges:
                      (data['pauseRanges'] as List?)
                          ?.whereType<Map<String, dynamic>>()
                          .map(
                            (range) => (
                              fromMonth: range['fromMonth'] as String,
                              untilMonth: range['untilMonth'] as String?,
                            ),
                          )
                          .toList(growable: false) ??
                      const [],
                );
              })
              .toList(growable: false),
        ),
      );

  @override
  Stream<List<DebtCommitmentPaymentLink>> watchPayments(String userId) => firestore
      .collection('users')
      .doc(userId)
      .collection('debtPaymentLinks')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              return DebtCommitmentPaymentLink(
                paymentId: doc.id,
                commitmentId: data['commitmentId'] as String,
                monthKey: data['monthKey'] as String,
                amountMinor: (data['amountMinor'] as num).toInt(),
              );
            })
            .toList(growable: false),
      );

  @override
  Future<Either<Failure, String>> execute(String userId, Map<String, Object?> command) async {
    try {
      if (auth.currentUser?.uid != userId) {
        throw FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'commitment-session-expired',
        );
      }
      final profile = await firestore
          .collection('users')
          .doc(userId)
          .get(const GetOptions(source: Source.server));
      if (!profile.exists || profile.data()?['resetStatus'] == 'resetting') {
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'commitment-profile-unavailable',
        );
      }
      final response = await functions
          .httpsCallable(
            'mutateDebtCommitment',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
          )
          .call<Map<String, dynamic>>({
            ...command,
            'expectedGeneration': (profile.data()?['dataGeneration'] as num? ?? 0).toInt(),
          });
      return Right(response.data['commitmentId'] as String);
    } on FirebaseFunctionsException catch (error) {
      final raw = error.details is Map ? (error.details as Map)['issue'] : null;
      final issue = raw is String && RegExp(r'^commitment-[a-z-]{1,64}$').hasMatch(raw)
          ? raw
          : 'commitment-command-failed';
      return Left(switch (error.code) {
        'unauthenticated' => const AuthFailure('commitment-session-expired'),
        'unavailable' ||
        'deadline-exceeded' => const NetworkFailure('commitment-connection-required'),
        'already-exists' => ConflictFailure(issue),
        _ => UnknownFailure(issue),
      });
    } catch (_) {
      return const Left(UnknownFailure('commitment-command-failed'));
    }
  }
}
