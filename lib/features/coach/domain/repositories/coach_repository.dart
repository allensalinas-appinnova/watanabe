import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/coach_models.dart';

abstract interface class CoachRepository {
  /// Server rejections received after a write returned [CoachWriteState.pending].
  Stream<CoachWriteFailure> watchWriteFailures(String uid);

  Stream<CoachPreferences> watchPreferences(String uid);
  Stream<List<CoachCompletion>> watchCompletions(String uid, {required DateTime since});
  Stream<CoachCompletion?> watchCompletion(
    String uid, {
    required CoachReviewKind kind,
    required String periodKey,
  });

  /// Period-scoped change signals; each source's initial snapshot is skipped.
  Stream<void> watchReportChanges(
    String uid, {
    required DateTime startAt,
    required DateTime endAtExclusive,
  });
  Future<Either<Failure, CoachWriteState>> savePreferences(
    String uid,
    CoachPreferences preferences,
  );
  Future<Either<Failure, CoachWriteState>> complete(
    String uid, {
    required String periodKey,
    required CoachReviewKind kind,
    bool noMovements = false,
  });
  Future<Either<Failure, CoachPeriodReport>> loadReport(
    String uid, {
    required DateTime startAt,
    required DateTime endAtExclusive,
  });
}
