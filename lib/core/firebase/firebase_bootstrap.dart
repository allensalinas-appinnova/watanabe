import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../config/environment/app_environment.dart';
import 'firebase_options.dart';

abstract final class FirebaseBootstrap {
  static Future<void> initialize(
    AppEnvironment environment, {
    bool useEmulators = false,
    String emulatorHost = '127.0.0.1',
    int authEmulatorPort = 59199,
    int firestoreEmulatorPort = 59180,
    int storageEmulatorPort = 59191,
  }) async {
    environment.validate(useEmulators: useEmulators, isRelease: kReleaseMode);
    await Firebase.initializeApp(
      options: AppFirebaseOptions.forEnvironment(
        environment,
        useEmulators: useEmulators,
      ),
    );

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;

    if (useEmulators) {
      await auth.useAuthEmulator(emulatorHost, authEmulatorPort);
      firestore.useFirestoreEmulator(emulatorHost, firestoreEmulatorPort);
      await storage.useStorageEmulator(emulatorHost, storageEmulatorPort);
      return;
    }

    FirebaseAnalytics.instance;
    FirebaseCrashlytics.instance;
  }
}
