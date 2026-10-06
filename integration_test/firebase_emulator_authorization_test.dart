import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
    await FirebaseAuth.instance.signOut();
  });

  tearDownAll(() => FirebaseAuth.instance.signOut());

  testWidgets('Android client authorization reaches each canonical Firestore boundary', (
    tester,
  ) async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final credential = await auth.signInAnonymously();
    final user = credential.user!;
    final token = await user.getIdToken(true);
    final app = Firebase.app();

    debugPrint('AUTH_DIAGNOSTIC uid=${user.uid} tokenPresent=${token?.isNotEmpty == true}');
    debugPrint('AUTH_DIAGNOSTIC projectId=${app.options.projectId} appId=${app.options.appId}');

    final catalog = await firestore
        .collection('categoryCatalog')
        .where('isActive', isEqualTo: true)
        .where('supportedCountries', arrayContains: 'CO')
        .get();
    debugPrint('AUTH_DIAGNOSTIC catalogCount=${catalog.docs.length}');
    expect(catalog.docs, isNotEmpty);

    final userReference = firestore.collection('users').doc(user.uid);
    await userReference.set({
      'locale': 'es',
      'countryCode': 'CO',
      'timeZone': 'America/Bogota',
      'defaultCurrency': 'COP',
      'onboardingStatus': 'complete',
      'categoryCatalogVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    expect((await userReference.get()).exists, isTrue);
    debugPrint('AUTH_DIAGNOSTIC userProfile=ok');

    final catalogId = catalog.docs.first.id;
    final systemCategory = userReference.collection('categories').doc(catalogId);
    final catalogData = catalog.docs.first.data();
    await systemCategory.set({
      'catalogId': catalogId,
      'type': catalogData['type'],
      'name': (catalogData['labels'] as Map)['es'],
      'icon': catalogData['icon'],
      'sortOrder': catalogData['sortOrder'],
      'isSystem': true,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    expect((await systemCategory.get()).exists, isTrue);
    debugPrint('AUTH_DIAGNOSTIC systemCategory=ok');
  });
}
