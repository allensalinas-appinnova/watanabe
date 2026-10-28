import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../finance/presentation/providers/canonical_finance_providers.dart';
import '../../data/calendar/zoned_coach_calendar.dart';
import '../../domain/entities/coach_models.dart';
import '../../domain/repositories/coach_repository.dart';
import '../../domain/services/coach_notification_service.dart';
import '../../domain/usecases/coach_overview.dart';
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

final coachAmountsHiddenProvider = NotifierProvider<CoachAmountsHiddenNotifier, bool>(
  CoachAmountsHiddenNotifier.new,
);

class CoachAmountsHiddenNotifier extends Notifier<bool> {
  static const _key = 'coach_amounts_hidden';

  @override
  bool build() => getIt.isRegistered<SharedPreferences>()
      ? getIt<SharedPreferences>().getBool(_key) ?? false
      : false;

  Future<void> setHidden(bool value) async {
    if (getIt.isRegistered<SharedPreferences>()) {
      await getIt<SharedPreferences>().setBool(_key, value);
    }
    state = value;
  }
}

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

final coachRoutinePreferencesProvider = StreamProvider.family<CoachRoutinePreferences, String>(
  (ref, uid) =>
      ref.watch(coachRepositoryProvider)?.watchRoutinePreferences(uid) ??
      Stream.value(const CoachRoutinePreferences()),
);

final coachUnallocatedPaymentsProvider = StreamProvider.family<CoachUnallocatedPayments, String>(
  (ref, uid) =>
      ref.watch(coachRepositoryProvider)?.watchUnallocatedPayments(uid) ??
      Stream.value(const CoachUnallocatedPayments(operations: [])),
);

typedef CoachBudgetProgressRequest = ({String userId, String monthKey});
final coachBudgetProgressProvider =
    StreamProvider.family<List<CoachBudgetProgress>, CoachBudgetProgressRequest>(
      (ref, request) =>
          ref
              .watch(coachRepositoryProvider)
              ?.watchBudgetProgress(request.userId, request.monthKey) ??
          Stream.value(const <CoachBudgetProgress>[]),
    );

class CoachOverviewLoadState {
  const CoachOverviewLoadState({this.overview, this.loading = false, this.error = false});
  final CoachOverview? overview;
  final bool loading;
  final bool error;
}

final coachOverviewProvider = Provider.family<CoachOverviewLoadState, String>((ref, uid) {
  ref.watch(coachTickProvider);
  final routine = ref.watch(coachRoutineProvider);
  final profileState = ref.watch(canonicalUserProfileProvider(uid));
  final preferenceState = ref.watch(coachPreferencesProvider(uid));
  final routinePreferenceState = ref.watch(coachRoutinePreferencesProvider(uid));
  final completionState = ref.watch(coachCompletionsProvider(uid));
  final commitmentsState = ref.watch(debtCommitmentsProvider(uid));
  final linksState = ref.watch(debtCommitmentPaymentsProvider(uid));
  final unallocatedState = ref.watch(coachUnallocatedPaymentsProvider(uid));
  final pendingState = ref.watch(pendingOperationsProvider);
  final profile = profileState.valueOrNull;
  final now = routine.clock.now();
  final localNow = routine.calendar.local(now, profile?.timeZone ?? 'UTC');
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final monthKey =
      '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}';
  final weekMonday = DateTime(today.year, today.month, today.day - today.weekday + 1);
  final previousMonday = DateTime(weekMonday.year, weekMonday.month, weekMonday.day - 7);
  final reportRequest = (
    userId: uid,
    startAt: routine.calendar
        .at(
          profile?.timeZone ?? 'UTC',
          previousMonday.year,
          previousMonday.month,
          previousMonday.day,
        )
        .toUtc(),
    endAtExclusive: routine.calendar
        .at(
          profile?.timeZone ?? 'UTC',
          previousMonday.year,
          previousMonday.month,
          previousMonday.day + 7,
        )
        .toUtc(),
  );
  final reportState = ref.watch(coachReportProvider(reportRequest));
  final budgetState = ref.watch(coachBudgetProgressProvider((userId: uid, monthKey: monthKey)));
  final states = [
    profileState,
    preferenceState,
    routinePreferenceState,
    completionState,
    commitmentsState,
    linksState,
    unallocatedState,
    pendingState,
    reportState,
    budgetState,
  ];
  final error =
      profileState.hasError ||
      preferenceState.hasError ||
      routinePreferenceState.hasError ||
      completionState.hasError ||
      commitmentsState.hasError ||
      linksState.hasError ||
      unallocatedState.hasError ||
      pendingState.hasError ||
      reportState.hasError ||
      budgetState.hasError ||
      (profileState.hasValue && profileState.value == null);
  final loading = states.any((value) => value.isLoading || !value.hasValue);
  if (loading || error) return CoachOverviewLoadState(loading: loading && !error, error: error);
  final routinePreferences = routinePreferenceState.requireValue;
  final legacyPreferences = preferenceState.requireValue;
  final ownerRows = pendingState.requireValue.where((row) {
    try {
      final decoded = jsonDecode(row.payload) as Map<String, dynamic>;
      return decoded['ownerUserId'] == uid;
    } on Object {
      return false;
    }
  }).toList();
  final rejected = ownerRows.where((row) => row.status == 'rejected').length;
  final pending = ownerRows
      .where((row) => row.status == 'pending' || row.status == 'syncing')
      .length;
  final unallocated = unallocatedState.requireValue;
  final overview = const CoachOverviewCalculator().calculate(
    nowLocal: localNow,
    zone: profile?.timeZone ?? 'UTC',
    routine: routine,
    reminderPreferences: legacyPreferences,
    routinePreferences: routinePreferences,
    completions: completionState.requireValue,
    commitments: commitmentsState.requireValue,
    paymentLinks: linksState.requireValue,
    unallocatedPayments: unallocated.operations,
    budgetProgress: budgetState.requireValue,
    report: reportState.requireValue,
    rejectedSyncCount: rejected,
    pendingSyncCount: pending,
    paymentFreshness: unallocated.freshness,
  );
  return CoachOverviewLoadState(overview: overview);
});

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
