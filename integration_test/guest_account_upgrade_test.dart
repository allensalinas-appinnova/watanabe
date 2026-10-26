import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '127.0.0.1');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final response = await client
          .getUrl(Uri(scheme: 'http', host: host, port: 59199))
          .then((request) => request.close());
      await response.drain<void>();
      expect(response.statusCode, HttpStatus.ok);
    } finally {
      client.close(force: true);
    }
    await FirebaseBootstrap.initialize(AppEnvironment.dev, useEmulators: true, emulatorHost: host);
  });

  testWidgets('linking email preserves guest UID and Firestore data', (tester) async {
    final auth = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app);
    final firestore = FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app);
    final guest = (await auth.signInAnonymously()).user!;
    final uid = guest.uid;
    final email = 'guest-upgrade-${DateTime.now().microsecondsSinceEpoch}@example.test';
    final password = 'SecureTestPassword123!';
    final profile = firestore.collection('users').doc(uid);
    await profile.set({
      'locale': 'es',
      'countryCode': 'CO',
      'timeZone': 'America/Bogota',
      'defaultCurrency': 'COP',
      'onboardingStatus': 'complete',
      'categoryCatalogVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await profile.collection('accounts').doc('synthetic-account').set({
      'name': 'Cuenta de prueba',
      'type': 'wallet',
      'currency': 'COP',
      'openingBalanceMinor': 1234500,
      'currentBalanceMinor': 1234500,
      'includeInDashboard': true,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'dataGeneration': 0,
    });

    final linked = await guest.linkWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    await linked.user!.reload();

    expect(auth.currentUser?.uid, uid);
    expect(auth.currentUser?.isAnonymous, isFalse);
    expect((await profile.get()).exists, isTrue);
    final account = profile.collection('accounts').doc('synthetic-account');
    expect((await account.get()).data()?['currentBalanceMinor'], 1234500);
    debugPrint('GUEST_UPGRADE uidPreserved=true profilePreserved=true provider=email');

    // Keep this synthetic profile for post-run inspection. Client rules correctly
    // prohibit deleting financial documents, including from this test flow.
  });

  testWidgets('credential conflict leaves the guest session active', (tester) async {
    final auth = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app);
    final email = 'guest-conflict-${DateTime.now().microsecondsSinceEpoch}@example.test';
    const password = 'SecureTestPassword123!';
    final registered = (await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    )).user!;
    final registeredUid = registered.uid;
    await auth.signOut();
    final guest = (await auth.signInAnonymously()).user!;
    final guestUid = guest.uid;

    await expectLater(
      guest.linkWithCredential(EmailAuthProvider.credential(email: email, password: password)),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          anyOf('credential-already-in-use', 'email-already-in-use'),
        ),
      ),
    );

    expect(auth.currentUser?.uid, guestUid);
    expect(auth.currentUser?.isAnonymous, isTrue);
    expect(auth.currentUser?.uid, isNot(registeredUid));
    debugPrint('GUEST_UPGRADE conflictKeepsGuest=true registeredUidChanged=false');
    await auth.currentUser!.delete();
    await auth.signInWithEmailAndPassword(email: email, password: password);
    await auth.currentUser!.delete();
  });
}
