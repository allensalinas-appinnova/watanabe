import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/firebase/firebase_observability.dart';
import '../../../../core/offline/pending_operation_queue.dart';
import '../../../../core/offline/pending_operation_sync_service.dart';
import '../../../../core/offline/sync_state.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/request_id.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../commitments/domain/commitment_repository.dart';
import '../../../commitments/domain/debt_commitment.dart';
import '../../domain/entities/activity_report.dart';
import '../../domain/entities/appearance_preferences.dart';
import '../../domain/entities/balance_adjustment.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_command_failure.dart';
import '../../domain/entities/budget_item.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/entities/operation_page.dart';
import '../../domain/entities/planning_agenda_entry.dart';
import '../../domain/entities/planning_follow_up.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../../domain/repositories/planning_follow_up_repository.dart';

final canonicalFinanceRepositoryProvider = Provider<CanonicalFinanceRepository>(
  (ref) => getIt<CanonicalFinanceRepository>(),
);

final debtCommitmentsProvider = StreamProvider.family<List<DebtCommitment>, String>(
  (ref, userId) => getIt.isRegistered<CommitmentRepository>()
      ? getIt<CommitmentRepository>().watch(userId)
      : Stream.value(const <DebtCommitment>[]),
);

final planningFollowUpRepositoryProvider = Provider<PlanningFollowUpRepository?>(
  (ref) =>
      getIt.isRegistered<PlanningFollowUpRepository>() ? getIt<PlanningFollowUpRepository>() : null,
);

final planningFollowUpsProvider = StreamProvider.family<PlanningFollowUpSnapshot, String>(
  (ref, uid) =>
      ref.watch(planningFollowUpRepositoryProvider)?.watch(uid) ??
      Stream.value(const PlanningFollowUpSnapshot()),
);

final planningClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final planningTickProvider = StreamProvider<DateTime>((ref) async* {
  yield ref.read(planningClockProvider)();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => ref.read(planningClockProvider)());
});
final planningTodayProvider = Provider.family<DateTime, String>((ref, uid) {
  final now = ref.watch(planningTickProvider).valueOrNull ?? ref.read(planningClockProvider)();
  final local = _planningLocalNow(
    now,
    ref.watch(canonicalUserProfileProvider(uid)).valueOrNull?.timeZone,
  );
  return DateTime(local.year, local.month, local.day);
});

class PlanningAttention {
  const PlanningAttention({required this.entries, required this.incomplete, required this.loading});
  final List<PlanningAgendaEntry> entries;
  final bool incomplete;
  final bool loading;
}

