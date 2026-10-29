import 'package:fpdart/fpdart.dart';
import '../../../core/error/failure.dart';
import 'diagnostic_engine.dart';
import 'diagnostic_record.dart';

class DiagnosticSnapshot {
  const DiagnosticSnapshot(this.input, this.revisions, {this.valuations = const []});
  final DiagnosticInput input;
  final Map<String, int> revisions;
  final List<DiagnosticRecord> valuations;
}

abstract interface class DiagnosticRepository {
  Stream<DiagnosticSnapshot> watch(String uid, DateTime today, DateTime historyStartUtc);
  Future<Either<Failure, int>> save(
    String uid,
    DiagnosticRecord record, {
    required int generation,
    required int revision,
    required String requestId,
    bool delete = false,
  });
}
