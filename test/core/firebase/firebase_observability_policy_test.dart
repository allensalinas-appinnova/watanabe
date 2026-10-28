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
        'coach_opened',
        'coach_action_opened',
        'coach_routine_configured',
        'coach_daily_review_completed',
        'coach_weekly_review_completed',
      },
    );
  });

  test('Performance collection is enabled only for staging/prod outside Emulator', () async {
    for (final environment in AppEnvironment.values) {
      for (final useEmulators in [false, true]) {
        bool? enabled;
        final client = _FakePerformanceClient(onCollectionEnabled: (value) => enabled = value);
        final observability = FirebaseObservability(
          environment,
          useEmulators: useEmulators,
          performanceTraceClient: client,
        );
        await observability.configurePerformanceCollection();
        final expected =
            !useEmulators &&
            (environment == AppEnvironment.staging || environment == AppEnvironment.prod);
        expect(observability.isPerformanceCollectionEnabled, expected);
        expect(enabled, expected);
      }
    }
  });

  test('disabled Performance policy never starts a trace and preserves operation result', () async {
    final client = _FakePerformanceClient();
    final observability = FirebaseObservability(
      AppEnvironment.dev,
      performanceTraceClient: client,
    );
    await observability.configurePerformanceCollection();

    final result = await observability.tracePerformance(
      PerformanceTraceName.operationSave,
      () async => 'saved',
    );

    expect(result, 'saved');
    expect(client.startedNames, isEmpty);
  });

  test('enabled traces stop on both success and failure without changing the outcome', () async {
    final client = _FakePerformanceClient();
    final observability = FirebaseObservability(
      AppEnvironment.staging,
      performanceTraceClient: client,
    );
    await observability.configurePerformanceCollection();

    expect(
      await observability.tracePerformance(
        PerformanceTraceName.homeInitialLoad,
        () async => 42,
      ),
      42,
    );
    await expectLater(
      observability.tracePerformance<void>(
        PerformanceTraceName.budgetSave,
        () async => throw StateError('private budget data'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(client.startedNames, ['home_initial_load', 'budget_save']);
    expect(client.spans.map((span) => span.stopCount), [1, 1]);
  });

  test('Performance SDK failures do not mask measured action failures', () async {
    final client = _FakePerformanceClient(failStart: true, failStop: true);
    final observability = FirebaseObservability(
      AppEnvironment.prod,
      performanceTraceClient: client,
    );
    await observability.configurePerformanceCollection();

    expect(
      await observability.tracePerformance(
        PerformanceTraceName.operationSave,
        () async => 'original result',
      ),
      'original result',
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

class _FakePerformanceClient implements PerformanceTraceClient {
  _FakePerformanceClient({
    this.onCollectionEnabled,
    this.failStart = false,
    this.failStop = false,
  });

  final void Function(bool)? onCollectionEnabled;
  final bool failStart;
  final bool failStop;
  final startedNames = <String>[];
  final spans = <_FakePerformanceSpan>[];

  @override
  Future<void> setCollectionEnabled(bool enabled) async => onCollectionEnabled?.call(enabled);

  @override
  Future<PerformanceTraceSpan> startTrace(String name) async {
    if (failStart) throw StateError('SDK error');
    startedNames.add(name);
    final span = _FakePerformanceSpan(failStop: failStop);
    spans.add(span);
    return span;
  }
}

class _FakePerformanceSpan implements PerformanceTraceSpan {
  _FakePerformanceSpan({required this.failStop});

  final bool failStop;
  int stopCount = 0;

  @override
  Future<void> stop() async {
    stopCount++;
    if (failStop) throw StateError('SDK error');
  }
}