final planningAttentionProvider = Provider.family<PlanningAttention, String>((ref, uid) {
  final today = ref.watch(planningTodayProvider(uid));
  final current = DateFormatMonth.key(today);
  final next = DateFormatMonth.key(DateTime(today.year, today.month + 1));
  final followUps = ref.watch(planningFollowUpsProvider(uid));
  final months = {
    current,
    next,
    for (final item in followUps.valueOrNull?.items ?? <PlanningFollowUp>[])
      if (item.state == PlanningFollowUpState.snoozed &&
          item.remindOn != null &&
          item.remindOn!.compareTo(DateFormatMonth.day(today)) <= 0)
        item.source.monthKey,
  };
  final sources = [
    for (final month in months)
      ref.watch(planningAgendaEntriesProvider((userId: uid, monthKey: month))),
  ];
  final end = DateTime(today.year, today.month, today.day + 7);
  final entries = <String, PlanningAgendaEntry>{};
  for (final state in sources) {
    for (final entry in state.valueOrNull ?? <PlanningAgendaEntry>[]) {
      if (entry.kind == PlanningEntryKind.income || !entry.needsAttention(today)) continue;
      final returned =
          entry.followUpState == PlanningFollowUpState.snoozed &&
          entry.remindOn != null &&
          entry.remindOn!.compareTo(DateFormatMonth.day(today)) <= 0;
      if (entry.monthKey == current ||
          !entry.date.isBefore(today) && !entry.date.isAfter(end) ||
          returned) {
        entries[entry.id] = entry;
      }
    }
  }
  final sorted = entries.values.toList()
    ..sort((a, b) {
      final date = a.date.compareTo(b.date);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
  return PlanningAttention(
    entries: List.unmodifiable(sorted),
    incomplete:
        followUps.isLoading ||
        followUps.hasError ||
        followUps.valueOrNull?.fromCache == true ||
        followUps.valueOrNull?.pendingWrites == true ||
        sources.any((item) => item.isLoading || item.hasError),
    loading: sources.every((item) => !item.hasValue && !item.hasError) && !followUps.hasError,
  );
});

abstract final class DateFormatMonth {
  static String key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
  static String day(DateTime date) => '${key(date)}-${date.day.toString().padLeft(2, '0')}';
}

void retryPlanning(WidgetRef ref, String uid) {
  ref
    ..invalidate(planningFollowUpsProvider(uid))
    ..invalidate(planningAgendaEntriesProvider)
    ..invalidate(canonicalBudgetsProvider)
    ..invalidate(canonicalFinanceRepositoryItemsProvider)
    ..invalidate(debtCommitmentsProvider(uid))
    ..invalidate(debtCommitmentPaymentsProvider(uid));
}

final debtCommitmentPaymentsProvider =
    StreamProvider.family<List<DebtCommitmentPaymentLink>, String>(
      (ref, userId) => getIt.isRegistered<CommitmentRepository>()
          ? getIt<CommitmentRepository>().watchPayments(userId)
          : Stream.value(const <DebtCommitmentPaymentLink>[]),
    );

final planningMonthProvider = NotifierProvider.family<PlanningMonthNotifier, DateTime, String>(
  PlanningMonthNotifier.new,
);

bool _planningTimeZonesInitialized = false;

DateTime _planningLocalNow(DateTime instant, String? zone) {
  if (zone == null || zone.isEmpty) return instant;
  try {
    if (!_planningTimeZonesInitialized) {
      timezone_data.initializeTimeZones();
      _planningTimeZonesInitialized = true;
    }
    return timezone.TZDateTime.from(instant.toUtc(), timezone.getLocation(zone));
  } on Object {
    return instant;
  }
}

class PlanningMonthNotifier extends Notifier<DateTime> {
  PlanningMonthNotifier(this.userId);

  final String userId;

  @override
  DateTime build() {
    final profileProvider = canonicalUserProfileProvider(userId);
    final profileState = ref.read(profileProvider);
    ref.listen(profileProvider, (previous, next) {
      if (previous?.valueOrNull != null || next.valueOrNull == null) return;
      final deviceNow = DateTime.now();
      final expectedDeviceMonth = DateTime(deviceNow.year, deviceNow.month);
      if (state.year != expectedDeviceMonth.year || state.month != expectedDeviceMonth.month) {
        return;
      }
      final zonedNow = _planningLocalNow(deviceNow, next.valueOrNull?.timeZone);
      state = DateTime(zonedNow.year, zonedNow.month);
    });
    final profile = profileState.valueOrNull;
    final now = _planningLocalNow(DateTime.now(), profile?.timeZone);
    return DateTime(now.year, now.month);
  }

  void select(DateTime month) => state = DateTime(month.year, month.month);
  void current() {
    final profile = ref.read(canonicalUserProfileProvider(userId)).valueOrNull;
    final now = _planningLocalNow(DateTime.now(), profile?.timeZone);
    state = DateTime(now.year, now.month);
  }
}

class PlanningBudgetTotals {
  const PlanningBudgetTotals({required this.income, required this.expense, required this.debt});
  final Map<String, int> income;
  final Map<String, int> expense;
  final Map<String, int> debt;
}

final planningBudgetTotalsProvider = FutureProvider.autoDispose
    .family<PlanningBudgetTotals, ({String userId, String monthKey})>((ref, input) async {
      final repository = ref.watch(canonicalFinanceRepositoryProvider);
      final budgets = await repository.watchBudgets(input.userId, input.monthKey).first;
      final income = <String, int>{};
      final expense = <String, int>{};
      await Future.wait(
        budgets.where((budget) => budget.status == 'active').map((budget) async {
          final items = await repository.watchBudgetItems(input.userId, budget.id).first;
          final amount = items
              .where((item) => item.isActive)
              .fold<int>(0, (sum, item) => sum + item.amountMinor);
          final totals = budget.flowType.name == 'income' ? income : expense;
          totals[budget.currency] = (totals[budget.currency] ?? 0) + amount;
        }),
      );
      final debt = <String, int>{};
      if (getIt.isRegistered<CommitmentRepository>()) {
        final commitments = await getIt<CommitmentRepository>().watch(input.userId).first;
        for (final original in commitments) {
          final commitment = original.forMonth(input.monthKey);
          if (commitment.dueDateFor(input.monthKey) == null ||
              commitment.isSkipped(input.monthKey)) {
            continue;
          }
          debt.update(
            commitment.currency,
            (amount) => amount + commitment.amountMinor,
            ifAbsent: () => commitment.amountMinor,
          );
        }
      }
      return PlanningBudgetTotals(income: income, expense: expense, debt: debt);
    });

final planningAgendaEntriesProvider = FutureProvider.autoDispose
    .family<List<PlanningAgendaEntry>, ({String userId, String monthKey})>((ref, input) async {
      final budgets = await ref.watch(canonicalBudgetsProvider(input).future);
      final followUps = await ref.watch(planningFollowUpsProvider(input.userId).future);
      final followUpsById = {for (final item in followUps.items) item.entryId: item};
      final entries = <PlanningAgendaEntry>[];
      for (final budget in budgets.where((item) => item.status == 'active')) {
        final itemsKey = (userId: input.userId, budgetId: budget.id);
        final items = await ref.watch(canonicalFinanceRepositoryItemsProvider(itemsKey).future);
        for (final item in items.where((item) => item.isActive)) {
          final month = DateTime.parse('${budget.monthKey}-01');
          final lastDay = DateTime(month.year, month.month + 1, 0).day;
          final date = DateTime(month.year, month.month, item.dayOfMonth.clamp(1, lastDay));
          final pending = (item.amountMinor - item.actualAmountMinor).clamp(0, item.amountMinor);
          entries.add(
            PlanningAgendaEntry(
              id: 'budget:${budget.id}:${item.id}',
              kind: budget.flowType.name == 'income'
                  ? PlanningEntryKind.income
                  : PlanningEntryKind.expense,
              date: date,
              title: item.description,
              currency: budget.currency,
              plannedMinor: item.amountMinor,
              recordedMinor: item.actualAmountMinor,
              pendingMinor: pending,
              monthKey: budget.monthKey,
              budgetId: budget.id,
              itemId: item.id,
              followUpState:
                  followUpsById['budget:${budget.id}:${item.id}']?.state ??
                  PlanningFollowUpState.open,
              followUpVersion: followUpsById['budget:${budget.id}:${item.id}']?.version ?? 0,
              remindOn: followUpsById['budget:${budget.id}:${item.id}']?.remindOn,
              followUpReason: followUpsById['budget:${budget.id}:${item.id}']?.reason,
            ),
          );
        }
      }
      if (getIt.isRegistered<CommitmentRepository>()) {
        final commitments = await ref.watch(debtCommitmentsProvider(input.userId).future);
        final paymentLinks = await ref.watch(debtCommitmentPaymentsProvider(input.userId).future);
        for (final original in commitments) {
          final commitment = original.forMonth(input.monthKey);
          final due = commitment.dueDateFor(input.monthKey);
          if (due == null || commitment.isSkipped(input.monthKey)) continue;
          final paid = paymentLinks
              .where(
                (link) => link.commitmentId == commitment.id && link.monthKey == input.monthKey,
              )
              .fold<int>(0, (sum, link) => sum + link.amountMinor);
          entries.add(
            PlanningAgendaEntry(
              id: 'debt:${commitment.id}:${input.monthKey}',
              kind: PlanningEntryKind.debt,
              date: due,
              title: commitment.debtAccountId,
              currency: commitment.currency,
              plannedMinor: commitment.amountMinor,
              recordedMinor: paid,
              pendingMinor: (commitment.amountMinor - paid).clamp(0, commitment.amountMinor),
              monthKey: input.monthKey,
              commitmentId: commitment.id,
              debtAccountId: commitment.debtAccountId,
              bankAccountId: commitment.bankAccountId,
              followUpState:
                  followUpsById['debt:${commitment.id}:${input.monthKey}']?.state ??
                  PlanningFollowUpState.open,
              followUpVersion:
                  followUpsById['debt:${commitment.id}:${input.monthKey}']?.version ?? 0,
              remindOn: followUpsById['debt:${commitment.id}:${input.monthKey}']?.remindOn,
              followUpReason: followUpsById['debt:${commitment.id}:${input.monthKey}']?.reason,
            ),
          );
        }
      }
      entries.sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate == 0 ? a.id.compareTo(b.id) : byDate;
      });
      return List.unmodifiable(entries);
    });

