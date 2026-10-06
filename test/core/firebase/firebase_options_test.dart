import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/firebase/firebase_options.dart';

void main() {
  group('AppFirebaseOptions emulator configuration', () {
    final originalTargetPlatform = debugDefaultTargetPlatformOverride;

    tearDown(() {
      debugDefaultTargetPlatformOverride = originalTargetPlatform;
    });

    test('uses an Android-shaped app ID on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final options = AppFirebaseOptions.forEnvironment(
        AppEnvironment.dev,
        useEmulators: true,
      );

      expect(options.appId, startsWith('1:1234567890:android:'));
      expect(options.projectId, 'demo-clearbudget');
      expect(options.apiKey, matches(RegExp(r'^A.{38}$')));
    });

    test('uses an Apple-shaped app ID on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final options = AppFirebaseOptions.forEnvironment(
        AppEnvironment.dev,
        useEmulators: true,
      );

      expect(options.appId, startsWith('1:1234567890:ios:'));
      expect(options.projectId, 'demo-clearbudget');
      expect(options.apiKey, matches(RegExp(r'^A.{38}$')));
    });
  });

  test('requires real Firebase values when emulator mode is disabled', () {
    expect(
      () => AppFirebaseOptions.forEnvironment(AppEnvironment.dev),
      throwsA(isA<StateError>()),
    );
  });

  test('does not permit emulator mode outside development', () {
    expect(
      () => AppEnvironment.staging.validate(useEmulators: true, isRelease: false),
      throwsA(isA<StateError>()),
    );
    expect(
      () => AppEnvironment.dev.validate(useEmulators: true, isRelease: true),
      throwsA(isA<StateError>()),
    );
  });
}
