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

  Future<int> _generation(String userId) async {
    if (_auth.currentUser?.uid != userId) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'operation-session-expired',
      );
    }
    final profile = await _firestore
        .collection('users')
        .doc(userId)
        .get(const GetOptions(source: Source.server));
    if (profile.data()?['resetStatus'] == 'resetting') {
      throw FirebaseFunctionsException(code: 'failed-precondition', message: 'reset-in-progress');
    }
    return (profile.data()?['dataGeneration'] as num? ?? 0).toInt();
  }

  Future<void> _call(Map<String, Object?> command) async {
    final payload = Map<String, Object?>.fromEntries(
      command.entries.where((entry) => entry.value != null),
    );
    await _functions
        .httpsCallable(
          'mutateOperation',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        )
        .call<Map<String, dynamic>>(payload);
  }

  Future<void> create(String userId, Map<String, Object?> operation) async {
    final currentGeneration = await _generation(userId);
    // Preserve the generation captured when the offline draft was created.
    // Re-tagging a stale outbox item with the current generation could restore
    // financial data after the user reset their account.
    final generation = (operation['dataGeneration'] as num?)?.toInt() ?? currentGeneration;
    final requestId = operation['idempotencyKey'];
    final operationPayload = Map<String, Object?>.from(operation)
      ..remove('dataGeneration');
    await _call({
      ...operationPayload,
      'action': 'create',
      'requestId': requestId,
      'expectedGeneration': generation,
    });
  }

  Future<void> execute(String userId, Map<String, Object?> command) async {
    final generation = await _generation(userId);
    await _call({
      ...command,
      'action': 'correct',
      'expectedGeneration': generation,
    });
  }

  Future<void> cancel(String userId, String operationId) async {
    final generation = await _generation(userId);
    await _call({
      'action': 'cancel',
      'operationId': operationId,
      'expectedGeneration': generation,
    });
  }

  Future<void> archiveAccount(String userId, String accountId) async {
    final generation = await _generation(userId);
    await _call({
      'action': 'archiveAccount',
      'accountId': accountId,
      'expectedGeneration': generation,
    });
  }
}