final firebaseObservabilityProvider = Provider<FirebaseObservability?>(
  (ref) => getIt.isRegistered<FirebaseObservability>() ? getIt<FirebaseObservability>() : null,
);

final dashboardAmountsHiddenProvider = NotifierProvider<DashboardAmountsHiddenNotifier, bool>(
  DashboardAmountsHiddenNotifier.new,
);

class DashboardAmountsHiddenNotifier extends Notifier<bool> {
  static const _preferenceKey = 'dashboard_amounts_hidden';

  @override
  bool build() => getIt.isRegistered<SharedPreferences>()
      ? getIt<SharedPreferences>().getBool(_preferenceKey) ?? false
      : false;

  Future<void> setHidden(bool hidden) async {
    if (getIt.isRegistered<SharedPreferences>()) {
      await getIt<SharedPreferences>().setBool(_preferenceKey, hidden);
    }
    state = hidden;
  }
}

final canonicalUserProfileProvider = StreamProvider.family<UserProfile?, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchUserProfile(userId),
);

final categoryCatalogSyncProvider =
    FutureProvider.family<
      void,
      ({
        String userId,
        String locale,
        String countryCode,
      })
    >((ref, input) async {
      final result = await ref
          .watch(canonicalFinanceRepositoryProvider)
          .syncDefaultCategories(
            input.userId,
            locale: input.locale,
            countryCode: input.countryCode,
          );
      result.match((failure) => throw Exception(failure.message), (_) {});
    });

final appearancePreferencesControllerProvider =
    NotifierProvider<AppearancePreferencesController, AppearancePreferencesSaveState>(
      AppearancePreferencesController.new,
    );

final effectiveAppearancePreferencesProvider = Provider<AppearancePreferences>((ref) {
  final userId = ref.watch(authSessionProvider).valueOrNull?.id;
  if (userId == null) return const AppearancePreferences();
  final saveState = ref.watch(appearancePreferencesControllerProvider);
  if (saveState.userId == userId && (saveState.isSaving || saveState.saveFailed)) {
    return saveState.preferences;
  }
  return ref.watch(canonicalUserProfileProvider(userId)).valueOrNull?.appearancePreferences ??
      const AppearancePreferences();
});

class AppearancePreferencesSaveState {
  const AppearancePreferencesSaveState({
    this.userId,
    this.preferences = const AppearancePreferences(),
    this.isSaving = false,
    this.saveFailed = false,
    this.hasSaved = false,
  });

  final String? userId;
  final AppearancePreferences preferences;
  final bool isSaving;
  final bool saveFailed;
  final bool hasSaved;

  AppearancePreferencesSaveState copyWith({
    String? userId,
    AppearancePreferences? preferences,
    bool? isSaving,
    bool? saveFailed,
    bool? hasSaved,
  }) => AppearancePreferencesSaveState(
    userId: userId ?? this.userId,
    preferences: preferences ?? this.preferences,
    isSaving: isSaving ?? this.isSaving,
    saveFailed: saveFailed ?? this.saveFailed,
    hasSaved: hasSaved ?? this.hasSaved,
  );
}

class AppearancePreferencesController extends Notifier<AppearancePreferencesSaveState> {
  Future<void> _saveQueue = Future<void>.value();
  int _latestRequest = 0;

  @override
  AppearancePreferencesSaveState build() => const AppearancePreferencesSaveState();

  Future<void> save(String userId, AppearancePreferences preferences) {
    final request = ++_latestRequest;
    state = AppearancePreferencesSaveState(
      userId: userId,
      preferences: preferences,
      isSaving: true,
    );
    final save = _saveQueue.then((_) async {
      final result = await ref
          .read(canonicalFinanceRepositoryProvider)
          .updateAppearancePreferences(userId, preferences);
      if (request != _latestRequest) return;
      result.match(
        (_) => state = state.copyWith(isSaving: false, saveFailed: true),
        (_) {
          state = state.copyWith(isSaving: false, saveFailed: false, hasSaved: true);
          ref.invalidate(canonicalUserProfileProvider(userId));
        },
      );
    });
    _saveQueue = save;
    return save;
  }
}

final canonicalCategoriesProvider = StreamProvider.family<List<FinanceCategory>, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchCategories(userId),
);

/// A bounded, cross-device activity sample used to prioritize picker options.
final canonicalRecentOperationsProvider = StreamProvider.family<List<FinancialOperation>, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchOperations(userId),
);

final canonicalAccountsProvider = StreamProvider.family<List<FinanceAccount>, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchAccounts(userId).map((items) {
    int group(FinanceAccount account) => account.isCreditCard
        ? 1
        : account.isDebt
        ? 2
        : 0;
    return [...items]..sort((a, b) => group(a).compareTo(group(b)));
  }),
);

final canonicalOperationByIdProvider =
    FutureProvider.family<FinancialOperation?, ({String userId, String operationId})>(
      (ref, request) async {
        final operations = await ref
            .watch(canonicalFinanceRepositoryProvider)
            .watchOperations(request.userId)
            .first;
        for (final operation in operations) {
          if (operation.id == request.operationId) return operation;
        }
        return null;
      },
    );

final balanceAdjustmentsProvider = StreamProvider.family<List<BalanceAdjustmentEvent>, String>(
  (ref, userId) => getIt<CanonicalFinanceRepository>().watchBalanceAdjustments(userId),
);

final canonicalAccountProvider =
    StreamProvider.family<FinanceAccount?, ({String userId, String accountId})>(
      (ref, key) =>
          ref.watch(canonicalFinanceRepositoryProvider).watchAccount(key.userId, key.accountId),
    );

final canonicalOperationsPageProvider =
    FutureProvider.family<
      OperationPage,
      ({
        String userId,
        OperationPageCursor? cursor,
        String? monthKey,
        String? currency,
        OperationType? type,
        List<String>? accountIds,
        int pageSize,
      })
    >((ref, input) async {
      final result = await ref
          .read(canonicalFinanceRepositoryProvider)
          .fetchOperationsPage(
            input.userId,
            cursor: input.cursor,
            monthKey: input.monthKey,
            currency: input.currency,
            type: input.type,
            accountIds: input.accountIds,
            pageSize: input.pageSize,
          );
      return result.match((failure) => throw Exception(failure.message), (page) => page);
    });

