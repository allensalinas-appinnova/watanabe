import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fpdart/fpdart.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/firebase_failure_mapper.dart';
import '../domain/payment_instrument.dart';

class FirebasePaymentInstrumentRepository implements PaymentInstrumentRepository {
  FirebasePaymentInstrumentRepository(this.firestore, this.functions);
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  @override
  Stream<List<PaymentInstrument>> watch(String uid, String accountId) => firestore
      .collection('users')
      .doc(uid)
      .collection('paymentInstruments')
      .where('accountId', isEqualTo: accountId)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) {
              final v = d.data();
              return PaymentInstrument(
                id: d.id,
                accountId: v['accountId'] as String,
                name: v['name'] as String? ?? '',
                lastFour: v['lastFour'] as String? ?? '',
                version: (v['version'] as num).toInt(),
                dataGeneration: (v['dataGeneration'] as num).toInt(),
                status: v['status'] as String? ?? 'active',
              );
            })
            .toList(growable: false),
      );
  @override
  Future<Either<Failure, Unit>> execute(InstrumentCommand c) async {
    try {
      await functions.httpsCallable('mutatePaymentInstrument').call<Object?>({
        'requestId': c.requestId,
        'expectedGeneration': c.generation,
        'expectedVersion': c.version,
        'action': c.action.name,
        'accountId': c.accountId,
        if (c.instrumentId != null) 'instrumentId': c.instrumentId,
        if (c.name != null) 'name': c.name,
        if (c.lastFour != null) 'lastFour': c.lastFour,
      });
      return const Right(unit);
    } catch (e) {
      return Left(FirebaseFailureMapper.fromException(e));
    }
  }
}
