import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../config/environment/app_environment.dart';

class FirebaseObservability {
  FirebaseObservability(this.environment);

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

  static const allowedEventNames = _allowedEvents;

  void installErrorHandlers() {
    FlutterError.onError = (details) {
      if (environment == AppEnvironment.dev) {
        FlutterError.presentError(details);
        return;
      }
      FirebaseCrashlytics.instance.recordError(
        const SafeTechnicalFailure(TechnicalErrorCode.flutterUi),
        details.stack ?? StackTrace.current,
        fatal: true,
        reason: 'sanitized_technical_failure',
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (environment == AppEnvironment.dev) {
        debugPrint('$error\n$stack');
        return false;
      }
      FirebaseCrashlytics.instance.recordError(
        const SafeTechnicalFailure(TechnicalErrorCode.platform),
        stack,
        fatal: true,
        reason: 'sanitized_technical_failure',
      );
      return true;
    };
  }

  Future<void> logEvent(String name) async {
    if (environment == AppEnvironment.dev || !_allowedEvents.contains(name)) return;
    await FirebaseAnalytics.instance.logEvent(name: name);
  }

  Future<void> recordNonFatal(TechnicalErrorCode code) async {
    if (environment == AppEnvironment.dev) return;
    await FirebaseCrashlytics.instance.recordError(
      SafeTechnicalFailure(code),
      StackTrace.current,
      reason: 'sanitized_technical_failure',
    );
  }
}

enum TechnicalErrorCode { flutterUi, platform, sync, firebaseRequest, bootstrap }

class SafeTechnicalFailure implements Exception {
  const SafeTechnicalFailure(this.code);

  final TechnicalErrorCode code;

  @override
  String toString() => 'technical_failure:${code.name}';
}