final operationsPagerProvider =
    AsyncNotifierProvider.family<
      OperationsPagerNotifier,
      OperationPagerState,
      ({String userId, OperationType? type, bool debtPaymentsOnly})
    >(
      OperationsPagerNotifier.new,
    );

/// Refreshes the two read models that display recent and paginated activity.
void invalidateOperationLists(WidgetRef ref, String userId) {
  ref.invalidate(
    canonicalOperationsPageProvider((
      userId: userId,
      cursor: null,
      monthKey: null,
      currency: null,
      type: null,
      accountIds: null,
      pageSize: 10,
    )),
  );
  for (final type in const <OperationType?>[
    null,
    OperationType.income,
    OperationType.expense,
    OperationType.transfer,
  ]) {
    ref.invalidate(
      operationsPagerProvider((userId: userId, type: type, debtPaymentsOnly: false)),
    );
  }
  ref.invalidate(
    operationsPagerProvider((userId: userId, type: null, debtPaymentsOnly: true)),
  );
}

final activityTypeFilterProvider = NotifierProvider<ActivityTypeFilterNotifier, OperationType?>(
  ActivityTypeFilterNotifier.new,
);

final activityDebtPaymentsOnlyProvider = NotifierProvider<DebtPaymentsOnlyNotifier, bool>(
  DebtPaymentsOnlyNotifier.new,
);

class DebtPaymentsOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void select(bool value) => state = value;
}

final activityBalanceAdjustmentsOnlyProvider =
    NotifierProvider<BalanceAdjustmentsOnlyNotifier, bool>(
      BalanceAdjustmentsOnlyNotifier.new,
    );

class BalanceAdjustmentsOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void select(bool value) => state = value;
}

final activityQueryFiltersProvider =
    NotifierProvider<ActivityQueryFiltersNotifier, ActivityQueryFilters>(
      ActivityQueryFiltersNotifier.new,
    );

/// Loads every non-rejected activity record matching the current filters so
/// summaries and exports are not limited to the list's currently loaded page.
final activityReportProvider = FutureProvider.family<ActivityReport, String>((ref, userId) async {
  final observability = ref.watch(firebaseObservabilityProvider);
  Future<ActivityReport> load() async {
    final filters = ref.watch(activityQueryFiltersProvider);
    final type = ref.watch(activityTypeFilterProvider);
    final debtPaymentsOnly = ref.watch(activityDebtPaymentsOnlyProvider);
    final adjustmentsOnly = ref.watch(activityBalanceAdjustmentsOnlyProvider);
    final adjustmentEventsState = ref.watch(balanceAdjustmentsProvider(userId));
    final localPending = ref.watch(pendingOperationsProvider).valueOrNull ?? const [];
    final repository = ref.watch(canonicalFinanceRepositoryProvider);
    final adjustmentEvents = adjustmentEventsState.valueOrNull ?? const <BalanceAdjustmentEvent>[];
    final operations = <FinancialOperation>[];
    OperationPageCursor? cursor;

    while (true) {
      final result = await repository.fetchOperationsPage(
        userId,
        cursor: cursor,
        monthKey: filters.monthKey,
        type: type,
        debtPaymentsOnly: debtPaymentsOnly,
        accountIds: filters.accountIds,
        startAt: filters.startAt,
        endAtExclusive: filters.endAtExclusive,
      );
      final page = result.match((failure) => throw Exception(failure.message), (value) => value);
      operations.addAll(page.items);
      cursor = page.nextCursor;
      if (cursor == null) break;
    }

    final knownIdempotencyKeys = operations.map((operation) => operation.idempotencyKey).toSet();
    for (final pending in localPending) {
      if (pending.status == 'rejected') continue;
      try {
        final payload = jsonDecode(pending.payload) as Map<String, dynamic>;
        // New queue entries carry ownership so another signed-in user's local
        // transactions are never exposed in this report or its export.
        if (payload['ownerUserId'] != userId) continue;
        final operation = _pendingActivityOperation(pending, payload);
        if (operation == null || knownIdempotencyKeys.contains(operation.idempotencyKey)) {
          continue;
        }
        if (debtPaymentsOnly || (type != null && operation.type != type)) continue;
        if (filters.monthKey != null && operation.monthKey != filters.monthKey) continue;
        if (filters.isDateRange &&
            (operation.occurredAt.isBefore(filters.startAt!) ||
                !operation.occurredAt.isBefore(filters.endAtExclusive!))) {
          continue;
        }
        if (filters.accountIds.isNotEmpty &&
            !filters.accountIds.any(
              (id) =>
                  id == operation.accountId ||
                  id == operation.sourceAccountId ||
                  id == operation.destinationAccountId,
            )) {
          continue;
        }
        operations.add(operation);
        knownIdempotencyKeys.add(operation.idempotencyKey);
      } on Object {
        // A malformed or legacy queue row is left untouched and omitted safely.
      }
    }

    final adjustments = <BalanceAdjustmentActivityEntry>[];
    if (type == null && !debtPaymentsOnly) {
      for (final event in adjustmentEvents) {
        final localDate = event.adjustedAt.toLocal();
        final monthKey =
            '${localDate.year.toString().padLeft(4, '0')}-${localDate.month.toString().padLeft(2, '0')}';
        if (filters.monthKey != null && monthKey != filters.monthKey) continue;
        if (filters.isDateRange &&
            (event.adjustedAt.isBefore(filters.startAt!) ||
                !event.adjustedAt.isBefore(filters.endAtExclusive!))) {
          continue;
        }
        for (final adjustment in event.adjustments) {
          if (filters.accountIds.isNotEmpty && !filters.accountIds.contains(adjustment.accountId)) {
            continue;
          }
          adjustments.add(
            BalanceAdjustmentActivityEntry(
              requestId: event.requestId,
              adjustedAt: event.adjustedAt,
              adjustment: adjustment,
            ),
          );
        }
      }
    }
    return ActivityReport.fromOperations(
      adjustmentsOnly
          ? operations.where((operation) => operation.type == OperationType.debtAdjustment)
          : operations,
      adjustments: adjustments,
    );
  }

  if (observability == null) return load();
  return observability.tracePerformance(PerformanceTraceName.activityReportPreparation, load);
});

