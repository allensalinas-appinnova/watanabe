import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/balance_adjustment.dart';

abstract interface class BalanceAdjustmentService {
  Future<Map<String, Object?>> adjust({
    required String userId,
    required String requestId,
    required List<BalanceAdjustmentDraft> adjustments,
    String? reason,
  });
}

class FirebaseBalanceAdjustmentService implements BalanceAdjustmentService {
  const FirebaseBalanceAdjustmentService({
    required FirebaseFunctions functions,
    FirebaseFirestore? firestore,
  }) : _functions = functions,
       _firestore = firestore;

  final FirebaseFunctions _functions;
  final FirebaseFirestore? _firestore;

  @override
  Future<Map<String, Object?>> adjust({
    required String userId,
    required String requestId,
    required List<BalanceAdjustmentDraft> adjustments,
    String? reason,
  }) async {
    var generation = 0;
    final database = _firestore;
    if (database != null) {
      final profile = await database
          .collection('users')
          .doc(userId)
          .get(const GetOptions(source: Source.server));
      if (profile.data()?['resetStatus'] == 'resetting') {
        throw FirebaseFunctionsException(code: 'failed-precondition', message: 'reset-in-progress');
      }
      generation = (profile.data()?['dataGeneration'] as num? ?? 0).toInt();
    }
    final response = await _functions
        .httpsCallable('adjustAccountBalances')
        .call<Map<dynamic, dynamic>>({
          'requestId': requestId,
          'expectedGeneration': generation,
          'adjustments': adjustments.map((adjustment) => adjustment.toJson()).toList(),
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        });
    return Map<String, Object?>.from(response.data);
  }
}
