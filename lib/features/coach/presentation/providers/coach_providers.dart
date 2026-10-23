import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../data/calendar/zoned_coach_calendar.dart';
import '../../domain/entities/coach_models.dart';
import '../../domain/repositories/coach_repository.dart';
import '../../domain/services/coach_notification_service.dart';
import '../../domain/usecases/coach_routine.dart';

final coachRepositoryProvider = Provider<CoachRepository?>(
  (ref) => getIt.isRegistered<CoachRepository>() ? getIt<CoachRepository>() : null,
);
final coachClockProvider = Provider<CoachClock>((ref) => const SystemCoachClock());
final coachCalendarProvider = Provider<CoachCalendar>((ref) => ZonedCoachCalendar());
final coachRoutineProvider = Provider<CoachRoutine>(
  (ref) => CoachRoutine(ref.watch(coachCalendarProvider), ref.watch(coachClockProvider)),
);
final coachNotificationServiceProvider = Provider<CoachNotificationService?>(
  (ref) =>
      getIt.isRegistered<CoachNotificationService>() ? getIt<CoachNotificationService>() : null,
);
final coachDeviceSettingsProvider = FutureProvider.family<CoachDeviceSettings, String>(
  (ref, uid) async =>
      await ref.watch(coachNotificationServiceProvider)?.readDeviceSettings(uid) ??
      const CoachDeviceSettings(),
);
final coachPermissionProvider = FutureProvider<CoachPermission>(
  (ref) async =>
      await ref.watch(coachNotificationServiceProvider)?.permission() ??
      CoachPermission.unsupported,
);

final coachSchedulingIssueProvider = NotifierProvider<CoachSchedulingIssue, bool>(
  CoachSchedulingIssue.new,
);

class CoachSchedulingIssue extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool failed) {
    if (state != failed) state = failed;
  }
}

final coachRescheduleProvider = NotifierProvider<CoachReschedule, int>(CoachReschedule.new);

class CoachReschedule extends Notifier<int> {
  @override
  int build() => 0;
  void retry() => state++;
}

final coachTickProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(coachClockProvider);
  yield clock.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => clock.now());
});

final coachPreferencesProvider = StreamProvider.family<CoachPreferences, String>(
  (ref, uid) =>
      ref.watch(coachRepositoryProvider)?.watchPreferences(uid) ??
      Stream.value(const CoachPreferences()),
);

final coachWriteFailureProvider = StreamProvider.family<CoachWriteFailure, String>(
  (ref, uid) => ref.watch(coachRepositoryProvider)?.watchWriteFailures(uid) ?? const Stream.empty(),
);

typedef CoachCompletionRequest = ({String userId, CoachReviewKind kind, String periodKey});
final coachSelectedCompletionProvider = StreamProvider.autoDispose
    .family<CoachCompletion?, CoachCompletionRequest>(
      (ref, request) =>
          ref
              .watch(coachRepositoryProvider)
              ?.watchCompletion(request.userId, kind: request.kind, periodKey: request.periodKey) ??
          Stream.value(null),
    );

final coachCompletionsProvider = StreamProvider.family<List<CoachCompletion>, String>((ref, uid) {
  ref.watch(coachTickProvider.select((value) => value.value?.day));
  final since = ref.watch(coachClockProvider).now().subtract(const Duration(days: 42));
  return ref.watch(coachRepositoryProvider)?.watchCompletions(uid, since: since) ??
      Stream.value(const []);
});

typedef CoachReportRequest = ({String userId, DateTime startAt, DateTime endAtExclusive});
final coachReportChangesProvider = StreamProvider.autoDispose.family<int, CoachReportRequest>((
  ref,
  request,
) async* {
  final repository = ref.watch(coachRepositoryProvider);
  if (repository == null) return;
  var revision = 0;
  await for (final _ in repository.watchReportChanges(
    request.userId,
    startAt: request.startAt,
    endAtExclusive: request.endAtExclusive,
  )) {
    yield ++revision;
  }
});

final coachReportProvider = FutureProvider.autoDispose
    .family<CoachPeriodReport, CoachReportRequest>((ref, request) async {
      final repository = ref.watch(coachRepositoryProvider);
      if (repository == null) throw StateError('coach-unavailable');
      ref.watch(
        coachReportChangesProvider(request).select((value) => (value.value ?? 0, value.hasError)),
      );
      final result = await repository.loadReport(
        request.userId,
        startAt: request.startAt,
        endAtExclusive: request.endAtExclusive,
      );
      return result.match(
        (failure) => throw StateError(failure.technicalCode ?? 'coach-read-failed'),
        (report) => report,
      );
    });