FinancialOperation? _pendingActivityOperation(
  PendingOperation pending,
  Map<String, dynamic> payload,
) {
  final isTransfer = pending.operationType == 'transfer';
  final type = isTransfer
      ? OperationType.transfer
      : OperationType.values.byName(payload['type'] as String);
  final occurredAt = DateTime.tryParse(payload['occurredAt'] as String? ?? '');
  final amountMinor = payload['amountMinor'];
  if (occurredAt == null || amountMinor is! int) return null;
  final monthKey =
      payload['monthKey'] as String? ??
      '${occurredAt.year.toString().padLeft(4, '0')}-${occurredAt.month.toString().padLeft(2, '0')}';
  return FinancialOperation(
    id: 'local-${pending.idempotencyKey}',
    type: type,
    amountMinor: amountMinor,
    currency: payload['currency'] as String? ?? '',
    monthKey: monthKey,
    occurredAt: occurredAt,
    status: OperationStatus.pending,
    idempotencyKey: pending.idempotencyKey,
    description: payload['description'] as String? ?? '',
    accountId: payload['accountId'] as String?,
    categoryId: payload['categoryId'] as String?,
    sourceAccountId: payload['sourceAccountId'] as String?,
    destinationAccountId: payload['destinationAccountId'] as String?,
  );
}

class ActivityQueryFilters {
  const ActivityQueryFilters({
    this.accountIds = const [],
    this.monthKey,
    this.startAt,
    this.endAtExclusive,
    this.hasBeenApplied = false,
  });

  final List<String> accountIds;
  final String? monthKey;
  final DateTime? startAt;
  final DateTime? endAtExclusive;
  final bool hasBeenApplied;

  bool get isDateRange => startAt != null && endAtExclusive != null;
}

class ActivityQueryFiltersNotifier extends Notifier<ActivityQueryFilters> {
  @override
  ActivityQueryFilters build() => ActivityQueryFilters(monthKey: _monthKey(DateTime.now()));

  void apply(ActivityQueryFilters filters) => state = filters;

  void reset() => state = ActivityQueryFilters(
    monthKey: _monthKey(DateTime.now()),
    hasBeenApplied: true,
  );

  static String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
}

class ActivityTypeFilterNotifier extends Notifier<OperationType?> {
  @override
  OperationType? build() => null;

  void select(OperationType? type) => state = type;
}

class OperationsPagerNotifier extends AsyncNotifier<OperationPagerState> {
  OperationsPagerNotifier(this.filter);

  final ({String userId, OperationType? type, bool debtPaymentsOnly}) filter;
  int _requestGeneration = 0;

  @override
  Future<OperationPagerState> build() {
    ref.watch(activityQueryFiltersProvider);
    return _loadInitial(type: filter.type);
  }

  Future<void> refresh() async {
    final generation = ++_requestGeneration;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _loadInitial(type: filter.type));
    if (generation == _requestGeneration) state = result;
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    final generation = _requestGeneration;
    state = AsyncData(current.copyWith(isLoadingMore: true, errorMessage: null));
    final result = await ref
        .read(canonicalFinanceRepositoryProvider)
        .fetchOperationsPage(
          filter.userId,
          cursor: current.nextCursor,
          monthKey: current.monthKey,
          currency: current.currency,
          type: current.type,
          debtPaymentsOnly: filter.debtPaymentsOnly,
          accountIds: current.accountIds,
          startAt: current.startAt,
          endAtExclusive: current.endAtExclusive,
        );
    if (generation != _requestGeneration) return;
    result.match(
      (failure) => state = AsyncData(
        current.copyWith(isLoadingMore: false, errorMessage: failure.message),
      ),
      (page) {
        final knownIds = current.items.map((item) => item.id).toSet();
        final additions = <FinancialOperation>[];
        for (final item in page.items) {
          if (knownIds.add(item.id)) additions.add(item);
        }
        state = AsyncData(
          current.copyWith(
            items: [...current.items, ...additions],
            nextCursor: page.nextCursor,
            isLoadingMore: false,
            errorMessage: null,
          ),
        );
      },
    );
  }

  Future<OperationPagerState> _loadInitial({required OperationType? type}) async {
    final filters = ref.read(activityQueryFiltersProvider);
    final result = await ref
        .read(canonicalFinanceRepositoryProvider)
        .fetchOperationsPage(
          filter.userId,
          type: type,
          debtPaymentsOnly: filter.debtPaymentsOnly,
          accountIds: filters.accountIds,
          monthKey: filters.monthKey,
          startAt: filters.startAt,
          endAtExclusive: filters.endAtExclusive,
        );
    return result.match(
      (failure) => throw Exception(failure.message),
      (page) => OperationPagerState(
        items: page.items,
        nextCursor: page.nextCursor,
        type: type,
        accountIds: filters.accountIds,
        monthKey: filters.monthKey,
        startAt: filters.startAt,
        endAtExclusive: filters.endAtExclusive,
      ),
    );
  }
}

class OperationPagerState {
  const OperationPagerState({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
    this.errorMessage,
    this.monthKey,
    this.currency,
    this.type,
    this.accountIds = const [],
    this.startAt,
    this.endAtExclusive,
  });

  final List<FinancialOperation> items;
  final OperationPageCursor? nextCursor;
  final bool isLoadingMore;
  final String? errorMessage;
  final String? monthKey;
  final String? currency;
  final OperationType? type;
  final List<String> accountIds;
  final DateTime? startAt;
  final DateTime? endAtExclusive;

  bool get hasMore => nextCursor != null;

  OperationPagerState copyWith({
    List<FinancialOperation>? items,
    OperationPageCursor? nextCursor,
    bool clearCursor = false,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    String? monthKey,
    String? currency,
    OperationType? type,
    bool clearType = false,
    List<String>? accountIds,
    DateTime? startAt,
    DateTime? endAtExclusive,
  }) => OperationPagerState(
    items: items ?? this.items,
    nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    monthKey: monthKey ?? this.monthKey,
    currency: currency ?? this.currency,
    type: clearType ? null : type ?? this.type,
    accountIds: accountIds ?? this.accountIds,
    startAt: startAt ?? this.startAt,
    endAtExclusive: endAtExclusive ?? this.endAtExclusive,
  );
}

