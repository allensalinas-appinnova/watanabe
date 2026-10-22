import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../config/environment/app_environment.dart';
import 'firebase_options.dart';

abstract final class FirebaseBootstrap {
  static FirebaseApp? _app;

  static FirebaseApp get app => _app ?? Firebase.app();

  static Future<void> initialize(
    AppEnvironment environment, {
    bool useEmulators = false,
    String emulatorHost = '127.0.0.1',
    int authEmulatorPort = 59199,
    int firestoreEmulatorPort = 59180,
    int storageEmulatorPort = 59191,
    int functionsEmulatorPort = 59192,
  }) async {
    environment.validate(useEmulators: useEmulators, isRelease: kReleaseMode);
    _app = await Firebase.initializeApp(
      // Native configuration can already initialize the real default app.
      // Never reuse it for emulator data or authentication.
      name: useEmulators ? 'demo-clearbudget' : null,
      options: AppFirebaseOptions.forEnvironment(
        environment,
        useEmulators: useEmulators,
      ),
    );

    final auth = FirebaseAuth.instanceFor(app: app);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    final storage = FirebaseStorage.instanceFor(app: app);

    if (useEmulators) {
      await auth.useAuthEmulator(emulatorHost, authEmulatorPort);
      firestore.useFirestoreEmulator(emulatorHost, firestoreEmulatorPort);
      await storage.useStorageEmulator(emulatorHost, storageEmulatorPort);
      FirebaseFunctions.instanceFor(
        app: app,
        region: 'us-central1',
      ).useFunctionsEmulator(emulatorHost, functionsEmulatorPort);
      return;
    }

    FirebaseAnalytics.instance;
  }
}
