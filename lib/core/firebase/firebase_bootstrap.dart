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
    final options = AppFirebaseOptions.forEnvironment(
      environment,
      useEmulators: useEmulators,
    );
    if (useEmulators) {
      _app = await Firebase.initializeApp(
        name: 'demo-clearbudget',
        options: options,
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android already loads its platform-specific app from
      // google-services.json. Supplying web Dart defines here can conflict
      // with that native app and cause [core/duplicate-app].
      _app = await Firebase.initializeApp();
      if (_app!.options.projectId != options.projectId) {
        throw StateError(
          'The native Firebase app does not match the selected environment.',
        );
      }
    } else {
      _app = await Firebase.initializeApp(options: options);
    }

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
