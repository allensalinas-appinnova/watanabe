import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseOperationCorrectionService {
  const FirebaseOperationCorrectionService({
    required FirebaseFunctions functions,
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _functions = functions,
       _auth = auth,
       _firestore = firestore;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> execute(String userId, Map<String, Object?> command) async {
    if (_auth.currentUser?.uid != userId) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'operation-edit-session-expired',
      );
    }
    final profile = await _firestore
        .collection('users')
        .doc(userId)
        .get(const GetOptions(source: Source.server));
    if (profile.data()?['resetStatus'] == 'resetting') {
      throw FirebaseFunctionsException(code: 'failed-precondition', message: 'reset-in-progress');
    }
    final generation = (profile.data()?['dataGeneration'] as num? ?? 0).toInt();
    await _functions
        .httpsCallable(
          'mutateOperation',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        )
        .call<Map<String, dynamic>>({...command, 'expectedGeneration': generation});
  }
}
