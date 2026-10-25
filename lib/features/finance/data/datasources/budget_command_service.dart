import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract interface class BudgetCommandService {
  Future<Map<String, dynamic>> execute(String userId, Map<String, dynamic> command);
}

class FirebaseBudgetCommandService implements BudgetCommandService {
  FirebaseBudgetCommandService({
    required FirebaseFunctions functions,
    required FirebaseAuth auth,
    FirebaseFirestore? firestore,
  }) : _functions = functions,
       _auth = auth,
       _firestore = firestore;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final FirebaseFirestore? _firestore;

  @override
  Future<Map<String, dynamic>> execute(String userId, Map<String, dynamic> command) async {
    if (_auth.currentUser?.uid != userId) {
      throw FirebaseFunctionsException(code: 'unauthenticated', message: 'budget-session-expired');
    }
    final firestore = _firestore;
    var generation = 0;
    if (firestore != null) {
      final profile = await firestore
          .collection('users')
          .doc(userId)
          .get(const GetOptions(source: Source.server));
      if (profile.data()?['resetStatus'] == 'resetting') {
        throw FirebaseFunctionsException(code: 'failed-precondition', message: 'reset-in-progress');
      }
      generation = (profile.data()?['dataGeneration'] as num? ?? 0).toInt();
    }
    final response = await _functions
        .httpsCallable(
          'mutateBudget',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        )
        .call<Map<String, dynamic>>({...command, 'expectedGeneration': generation});
    return Map<String, dynamic>.from(response.data);
  }
}
