import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/firebase/firebase_observability.dart';

void main() {
  final previousFlutterErrorHandler = FlutterError.onError;
  final previousPlatformErrorHandler = PlatformDispatcher.instance.onError;

  tearDown(() {
    FlutterError.onError = previousFlutterErrorHandler;
    PlatformDispatcher.instance.onError = previousPlatformErrorHandler;
  });

  test('product analytics event names are allowlisted without payloads', () {
    expect(
      FirebaseObservability.allowedEventNames,
      {
        'onboarding_completed',
        'account_created',
        'income_created',
        'expense_created',
        'budget_created',
        'transfer_created',
        'sync_rejected',
      },
    );
  });

  test('Crashlytics collection is enabled only for staging/prod, not Emulator', () async {
    for (final environment in AppEnvironment.values) {
      for (final useEmulators in [false, true]) {
        bool? enabled;
        var deletedUnsentReports = false;
        final observability = FirebaseObservability(
          environment,
          useEmulators: useEmulators,
          collectionSetter: (value) async {
            enabled = value;
          },
          unsentReportsDeleter: () async {
            deletedUnsentReports = true;
          },
        );

        await observability.configureCrashlyticsCollection();

        final expected =
            !useEmulators &&
            (environment == AppEnvironment.staging || environment == AppEnvironment.prod);
        expect(observability.isCrashlyticsCollectionEnabled, expected);
        expect(enabled, expected);
        expect(deletedUnsentReports, !expected);
      }
    }
  });

  test('fatal Flutter and platform errors report only safe technical codes', () async {
    final reports = <({Object exception, bool fatal, String reason})>[];
    final observability = FirebaseObservability(
      AppEnvironment.staging,
      errorReporter: (exception, _, {required fatal, required reason}) async {
        reports.add((exception: exception, fatal: fatal, reason: reason));
      },
    );
    await observability.configureCrashlyticsCollection();
    observability.installErrorHandlers();

    const privateMessage = 'COP 987654321 account-secret';
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError(privateMessage),
        stack: StackTrace.current,
      ),
    );
    final handled = PlatformDispatcher.instance.onError!(
      StateError(privateMessage),
      StackTrace.current,
    );

    expect(handled, isTrue);
    expect(reports, hasLength(2));
    expect(reports[0].exception, isA<SafeTechnicalFailure>());
    expect(
      (reports[0].exception as SafeTechnicalFailure).code,
      TechnicalErrorCode.flutterUi,
    );
    expect(
      (reports[1].exception as SafeTechnicalFailure).code,
      TechnicalErrorCode.platform,
    );
    expect(reports.every((report) => report.fatal), isTrue);
    expect(reports.every((report) => report.reason == 'sanitized_technical_failure'), isTrue);
    expect(
      reports.map((report) => report.exception.toString()).join(),
      isNot(contains(privateMessage)),
    );
  });

  test('non-fatal reports only the typed code and is suppressed in dev/emulator', () async {
    final reports = <Object>[];
    final prod = FirebaseObservability(
      AppEnvironment.prod,
      errorReporter: (exception, _, {required fatal, required reason}) async {
        reports.add(exception);
        expect(fatal, isFalse);
        expect(reason, 'sanitized_technical_failure');
      },
    );
    final dev = FirebaseObservability(
      AppEnvironment.dev,
      errorReporter: (exception, _, {required fatal, required reason}) async {
        reports.add(exception);
      },
    );
    final emulator = FirebaseObservability(
      AppEnvironment.staging,
      useEmulators: true,
      errorReporter: (exception, _, {required fatal, required reason}) async {
        reports.add(exception);
      },
    );

    await prod.recordNonFatal(TechnicalErrorCode.firebaseRequest);
    await dev.recordNonFatal(TechnicalErrorCode.sync);
    await emulator.recordNonFatal(TechnicalErrorCode.bootstrap);

    expect(reports, hasLength(1));
    expect(reports.single, isA<SafeTechnicalFailure>());
    expect(
      (reports.single as SafeTechnicalFailure).code,
      TechnicalErrorCode.firebaseRequest,
    );
  });

  test('technical errors serialize only an allowlisted code', () {
    const error = SafeTechnicalFailure(TechnicalErrorCode.sync);

    expect(error.toString(), 'technical_failure:sync');
    expect(error.toString(), isNot(contains('COP')));
    expect(error.toString(), isNot(contains('amount')));
  });
}
