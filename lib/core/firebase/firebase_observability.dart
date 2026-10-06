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

  void installErrorHandlers() {
    FlutterError.onError = (details) {
      if (environment == AppEnvironment.dev) {
        FlutterError.presentError(details);
        return;
      }
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (environment == AppEnvironment.dev) {
        debugPrint('$error\n$stack');
        return false;
      }
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  Future<void> logEvent(String name) async {
    if (environment == AppEnvironment.dev || !_allowedEvents.contains(name)) return;
    await FirebaseAnalytics.instance.logEvent(name: name);
  }

  Future<void> recordNonFatal(Object error, StackTrace stack) async {
    if (environment == AppEnvironment.dev) return;
    await FirebaseCrashlytics.instance.recordError(error, stack);
  }
}