final canonicalBudgetsProvider =
    StreamProvider.family<List<Budget>, ({String userId, String monthKey})>(
      (ref, input) =>
          ref.watch(canonicalFinanceRepositoryProvider).watchBudgets(input.userId, input.monthKey),
    );

final canonicalBudgetProvider = StreamProvider.family<Budget?, ({String userId, String budgetId})>(
  (ref, input) =>
      ref.watch(canonicalFinanceRepositoryProvider).watchBudget(input.userId, input.budgetId),
);

final canonicalFinanceRepositoryItemsProvider =
    StreamProvider.family<List<BudgetItem>, ({String userId, String budgetId})>(
      (ref, input) => ref
          .watch(canonicalFinanceRepositoryProvider)
          .watchBudgetItems(input.userId, input.budgetId),
    );

final canonicalBudgetAggregateReconciliationProvider = FutureProvider.autoDispose
    .family<void, ({String userId, String budgetId})>((ref, input) async {
      final budget = await ref.watch(canonicalBudgetProvider(input).future);
      if (budget == null) return;
      final items = await ref.watch(canonicalFinanceRepositoryItemsProvider(input).future);
      final activeItems = items.where((item) => item.isActive).toList(growable: false);
      if (activeItems.isEmpty) {
        throw StateError('budget-has-no-active-items');
      }
      final plannedTotal = activeItems.fold<int>(0, (total, item) => total + item.amountMinor);
      if (budget.plannedAmountMinor != plannedTotal || budget.itemCount != activeItems.length) {
        await ref.read(canonicalActionsProvider).reconcileBudget(input.userId, input.budgetId);
      }
    });

final canonicalBudgetItemOperationsProvider =
    StreamProvider.family<
      List<FinancialOperation>,
      ({String userId, String budgetId, String itemId})
    >(
      (ref, input) => ref
          .watch(canonicalFinanceRepositoryProvider)
          .watchBudgetItemOperations(
            input.userId,
            input.budgetId,
            input.itemId,
          ),
    );

final canonicalBudgetCategoryOperationsProvider = FutureProvider.autoDispose
    .family<
      List<FinancialOperation>,
      ({
        String userId,
        String budgetId,
        String categoryId,
        String monthKey,
        String currency,
        String flowType,
      })
    >(
      (ref, input) async {
        final repository = ref.watch(canonicalFinanceRepositoryProvider);
        final operations = <FinancialOperation>[];
        OperationPageCursor? cursor;
        final type = input.flowType == 'income' ? OperationType.income : OperationType.expense;
        while (true) {
          final pageResult = await repository.fetchOperationsPage(
            input.userId,
            cursor: cursor,
            monthKey: input.monthKey,
            currency: input.currency,
            type: type,
            pageSize: 100,
          );
          final page = pageResult.match(
            (failure) => throw Exception(failure.message),
            (value) => value,
          );
          operations.addAll(
            page.items.where(
              (operation) =>
                  operation.status == OperationStatus.confirmed &&
                  operation.categoryId == input.categoryId &&
                  (operation.type == type ||
                      (type == OperationType.expense &&
                          operation.type == OperationType.expenseRefund)),
            ),
          );
          cursor = page.nextCursor;
          if (cursor == null) break;
        }
        operations.sort((a, b) {
          final date = b.occurredAt.compareTo(a.occurredAt);
          return date == 0 ? b.id.compareTo(a.id) : date;
        });
        return List.unmodifiable(operations);
      },
    );

final canonicalMonthlySummaryProvider =
    StreamProvider.family<MonthlySummary?, ({String userId, String monthKey, String currency})>(
      (ref, input) => getIt<CanonicalFinanceRepository>().watchMonthlySummary(
        input.userId,
        input.monthKey,
        input.currency,
      ),
    );

final homeInitialLoadProvider =
    FutureProvider.family<void, ({String userId, String monthKey, String currency})>((
      ref,
      input,
    ) async {
      final observability = ref.watch(firebaseObservabilityProvider);
      Future<void> load() async {
        await Future.wait<Object?>([
          ref.watch(canonicalAccountsProvider(input.userId).future),
          ref.watch(canonicalCategoriesProvider(input.userId).future),
          ref.watch(
            canonicalOperationsPageProvider((
              userId: input.userId,
              cursor: null,
              monthKey: null,
              currency: null,
              type: null,
              accountIds: null,
              pageSize: 10,
            )).future,
          ),
          ref.watch(
            canonicalMonthlySummaryProvider((
              userId: input.userId,
              monthKey: input.monthKey,
              currency: input.currency,
            )).future,
          ),
          ref.watch(
            canonicalBudgetsProvider((userId: input.userId, monthKey: input.monthKey)).future,
          ),
        ]);
      }

      if (observability == null) {
        await load();
      } else {
        await observability.tracePerformance(PerformanceTraceName.homeInitialLoad, load);
      }
    });

final bootstrapCategoriesProvider = Provider<BootstrapCategories>(
  (ref) => BootstrapCategories(
    getIt<CanonicalFinanceRepository>(),
    getIt<FirebaseObservability>(),
  ),
);

final pendingOperationsProvider = StreamProvider<List<PendingOperation>>((ref) {
  return getIt<PendingOperationDatabase>().watchActive();
});

final pendingOperationSyncStatusProvider = StreamProvider<SyncStatusSnapshot>((ref) {
  return getIt<PendingOperationSyncService>().watchStatus();
});

final pendingOperationAutoSyncProvider = Provider.autoDispose<void>((ref) {
  final user = ref.watch(authSessionProvider).value;
  if (user == null) return;
  final actions = ref.read(canonicalActionsProvider);
  final subscription = actions.startAutoSync(user.id);
  ref.onDispose(subscription.cancel);
  unawaited(actions.syncPending(user.id));
});

class BootstrapCategories {
  const BootstrapCategories(this._repository, this._observability);

  final CanonicalFinanceRepository _repository;
  final FirebaseObservability _observability;

  Future<void> call(
    String userId, {
    required String locale,
    required String countryCode,
    String timeZone = 'UTC',
    String defaultCurrency = 'COP',
  }) async {
    final result = await _repository.ensureDefaultCategories(
      userId,
      locale: locale,
      countryCode: countryCode,
      timeZone: timeZone,
      defaultCurrency: defaultCurrency,
    );
    result.match((failure) => throw Exception(failure.message), (_) {
      unawaited(_observability.logEvent('onboarding_completed'));
    });
  }
}

