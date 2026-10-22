import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract interface class BudgetCommandService {
  Future<Map<String, dynamic>> execute(String userId, Map<String, dynamic> command);
}

class FirebaseBudgetCommandService implements BudgetCommandService {
  FirebaseBudgetCommandService({required FirebaseFunctions functions, required FirebaseAuth auth})
    : _functions = functions,
      _auth = auth;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  @override
  Future<Map<String, dynamic>> execute(String userId, Map<String, dynamic> command) async {
    if (_auth.currentUser?.uid != userId) {
      throw FirebaseFunctionsException(code: 'unauthenticated', message: 'budget-session-expired');
    }
    final response = await _functions
        .httpsCallable(
          'mutateBudget',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        )
        .call<Map<String, dynamic>>(command);
    return Map<String, dynamic>.from(response.data);
  }
}
