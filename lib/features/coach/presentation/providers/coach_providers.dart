import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/offline/pending_operation_queue.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../commitments/domain/commitment_repository.dart';
import '../../../commitments/domain/debt_commitment.dart';
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

typedef CoachOverviewDeadlineRequest = ({String userId, int attempt});

final coachOverviewRetryCountProvider =
    NotifierProvider.family<CoachOverviewRetryCount, int, String>(
      (_) => CoachOverviewRetryCount(),
    );

class CoachOverviewRetryCount extends Notifier<int> {
  @override
  int build() => 0;

  void retry() => state++;
}

final coachOverviewDeadlineProvider = FutureProvider.autoDispose
    .family<bool, CoachOverviewDeadlineRequest>((ref, request) async {
      final completed = Completer<bool>();
      final timer = Timer(const Duration(seconds: 8), () => completed.complete(true));
      ref.onDispose(timer.cancel);
      return completed.future;
    });

class CoachOverviewLoadState {
  const CoachOverviewLoadState({
    this.overview,
    this.loading = false,
    this.error = false,
    this.incomplete = false,
    this.actionIncomplete = false,
    this.paymentsIncomplete = false,
    this.insightsIncomplete = false,
  });
  final CoachOverview? overview;
  final bool loading;
  final bool error;
  final bool incomplete;
  final bool actionIncomplete;
  final bool paymentsIncomplete;
  final bool insightsIncomplete;
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
  final nextMonthDate = DateTime(today.year, today.month + 1);
  final nextMonthKey =
      '${nextMonthDate.year.toString().padLeft(4, '0')}-${nextMonthDate.month.toString().padLeft(2, '0')}';
  final planningCurrentState = ref.watch(
    planningAgendaEntriesProvider((userId: uid, monthKey: monthKey)),
  );
  final planningNextState = ref.watch(
    planningAgendaEntriesProvider((userId: uid, monthKey: nextMonthKey)),
  );

  // The weekly report affects insights, but must not hold up the next action.
  final actionStates = [
    profileState,
    preferenceState,
    routinePreferenceState,
    completionState,
    commitmentsState,
    linksState,
    unallocatedState,
    pendingState,
    budgetState,
    planningCurrentState,
    planningNextState,
  ];
  final actionSourcesSettled = actionStates.every((value) => value.hasValue || value.hasError);
  final retryAttempt = ref.watch(coachOverviewRetryCountProvider(uid));
  final timedOut = actionSourcesSettled
      ? false
      : ref
                .watch(
                  coachOverviewDeadlineProvider((userId: uid, attempt: retryAttempt)),
                )
                .valueOrNull ==
            true;
  if (!actionSourcesSettled && !timedOut) {
    return const CoachOverviewLoadState(loading: true);
  }

  final availability = CoachOverviewAvailability(
    profile: profile != null,
    reminderPreferences: preferenceState.hasValue,
    routinePreferences: routinePreferenceState.hasValue,
    completions: completionState.hasValue,
    commitments: commitmentsState.hasValue,
    paymentLinks: linksState.hasValue,
    unallocatedPayments: unallocatedState.hasValue,
    budgetProgress: budgetState.hasValue,
    pendingOperations: pendingState.hasValue,
    report: reportState.hasValue,
    planningEntries: planningCurrentState.hasValue && planningNextState.hasValue,
  );
  final routinePreferences = routinePreferenceState.valueOrNull ?? const CoachRoutinePreferences();
  final legacyPreferences = preferenceState.valueOrNull ?? const CoachPreferences();
  final completions = completionState.valueOrNull ?? const <CoachCompletion>[];
  final commitments = commitmentsState.valueOrNull ?? const <DebtCommitment>[];
  final paymentLinks = linksState.valueOrNull ?? const <DebtCommitmentPaymentLink>[];
  final unallocated =
      unallocatedState.valueOrNull ?? const CoachUnallocatedPayments(operations: []);
  final budgets = budgetState.valueOrNull ?? const <CoachBudgetProgress>[];
  final report =
      reportState.valueOrNull ??
      CoachPeriodReport(
        startAt: reportRequest.startAt,
        endAtExclusive: reportRequest.endAtExclusive,
        operations: const [],
        freshness: CoachFreshness.cached,
      );
  final ownerRows = (pendingState.valueOrNull ?? const <PendingOperation>[]).where((row) {
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
  final overview = const CoachOverviewCalculator().calculate(
    nowLocal: localNow,
    zone: profile?.timeZone ?? 'UTC',
    routine: routine,
    reminderPreferences: legacyPreferences,
    routinePreferences: routinePreferences,
    completions: completions,
    commitments: commitments,
    paymentLinks: paymentLinks,
    unallocatedPayments: unallocated.operations,
    budgetProgress: budgets,
    report: report,
    rejectedSyncCount: rejected,
    pendingSyncCount: pending,
    paymentFreshness: unallocated.freshness,
    plannedExpenses: const [],
    attentionEntries: ref.watch(planningAttentionProvider(uid)).entries,
    availability: availability,
  );
  final actionIncomplete =
      ref.watch(planningAttentionProvider(uid)).incomplete ||
      !availability.actionSources ||
      actionStates.any((value) => value.isLoading || value.hasError || !value.hasValue);
  final paymentsIncomplete =
      !availability.paymentItems ||
      commitmentsState.isLoading ||
      commitmentsState.hasError ||
      linksState.isLoading ||
      linksState.hasError ||
      unallocatedState.isLoading ||
      unallocatedState.hasError;
  final insightsIncomplete =
      !availability.weeklyReport || reportState.isLoading || reportState.hasError;
  final error = actionStates.every((value) => value.hasError && !value.hasValue);
  return CoachOverviewLoadState(
    overview: overview,
    error: error,
    incomplete: actionIncomplete || paymentsIncomplete || insightsIncomplete,
    actionIncomplete: actionIncomplete,
    paymentsIncomplete: paymentsIncomplete,
    insightsIncomplete: insightsIncomplete,
  );
});

/// Invalidates every input used by the shared Home and Coach recommendation.
void retryCoachOverview(WidgetRef ref, String uid) {
  ref.read(coachOverviewRetryCountProvider(uid).notifier).retry();
  ref
    ..invalidate(canonicalUserProfileProvider(uid))
    ..invalidate(coachPreferencesProvider(uid))
    ..invalidate(coachRoutinePreferencesProvider(uid))
    ..invalidate(coachCompletionsProvider(uid))
    ..invalidate(debtCommitmentsProvider(uid))
    ..invalidate(debtCommitmentPaymentsProvider(uid))
    ..invalidate(coachUnallocatedPaymentsProvider(uid))
    ..invalidate(pendingOperationsProvider)
    ..invalidate(coachReportProvider)
    ..invalidate(coachReportChangesProvider)
    ..invalidate(coachBudgetProgressProvider)
    ..invalidate(planningAgendaEntriesProvider)
    ..invalidate(planningFollowUpsProvider(uid))
    ..invalidate(coachTickProvider)
    ..invalidate(coachOverviewProvider(uid));
}

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
