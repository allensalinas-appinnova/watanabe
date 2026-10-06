import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../config/environment/app_environment.dart';

abstract final class AppFirebaseOptions {
  static FirebaseOptions forEnvironment(
    AppEnvironment environment, {
    bool useEmulators = false,
  }) {
    if (useEmulators) {
      final appPlatform = kIsWeb
          ? 'web'
          : switch (defaultTargetPlatform) {
              TargetPlatform.android => 'android',
              TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
              _ => 'web',
            };
      return FirebaseOptions(
        apiKey: 'A12345678901234567890123456789012345678',
        appId: '1:1234567890:$appPlatform:abcdef0123456789abcdef',
        messagingSenderId: '1234567890',
        projectId: 'demo-clearbudget',
        authDomain: 'demo-clearbudget.firebaseapp.com',
        storageBucket: 'demo-clearbudget.appspot.com',
      );
    }

    return switch (environment) {
      AppEnvironment.dev => _configured(
        apiKey: const String.fromEnvironment('FIREBASE_DEV_API_KEY'),
        appId: const String.fromEnvironment('FIREBASE_DEV_APP_ID'),
        messagingSenderId: const String.fromEnvironment(
          'FIREBASE_DEV_MESSAGING_SENDER_ID',
        ),
        projectId: const String.fromEnvironment('FIREBASE_DEV_PROJECT_ID'),
        storageBucket: const String.fromEnvironment('FIREBASE_DEV_STORAGE_BUCKET'),
        authDomain: const String.fromEnvironment('FIREBASE_DEV_AUTH_DOMAIN'),
        iosBundleId: const String.fromEnvironment('FIREBASE_DEV_IOS_BUNDLE_ID'),
        measurementId: const String.fromEnvironment('FIREBASE_DEV_MEASUREMENT_ID'),
      ),
      AppEnvironment.staging => _configured(
        apiKey: const String.fromEnvironment('FIREBASE_STAGING_API_KEY'),
        appId: const String.fromEnvironment('FIREBASE_STAGING_APP_ID'),
        messagingSenderId: const String.fromEnvironment(
          'FIREBASE_STAGING_MESSAGING_SENDER_ID',
        ),
        projectId: const String.fromEnvironment('FIREBASE_STAGING_PROJECT_ID'),
        storageBucket: const String.fromEnvironment('FIREBASE_STAGING_STORAGE_BUCKET'),
        authDomain: const String.fromEnvironment('FIREBASE_STAGING_AUTH_DOMAIN'),
        iosBundleId: const String.fromEnvironment('FIREBASE_STAGING_IOS_BUNDLE_ID'),
        measurementId: const String.fromEnvironment('FIREBASE_STAGING_MEASUREMENT_ID'),
      ),
      AppEnvironment.prod => _configured(
        apiKey: const String.fromEnvironment('FIREBASE_PROD_API_KEY'),
        appId: const String.fromEnvironment('FIREBASE_PROD_APP_ID'),
        messagingSenderId: const String.fromEnvironment(
          'FIREBASE_PROD_MESSAGING_SENDER_ID',
        ),
        projectId: const String.fromEnvironment('FIREBASE_PROD_PROJECT_ID'),
        storageBucket: const String.fromEnvironment('FIREBASE_PROD_STORAGE_BUCKET'),
        authDomain: const String.fromEnvironment('FIREBASE_PROD_AUTH_DOMAIN'),
        iosBundleId: const String.fromEnvironment('FIREBASE_PROD_IOS_BUNDLE_ID'),
        measurementId: const String.fromEnvironment('FIREBASE_PROD_MEASUREMENT_ID'),
      ),
    };
  }

  static FirebaseOptions _configured({
    required String apiKey,
    required String appId,
    required String messagingSenderId,
    required String projectId,
    required String storageBucket,
    required String authDomain,
    required String iosBundleId,
    required String measurementId,
  }) {
    final requiredValues = <String, String>{
      'apiKey': apiKey,
      'appId': appId,
      'messagingSenderId': messagingSenderId,
      'projectId': projectId,
      'storageBucket': storageBucket,
    };
    final missing = requiredValues.entries
        .where((entry) => entry.value.trim().isEmpty)
        .map((entry) => entry.key)
        .toList();
    if (missing.isNotEmpty) {
      throw StateError('Missing Firebase configuration: ${missing.join(', ')}');
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
      authDomain: authDomain.isEmpty ? null : authDomain,
      iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }
}
