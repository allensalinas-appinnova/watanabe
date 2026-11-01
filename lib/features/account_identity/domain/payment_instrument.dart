import 'package:fpdart/fpdart.dart';
import '../../../core/error/failure.dart';

class PaymentInstrument {
  const PaymentInstrument({
    required this.id,
    required this.accountId,
    required this.name,
    required this.lastFour,
    required this.version,
    required this.dataGeneration,
    this.status = 'active',
  });
  final String id, accountId, name, lastFour, status;
  final int version, dataGeneration;
}

enum InstrumentAction { create, update, archive }

class InstrumentCommand {
  const InstrumentCommand({
    required this.requestId,
    required this.generation,
    required this.version,
    required this.action,
    required this.accountId,
    this.instrumentId,
    this.name,
    this.lastFour,
  });
  final String requestId, accountId;
  final String? instrumentId, name, lastFour;
  final int generation, version;
  final InstrumentAction action;
}

abstract interface class PaymentInstrumentRepository {
  Stream<List<PaymentInstrument>> watch(String uid, String accountId);
  Future<Either<Failure, Unit>> execute(InstrumentCommand command);
}
