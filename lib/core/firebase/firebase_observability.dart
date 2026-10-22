import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../config/environment/app_environment.dart';

typedef CrashlyticsErrorReporter =
    Future<void> Function(
      Object exception,
      StackTrace stackTrace, {
      required bool fatal,
      required String reason,
    });

typedef CrashlyticsCollectionSetter = Future<void> Function(bool enabled);
typedef CrashlyticsUnsentReportsDeleter = Future<void> Function();

class FirebaseObservability {
  FirebaseObservability(
    this.environment, {
    this.useEmulators = false,
    CrashlyticsErrorReporter? errorReporter,
    CrashlyticsCollectionSetter? collectionSetter,
    CrashlyticsUnsentReportsDeleter? unsentReportsDeleter,
  }) : _errorReporter = errorReporter ?? _recordCrashlyticsError,
       _collectionSetter = collectionSetter ?? _setCrashlyticsCollectionEnabled,
       _unsentReportsDeleter = unsentReportsDeleter ?? _deleteUnsentCrashlyticsReports;

  static const _allowedEvents = <String>{
    'onboarding_completed',
    'account_created',
    'income_created',
    'expense_created',
    'budget_created',
    'transfer_created',
    'sync_rejected',
  };

  final AppEnvironment environment;
  final bool useEmulators;
  final CrashlyticsErrorReporter _errorReporter;
  final CrashlyticsCollectionSetter _collectionSetter;
  final CrashlyticsUnsentReportsDeleter _unsentReportsDeleter;

  static const allowedEventNames = _allowedEvents;

  bool get isCrashlyticsCollectionEnabled =>
      !useEmulators &&
      (environment == AppEnvironment.staging || environment == AppEnvironment.prod);

  /// Explicitly sets collection before any error handlers can report.
  Future<void> configureCrashlyticsCollection() async {
    try {
      await _collectionSetter(isCrashlyticsCollectionEnabled);
    } catch (_) {
      // Diagnostics must never prevent the app from starting or leak SDK data.
      if (environment == AppEnvironment.dev) {
        debugPrint('Crashlytics collection policy could not be applied.');
      }
    }
    if (!isCrashlyticsCollectionEnabled) {
      try {
        // Prevent local/emulator reports from being uploaded by a later run.
        await _unsentReportsDeleter();
      } catch (_) {
        if (environment == AppEnvironment.dev) {
          debugPrint('Local Crashlytics reports could not be cleared.');
        }
      }
    }
  }

  void installErrorHandlers() {
    FlutterError.onError = (details) {
      if (!isCrashlyticsCollectionEnabled) {
        FlutterError.presentError(details);
        return;
      }
      _recordSafely(
        TechnicalErrorCode.flutterUi,
        details.stack ?? StackTrace.current,
        fatal: true,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (!isCrashlyticsCollectionEnabled) {
        debugPrint('Unhandled platform error in local-only environment.');
        return false;
      }
      _recordSafely(TechnicalErrorCode.platform, stack, fatal: true);
      return true;
    };
  }

  Future<void> logEvent(String name) async {
    if (environment == AppEnvironment.dev || useEmulators || !_allowedEvents.contains(name)) {
      return;
    }
    await FirebaseAnalytics.instance.logEvent(name: name);
  }

  Future<void> recordNonFatal(TechnicalErrorCode code) async {
    if (!isCrashlyticsCollectionEnabled) return;
    await _recordSafely(code, StackTrace.current, fatal: false);
  }

  Future<void> _recordSafely(
    TechnicalErrorCode code,
    StackTrace stackTrace, {
    required bool fatal,
  }) async {
    try {
      await _errorReporter(
        SafeTechnicalFailure(code),
        stackTrace,
        fatal: fatal,
        reason: 'sanitized_technical_failure',
      );
    } catch (_) {
      // Crash reporting is best-effort. Never forward raw SDK exceptions.
    }
  }

  static Future<void> _recordCrashlyticsError(
    Object exception,
    StackTrace stackTrace, {
    required bool fatal,
    required String reason,
  }) => FirebaseCrashlytics.instance.recordError(
    exception,
    stackTrace,
    fatal: fatal,
    reason: reason,
  );

  static Future<void> _setCrashlyticsCollectionEnabled(bool enabled) =>
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);

  static Future<void> _deleteUnsentCrashlyticsReports() =>
      FirebaseCrashlytics.instance.deleteUnsentReports();
}

enum TechnicalErrorCode { flutterUi, platform, sync, firebaseRequest, bootstrap }

class SafeTechnicalFailure implements Exception {
  const SafeTechnicalFailure(this.code);

  final TechnicalErrorCode code;

  @override
  String toString() => 'technical_failure:${code.name}';
}
