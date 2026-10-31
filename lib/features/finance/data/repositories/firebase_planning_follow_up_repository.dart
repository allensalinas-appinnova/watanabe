import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/planning_follow_up.dart';
import '../../domain/repositories/planning_follow_up_repository.dart';

class FirebasePlanningFollowUpRepository implements PlanningFollowUpRepository {
  FirebasePlanningFollowUpRepository({
    required this.firestore,
    required this.functions,
    required this.auth,
  });
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final FirebaseAuth auth;

  PlanningFollowUp _decode(Map<String, dynamic> data) => PlanningFollowUp(
    source: PlanningSource(
      kind: PlanningSourceKind.values.byName(data['kind'] as String),
      monthKey: data['monthKey'] as String,
      budgetId: data['budgetId'] as String?,
      itemId: data['itemId'] as String?,
      commitmentId: data['commitmentId'] as String?,
    ),
    state: PlanningFollowUpState.values.byName(data['state'] as String),
    version: (data['version'] as num).toInt(),
    dataGeneration: (data['dataGeneration'] as num? ?? 0).toInt(),
    remindOn: data['remindOn'] as String?,
    reason: data['reason'] as String?,
  );

  @override
  Stream<PlanningFollowUpSnapshot> watch(String userId) => firestore
      .collection('users')
      .doc(userId)
      .collection('planningFollowUps')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => PlanningFollowUpSnapshot(
          items: snapshot.docs.map((doc) => _decode(doc.data())).toList(growable: false),
          fromCache: snapshot.metadata.isFromCache,
          pendingWrites: snapshot.metadata.hasPendingWrites,
        ),
      );

  @override
  Future<Either<Failure, PlanningFollowUp>> mutate(
    String userId,
    PlanningFollowUpCommand command,
  ) async {
    try {
      if (auth.currentUser?.uid != userId) {
        return const Left(AuthFailure('planning-session-expired'));
      }
      final source = command.source;
      final result = await functions
          .httpsCallable('mutatePlanningFollowUp')
          .call<Map<String, dynamic>>({
            'action': command.action.name,
            'requestId': command.requestId,
            'expectedGeneration': command.expectedGeneration,
            'expectedVersion': command.expectedVersion,
            'kind': source.kind.name,
            'monthKey': source.monthKey,
            if (source.kind == PlanningSourceKind.expense) ...{
              'budgetId': source.budgetId,
              'itemId': source.itemId,
            },
            if (source.kind == PlanningSourceKind.debt) 'commitmentId': source.commitmentId,
            if (command.action == PlanningFollowUpAction.snooze) 'remindOn': command.remindOn,
          });
      return Right(_decode(result.data));
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final raw = details is Map ? details['issue'] : null;
      final issue = raw is String && RegExp(r'^planning-[a-z-]{1,64}$').hasMatch(raw)
          ? raw
          : 'planning-follow-up-failed';
      return Left(switch (error.code) {
        'unavailable' || 'deadline-exceeded' => NetworkFailure(issue),
        'unauthenticated' || 'permission-denied' => AuthFailure(issue),
        'already-exists' || 'failed-precondition' => ConflictFailure(issue),
        _ => UnknownFailure(issue),
      });
    } catch (_) {
      return const Left(UnknownFailure('planning-follow-up-failed'));
    }
  }
}