final canonicalActionsProvider = Provider<CanonicalFinanceActions>(
  (ref) => CanonicalFinanceActions(
    getIt<CanonicalFinanceRepository>(),
    getIt<PendingOperationSyncService>(),
    getIt<PendingOperationDatabase>(),
    getIt<FirebaseObservability>(),
  ),
);

class CanonicalFinanceActions {
  CanonicalFinanceActions(
    this._repository,
    this._sync,
    this._database,
    this._observability,
  );

  final CanonicalFinanceRepository _repository;
  final PendingOperationSyncService _sync;
  final PendingOperationDatabase _database;
  final FirebaseObservability _observability;

  Future<void> createAccount(
    String userId, {
    String? accountId,
    required String name,
    required String type,
    required String currency,
    required int openingBalanceMinor,
  }) async {
    final result = await _repository.createAccount(
      userId,
      accountId: accountId,
      name: name,
      type: type,
      currency: currency,
      openingBalanceMinor: openingBalanceMinor,
    );
    result.match((failure) => throw Exception(failure.message), (_) {
      unawaited(_observability.logEvent('account_created'));
    });
  }

  Future<void> updateAccount(
    String userId,
    FinanceAccount account, {
    required String name,
    required bool includeInDashboard,
  }) async {
    final result = await _repository.updateAccount(
      userId,
      FinanceAccount(
        id: account.id,
        name: name,
        type: account.type,
        currency: account.currency,
        openingBalanceMinor: account.openingBalanceMinor,
        currentBalanceMinor: account.currentBalanceMinor,
        includeInDashboard: includeInDashboard,
        status: account.status,
        createdAt: account.createdAt,
        updatedAt: account.updatedAt,
        archivedAt: account.archivedAt,
      ),
    );
    result.match((failure) => throw Exception(failure.message), (_) {});
  }

  Future<SyncState> createOperation(
    String userId,
    FinancialOperationDraft draft,
  ) async {
    return _observability.tracePerformance(PerformanceTraceName.operationSave, () async {
      final generation = (await _repository.watchUserProfile(userId).first)?.dataGeneration ?? 0;
      await _sync.enqueue(
        idempotencyKey: draft.idempotencyKey,
        operationType: 'operation',
        payload: {..._operationPayload(draft), 'ownerUserId': userId, 'dataGeneration': generation},
      );
      await _sync.drain((type, payload) => _send(userId, type, payload));
      final status = (await _database.findByIdempotencyKey(draft.idempotencyKey))?.status;
      if (status == SyncState.confirmed.name) {
        await _observability.logEvent('${draft.type.name}_created');
      }
      return SyncState.values.firstWhere(
        (value) => value.name == status,
        orElse: () => SyncState.pending,
      );
    });
  }

  Future<SyncState> createTransfer(String userId, TransferDraft draft) async {
    return _observability.tracePerformance(PerformanceTraceName.operationSave, () async {
      final generation = (await _repository.watchUserProfile(userId).first)?.dataGeneration ?? 0;
      await _sync.enqueue(
        idempotencyKey: draft.idempotencyKey,
        operationType: 'transfer',
        payload: {..._transferPayload(draft), 'ownerUserId': userId, 'dataGeneration': generation},
      );
      await _sync.drain((type, payload) => _send(userId, type, payload));
      final status = (await _database.findByIdempotencyKey(draft.idempotencyKey))?.status;
      if (status == SyncState.confirmed.name) await _observability.logEvent('transfer_created');
      return SyncState.values.firstWhere(
        (value) => value.name == status,
        orElse: () => SyncState.pending,
      );
    });
  }

  final Map<String, String> _budgetRequestIds = {};

  List<Object> _budgetItemKey(CanonicalBudgetItemDraft item) => [
    item.description.trim(),
    item.amountMinor,
    item.dayOfMonth,
  ];

  Future<T> _runBudget<T>(String key, Future<Either<Failure, T>> Function(String) send) async {
    return _observability.tracePerformance(PerformanceTraceName.budgetSave, () async {
      final requestId = _budgetRequestIds.putIfAbsent(key, newRequestId);
      final result = await send(requestId);
      return result.match(
        (failure) => throw BudgetCommandException.fromFailure(failure),
        (value) {
          _budgetRequestIds.remove(key);
          return value;
        },
      );
    });
  }

  Future<Budget> createBudget(
    String userId, {
    required String categoryId,
    required String flowType,
    required String monthKey,
    required String currency,
    required List<CanonicalBudgetItemDraft> items,
  }) async {
    final key = jsonEncode([
      userId,
      'create',
      categoryId,
      flowType,
      monthKey,
      currency,
      items.map(_budgetItemKey).toList(),
    ]);
    final budget = await _runBudget(
      key,
      (requestId) => _repository.createBudgetWithItems(
        userId,
        categoryId: categoryId,
        flowType: flowType,
        monthKey: monthKey,
        currency: currency,
        items: items,
        requestId: requestId,
      ),
    );
    unawaited(_observability.logEvent('budget_created'));
    return budget;
  }

  Future<void> addBudgetItem(String userId, String budgetId, CanonicalBudgetItemDraft item) async {
    final key = jsonEncode([userId, 'addItem', budgetId, _budgetItemKey(item)]);
    await _runBudget(
      key,
      (requestId) => _repository.addBudgetItem(userId, budgetId, item, requestId: requestId),
    );
  }

  Future<void> updateBudgetItem(String userId, String budgetId, BudgetItem item) async {
    final key = jsonEncode([
      userId,
      'updateItem',
      budgetId,
      item.id,
      item.description.trim(),
      item.amountMinor,
      item.dayOfMonth,
    ]);
    await _runBudget(
      key,
      (requestId) => _repository.updateBudgetItem(userId, budgetId, item, requestId: requestId),
    );
  }

  Future<void> deleteBudgetItem(String userId, String budgetId, String itemId) async {
    final key = jsonEncode([userId, 'archiveItem', budgetId, itemId]);
    await _runBudget(
      key,
      (requestId) => _repository.deleteBudgetItem(userId, budgetId, itemId, requestId: requestId),
    );
  }

