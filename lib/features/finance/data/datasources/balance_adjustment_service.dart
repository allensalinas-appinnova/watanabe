import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/balance_adjustment.dart';

abstract interface class BalanceAdjustmentService {
  Future<Map<String, Object?>> adjust({
    required String requestId,
    required List<BalanceAdjustmentDraft> adjustments,
    String? reason,
  });
}

class FirebaseBalanceAdjustmentService implements BalanceAdjustmentService {
  const FirebaseBalanceAdjustmentService({required FirebaseFunctions functions})
    : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, Object?>> adjust({
    required String requestId,
    required List<BalanceAdjustmentDraft> adjustments,
    String? reason,
  }) async {
    final response = await _functions
        .httpsCallable('adjustAccountBalances')
        .call<Map<dynamic, dynamic>>({
          'requestId': requestId,
          'adjustments': adjustments.map((adjustment) => adjustment.toJson()).toList(),
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        });
    return Map<String, Object?>.from(response.data);
  }
}
