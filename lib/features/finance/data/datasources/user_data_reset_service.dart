import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract interface class UserDataResetService {
  Future<int> reset({
    required String userId,
    required String requestId,
    required int expectedGeneration,
  });
}

class FirebaseUserDataResetService implements UserDataResetService {
  const FirebaseUserDataResetService({
    required FirebaseFunctions functions,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _functions = functions,
       _firestore = firestore,
       _auth = auth;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<int> reset({
    required String userId,
    required String requestId,
    required int expectedGeneration,
  }) async {
    if (_auth.currentUser?.uid != userId) {
      throw FirebaseFunctionsException(code: 'unauthenticated', message: 'reset-session-expired');
    }
    final profile = await _firestore
        .collection('users')
        .doc(userId)
        .get(const GetOptions(source: Source.server));
    final current = (profile.data()?['dataGeneration'] as num? ?? 0).toInt();
    if (current != expectedGeneration && profile.data()?['resetRequestId'] != requestId) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'reset-generation-conflict',
      );
    }
    final response = await _functions
        .httpsCallable(
          'resetUserData',
          options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
        )
        .call<Map<String, dynamic>>({
          'requestId': requestId,
          'expectedGeneration': expectedGeneration,
          'confirmed': true,
        });
    final generation = response.data['dataGeneration'];
    if (response.data['status'] != 'complete' || generation is! num) {
      throw FirebaseFunctionsException(code: 'internal', message: 'reset-invalid-response');
    }
    return generation.toInt();
  }
}