  Future<void> reconcileBudget(String userId, String budgetId) async {
    final key = jsonEncode([userId, 'reconcile', budgetId]);
    await _runBudget(
      key,
      (requestId) => _repository.reconcileBudget(userId, budgetId, requestId: requestId),
    );
  }

  Future<void> setOperationBudgetItem(
    String userId, {
    required String operationId,
    required int expectedRevision,
    required String? budgetId,
    required String? itemId,
  }) async {
    final key = jsonEncode([
      userId,
      'setOperationBudgetItem',
      operationId,
      expectedRevision,
      budgetId,
      itemId,
    ]);
    await _runBudget(
      key,
      (requestId) => _repository.setOperationBudgetItem(
        userId,
        operationId: operationId,
        expectedRevision: expectedRevision,
        budgetId: budgetId,
        itemId: itemId,
        requestId: requestId,
      ),
    );
  }

  Future<Failure?> archiveBudget(String userId, String budgetId) async {
    return _observability.tracePerformance(PerformanceTraceName.budgetSave, () async {
      final key = jsonEncode([userId, 'archiveBudget', budgetId]);
      final requestId = _budgetRequestIds.putIfAbsent(key, newRequestId);
      final result = await _repository.archiveBudget(userId, budgetId, requestId: requestId);
      return result.match(
        (failure) {
          if (kDebugMode) {
            debugPrint('budget_archive_failure code=${failure.technicalCode ?? 'unexpected'}');
          }
          unawaited(_observability.recordNonFatal(TechnicalErrorCode.firebaseRequest));
          return failure;
        },
        (_) {
          _budgetRequestIds.remove(key);
          return null;
        },
      );
    });
  }

  Future<void> updateOperation(
    String userId,
    FinancialOperation operation, {
    required String requestId,
  }) async {
    final result = await _repository.updateOperation(userId, operation, requestId: requestId);
    result.match((failure) => throw Exception(failure.message), (_) {});
  }

  Future<void> deleteOperation(String userId, String operationId) async {
    final result = await _repository.deleteOperation(userId, operationId);
    result.match((failure) => throw Exception(failure.message), (_) {});
  }

  Future<void> syncPending(String userId, {bool retryRejected = true}) {
    return _sync.drain(
      (type, payload) => _send(userId, type, payload),
      retryRejected: retryRejected,
    );
  }

  StreamSubscription<dynamic> startAutoSync(String userId) =>
      _sync.listenForReconnect((type, payload) => _send(userId, type, payload));

  Future<SyncAttemptResult> _send(String userId, String type, Map<String, dynamic> payload) async {
    if (type == 'transfer') {
      final result = await _repository.createTransfer(
        userId,
        TransferDraft(
          amountMinor: payload['amountMinor'] as int,
          currency: payload['currency'] as String,
          sourceAccountId: payload['sourceAccountId'] as String,
          destinationAccountId: payload['destinationAccountId'] as String,
          occurredAt: DateTime.parse(payload['occurredAt'] as String),
          description: payload['description'] as String,
          idempotencyKey: payload['idempotencyKey'] as String,
          monthKey: payload['monthKey'] as String?,
          dataGeneration: payload['dataGeneration'] as int? ?? 0,
        ),
      );
      return result.match(_syncFailureResult, (_) => const SyncAttemptResult.success());
    }
    final result = await _repository.createOperation(
      userId,
      FinancialOperationDraft(
        type: OperationType.values.byName(payload['type'] as String),
        amountMinor: payload['amountMinor'] as int,
        currency: payload['currency'] as String,
        accountId: payload['accountId'] as String,
        categoryId: payload['categoryId'] as String?,
        occurredAt: DateTime.parse(payload['occurredAt'] as String),
        monthKey: payload['monthKey'] as String?,
        description: payload['description'] as String,
        idempotencyKey: payload['idempotencyKey'] as String,
        budgetId: payload['budgetId'] as String?,
        budgetItemId: payload['budgetItemId'] as String?,
        dataGeneration: payload['dataGeneration'] as int? ?? 0,
      ),
    );
    return result.match(_syncFailureResult, (_) => const SyncAttemptResult.success());
  }

  SyncAttemptResult _syncFailureResult(Failure failure) {
    final result = switch (failure) {
      NetworkFailure() => SyncAttemptResult.retryable(
        SyncIssueCode.networkUnavailable,
        technicalCode: failure.technicalCode,
      ),
      AuthFailure() => SyncAttemptResult.rejected(
        SyncIssueCode.permissionDenied,
        technicalCode: failure.technicalCode,
      ),
      ConflictFailure() => SyncAttemptResult.rejected(
        SyncIssueCode.invalidOperation,
        technicalCode: failure.technicalCode,
      ),
      UnknownFailure() => SyncAttemptResult.rejected(
        SyncIssueCode.invalidOperation,
        technicalCode: failure.technicalCode,
      ),
    };

    if (kDebugMode) {
      debugPrint(
        'operation_sync_failure issue=${result.issueCode?.name} '
        'firebaseCode=${result.technicalCode ?? 'none'}',
      );
    }
    if (!result.retryable) {
      unawaited(_recordRejectedSync());
    }
    return result;
  }

  Future<void> _recordRejectedSync() async {
    try {
      await _observability.logEvent('sync_rejected');
    } catch (_) {
      // Diagnostics must never replace or hide the user's sync failure.
    }
    await _observability.recordNonFatal(TechnicalErrorCode.sync);
  }

  Map<String, dynamic> _operationPayload(FinancialOperationDraft draft) => {
    'type': draft.type.name,
    'amountMinor': draft.amountMinor,
    'currency': draft.currency,
    'accountId': draft.accountId,
    'categoryId': draft.categoryId,
    'occurredAt': draft.occurredAt.toIso8601String(),
    'monthKey': draft.monthKey,
    'description': draft.description,
    'idempotencyKey': draft.idempotencyKey,
    'budgetId': draft.budgetId,
    'budgetItemId': draft.budgetItemId,
  };

  Map<String, dynamic> _transferPayload(TransferDraft draft) => {
    'amountMinor': draft.amountMinor,
    'currency': draft.currency,
    'sourceAccountId': draft.sourceAccountId,
    'destinationAccountId': draft.destinationAccountId,
    'occurredAt': draft.occurredAt.toIso8601String(),
    'monthKey': draft.monthKey,
    'description': draft.description,
    'idempotencyKey': draft.idempotencyKey,
  };
}
