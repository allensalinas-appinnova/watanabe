import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import '../../config/environment/app_environment.dart';
import 'firebase_bootstrap.dart';

typedef CrashlyticsErrorReporter =
    Future<void> Function(
      Object exception,
      StackTrace stackTrace, {
      required bool fatal,
      required String reason,
    });

typedef CrashlyticsCollectionSetter = Future<void> Function(bool enabled);
typedef CrashlyticsUnsentReportsDeleter = Future<void> Function();

abstract interface class PerformanceTraceSpan {
  Future<void> stop();
}

abstract interface class PerformanceTraceClient {
  Future<void> setCollectionEnabled(bool enabled);
  Future<PerformanceTraceSpan> startTrace(String name);
}

enum PerformanceTraceName {
  appStartup('app_startup'),
  homeInitialLoad('home_initial_load'),
  activityReportPreparation('activity_report_preparation'),
  operationSave('operation_save'),
  budgetSave('budget_save');

  const PerformanceTraceName(this.value);
  final String value;
}

class FirebaseObservability {
  FirebaseObservability(
    this.environment, {
    this.useEmulators = false,
    CrashlyticsErrorReporter? errorReporter,
    CrashlyticsCollectionSetter? collectionSetter,
    CrashlyticsUnsentReportsDeleter? unsentReportsDeleter,
    PerformanceTraceClient? performanceTraceClient,
  }) : _errorReporter = errorReporter ?? _recordCrashlyticsError,
       _collectionSetter = collectionSetter ?? _setCrashlyticsCollectionEnabled,
       _unsentReportsDeleter = unsentReportsDeleter ?? _deleteUnsentCrashlyticsReports,
       _performanceTraceClient = performanceTraceClient ?? _FirebasePerformanceTraceClient();

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
  final PerformanceTraceClient _performanceTraceClient;
  bool _performanceConfigured = false;

  static const allowedEventNames = _allowedEvents;

  bool get isCrashlyticsCollectionEnabled =>
      !useEmulators &&
      (environment == AppEnvironment.staging || environment == AppEnvironment.prod);

  bool get isPerformanceCollectionEnabled => isCrashlyticsCollectionEnabled;

  /// Applies the environment policy before the app starts measuring flows.
  Future<void> configurePerformanceCollection() async {
    if (kIsWeb && !isPerformanceCollectionEnabled) {
      // Do not initialize the web Performance SDK at all in dev/Emulator.
      _performanceConfigured = true;
      return;
    }
    try {
      await _performanceTraceClient.setCollectionEnabled(isPerformanceCollectionEnabled);
      _performanceConfigured = true;
    } catch (_) {
      // Performance monitoring is optional and must never block app startup.
      _performanceConfigured = false;
      if (environment == AppEnvironment.dev) {
        debugPrint('Firebase Performance policy could not be applied.');
      }
    }
  }

  /// Runs [action] unchanged if tracing is unavailable; only duration is sent.
  Future<T> tracePerformance<T>(
    PerformanceTraceName name,
    Future<T> Function() action,
  ) async {
    if (!isPerformanceCollectionEnabled || !_performanceConfigured) return action();
    PerformanceTraceSpan? span;
    try {
      span = await _performanceTraceClient.startTrace(name.value);
    } catch (_) {
      // Tracing failures must not alter the result of the measured operation.
    }
    if (span == null) return action();
    try {
      return await action();
    } finally {
      try {
        await span.stop();
      } catch (_) {
        // Trace shutdown is best-effort as well.
      }
    }
  }

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

class _FirebasePerformanceTraceClient implements PerformanceTraceClient {
  FirebasePerformance get _performance =>
      FirebasePerformance.instanceFor(app: FirebaseBootstrap.app);

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _performance.setPerformanceCollectionEnabled(enabled);

  @override
  Future<PerformanceTraceSpan> startTrace(String name) async {
    final trace = _performance.newTrace(name);
    await trace.start();
    return _FirebasePerformanceTraceSpan(trace);
  }
}

class _FirebasePerformanceTraceSpan implements PerformanceTraceSpan {
  const _FirebasePerformanceTraceSpan(this._trace);

  final Trace _trace;

  @override
  Future<void> stop() => _trace.stop();
}

enum TechnicalErrorCode { flutterUi, platform, sync, firebaseRequest, bootstrap }

class SafeTechnicalFailure implements Exception {
  const SafeTechnicalFailure(this.code);

  final TechnicalErrorCode code;

  @override
  String toString() => 'technical_failure:${code.name}';
}
