import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../finance/domain/entities/finance_account.dart';
import '../../../finance/domain/entities/finance_category.dart';
import '../../../finance/presentation/providers/canonical_finance_providers.dart';
import '../../../finance/presentation/widgets/planning_follow_up_controls.dart';
import '../../domain/entities/coach_models.dart';
import '../../domain/usecases/coach_overview.dart';
import '../../domain/usecases/coach_routine.dart';
import '../coach_action_presentation.dart';
import '../providers/coach_providers.dart';

class CoachHomeScreen extends ConsumerStatefulWidget {
  const CoachHomeScreen({super.key});

  @override
  ConsumerState<CoachHomeScreen> createState() => _CoachHomeScreenState();
}

class _CoachHomeScreenState extends ConsumerState<CoachHomeScreen> {
  final _scrollController = ScrollController();
  final _routineKey = GlobalKey();
  bool _openedLogged = false;
  bool _routineSaving = false;
  bool _routineFailed = false;
  bool _showAllPayments = false;
  bool _inviteDaily = false;
  bool _inviteWeekly = false;
  CoachRoutinePreferences? _routineDraft;
  String? _ownerUid;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveRoutine(String uid, CoachRoutinePreferences preferences) async {
    if (ref.read(authSessionProvider).value?.id != uid || _routineSaving) return;
    setState(() {
      _routineDraft = preferences;
      _routineSaving = true;
      _routineFailed = false;
    });
    final result = await ref
        .read(coachRepositoryProvider)!
        .saveRoutinePreferences(uid, preferences);
    if (!mounted || ref.read(authSessionProvider).value?.id != uid) return;
    setState(() {
      _routineSaving = false;
      _routineFailed = result.isLeft();
      if (result.isRight()) _routineDraft = null;
    });
    if (result.isRight()) {
      unawaited(ref.read(firebaseObservabilityProvider)?.logEvent('coach_routine_configured'));
      ref
        ..invalidate(coachRoutinePreferencesProvider(uid))
        ..invalidate(coachOverviewProvider(uid))
        ..read(coachRescheduleProvider.notifier).retry();
    }
  }

  void _refresh(String uid) {
    retryCoachOverview(ref, uid);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    if (_ownerUid != uid) {
      _ownerUid = uid;
      _routineDraft = null;
      _routineSaving = false;
      _routineFailed = false;
      _showAllPayments = false;
      _openedLogged = false;
      _inviteDaily = false;
      _inviteWeekly = false;
    }
    if (!_openedLogged) {
      _openedLogged = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(authSessionProvider).value?.id == uid) {
          unawaited(ref.read(firebaseObservabilityProvider)?.logEvent('coach_opened'));
        }
      });
    }
    if (ref.watch(coachRepositoryProvider) == null) {
      return Scaffold(body: Center(child: Text(l10n.coachReadFailure)));
    }
    final overviewState = ref.watch(coachOverviewProvider(uid));
    final routineState = ref.watch(coachRoutinePreferencesProvider(uid));
    final legacyPrefs = ref.watch(coachPreferencesProvider(uid));
    final completionsState = ref.watch(coachCompletionsProvider(uid));
    final profile = ref.watch(canonicalUserProfileProvider(uid)).valueOrNull;
    final accountsState = ref.watch(canonicalAccountsProvider(uid));
    final categories =
        ref.watch(canonicalCategoriesProvider(uid)).valueOrNull ?? const <FinanceCategory>[];
    final hidden = ref.watch(coachAmountsHiddenProvider);
    final overview = overviewState.overview;
    final routine = _routineDraft ?? routineState.valueOrNull;
    final accounts = accountsState.valueOrNull ?? const <FinanceAccount>[];
    final completions = completionsState.valueOrNull ?? const <CoachCompletion>[];
    final zone = profile?.timeZone ?? 'UTC';
    final clock = ref.watch(coachRoutineProvider);
    final today = clock.today(zone);
    final todayKey = coachDateKey(today);
    final weeklyKey = coachDateKey(clock.previousWeek(zone));
    final locale = Localizations.localeOf(context).toString();
    final localNow = clock.calendar.local(clock.clock.now(), zone);
    String money(int amount, String currency) =>
        CurrencyFormatter.formatMinor(amount, currency, locale: locale);
    String localDate(DateTime date) => DateFormat.yMMMd(locale).format(
      clock.calendar.local(date, zone),
    );
    String accountName(String? id) =>
        accounts.where((account) => account.id == id).firstOrNull?.name ?? l10n.accountName;

    final action = overview?.action;
    final actionTitle = action == null ? null : coachActionTitle(l10n, action, accounts);
    final actionBody = action == null
        ? null
        : coachActionBody(context, l10n, action, amountsHidden: hidden);
    final isPriority = action != null && action.kind != CoachActionKind.current;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => _refresh(uid),
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 112),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.coachHubTitle,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.coachToggleAmounts,
                    onPressed: () =>
                        ref.read(coachAmountsHiddenProvider.notifier).setHidden(!hidden),
                    icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(l10n.coachScreenSubtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                DateFormat.yMMMMEEEEd(locale).format(localNow),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (overviewState.loading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ] else if (overviewState.incomplete) ...[
                const SizedBox(height: 16),
                _Notice(
                  icon: Icons.sync_problem_outlined,
                  message: l10n.coachSourcesIncomplete,
                  actionLabel: l10n.retry,
                  onAction: () => _refresh(uid),
                  warning: true,
                ),
              ] else if (overview != null &&
                  (overview.freshness == CoachFreshness.cached ||
                      overview.hasPendingOperations)) ...[
                const SizedBox(height: 16),
                _Notice(
                  icon: Icons.info_outline,
                  message: overview.freshness == CoachFreshness.cached
                      ? l10n.coachDataCached
                      : l10n.coachIncompleteInfo,
                  warning: true,
                ),
              ] else ...[
                const SizedBox(height: 16),
                _Notice(icon: Icons.check_circle_outline, message: l10n.coachDataFresh),
              ],
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: Text(l10n.diagnosticText('title')),
                  subtitle: Text(l10n.diagnosticText('intro')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/coach/diagnosis'),
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle(context, l10n.coachNextStepTitle),
              const SizedBox(height: 8),
              _nextActionCard(
                context,
                ref,
                l10n,
                uid,
                action,
                actionTitle,
                actionBody,
                overviewState,
                accounts,
                isPriority,
                hidden,
              ),
              const SizedBox(height: 20),
              _sectionTitle(context, l10n.coachActionUnallocatedTitle),
              const SizedBox(height: 8),
              if (overviewState.error)
                _Notice(icon: Icons.error_outline, message: l10n.coachReadFailure, warning: true)
              else if (overviewState.loading)
                const Card(
                  child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
                )
              else ...[
                if (overviewState.paymentsIncomplete)
                  _Notice(
                    icon: Icons.info_outline,
                    message: l10n.coachPaymentsIncomplete,
                    actionLabel: l10n.retry,
                    onAction: () => _refresh(uid),
                    warning: true,
                  ),
                if (overview?.paymentItems.isEmpty ?? true)
                  _SurfaceCard(
                    child: Text(
                      overviewState.paymentsIncomplete
                          ? l10n.coachPaymentsIncomplete
                          : l10n.coachNoPaymentsToReview,
                    ),
                  )
                else ...[
                  for (final item in overview!.paymentItems.take(3))
                    _paymentTile(context, ref, l10n, item, accountName, hidden, money, localDate),
                  if (overview.paymentItems.length > 3)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => setState(() => _showAllPayments = !_showAllPayments),
                        child: Text(_showAllPayments ? l10n.showLess : l10n.coachSeeMore),
                      ),
                    ),
                  if (_showAllPayments && overview.paymentItems.length > 3)
                    for (final item in overview.paymentItems.skip(3))
                      _paymentTile(context, ref, l10n, item, accountName, hidden, money, localDate),
                ],
              ],
              const SizedBox(height: 20),
              PlanningAttentionCard(userId: uid, amountsHidden: hidden),
              const SizedBox(height: 20),
              _sectionTitle(context, l10n.coachWeeklyUnderstanding),
              const SizedBox(height: 8),
              _weeklyInsight(
                context,
                l10n,
                overview,
                categories,
                hidden,
                money,
                reportIncomplete: overviewState.insightsIncomplete,
                onRetry: () => _refresh(uid),
              ),
              const SizedBox(height: 20),
              _sectionTitle(context, l10n.coachRoutineTitle),
              const SizedBox(height: 8),
              _routineCard(
                context,
                l10n,
                uid,
                routine,
                routineState,
                legacyPrefs.valueOrNull,
                completions,
                todayKey,
                weeklyKey,
                overview?.dailyReviewDue ?? false,
                overview?.weeklyReviewDue ?? false,
              ),
              const SizedBox(height: 20),
              _sectionTitle(context, l10n.coachHistoryTitle),
              const SizedBox(height: 8),
              _history(
                context,
                l10n,
                completionsState,
                completions,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/coach/settings'),
                icon: const Icon(Icons.notifications_outlined),
                label: Text(l10n.coachSettingsShortcut),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nextActionCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String uid,
    CoachAction? action,
    String? title,
    String? body,
    CoachOverviewLoadState state,
    List<FinanceAccount> accounts,
    bool isPriority,
    bool hidden,
  ) {
    final colors = Theme.of(context).colorScheme;
    if (state.loading) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(18), child: LinearProgressIndicator()),
      );
    }
    if (action == null) {
      return _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              state.actionIncomplete ? l10n.coachNoReliableRecommendation : l10n.coachReadFailure,
            ),
            TextButton(
              key: const ValueKey('coach_next_step_retry'),
              onPressed: () => _refresh(uid),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    final configured = action.kind == CoachActionKind.configureRoutines;
    return Card(
      color: isPriority ? colors.primaryContainer : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isPriority ? Icons.lightbulb_outline : Icons.check_circle_outline,
                  color: isPriority
                      ? colors.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            if (state.actionIncomplete) ...[
              Text(l10n.coachProvisionalRecommendation),
              const SizedBox(height: 8),
            ],
            Text(body!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () {
                  unawaited(
                    ref.read(firebaseObservabilityProvider)?.logEvent('coach_action_opened'),
                  );
                  if (configured) {
                    final target = _routineKey.currentContext;
                    if (target != null) {
                      unawaited(
                        Scrollable.ensureVisible(
                          target,
                          duration: const Duration(milliseconds: 250),
                          alignment: .1,
                        ),
                      );
                    } else if (_scrollController.hasClients) {
                      unawaited(
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                      );
                    }
                  } else if (action.operation != null) {
                    unawaited(
                      context.push<void>(coachActionRoute(action), extra: [action.operation]),
                    );
                  } else {
                    unawaited(context.push<void>(coachActionRoute(action)));
                  }
                },
                child: Text(coachActionButtonLabel(l10n, action.kind)),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(l10n.coachWhyThis),
                    content: Text(l10n.coachActionExplain),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(l10n.close),
                      ),
                    ],
                  ),
                ),
                child: Text(l10n.coachWhyThis),
              ),
            ),
            if (hidden && (action.remainingMinor != null || action.plannedMinor != null))
              Semantics(label: l10n.coachAmountsHidden, child: const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    CoachPaymentReviewItem item,
    String Function(String?) accountName,
    bool hidden,
    String Function(int, String) money,
    String Function(DateTime) localDate,
  ) {
    final unallocated = item.kind == CoachActionKind.unallocatedPayment;
    final title = unallocated ? l10n.coachActionUnallocatedTitle : accountName(item.debtAccountId);
    final date = unallocated
        ? localDate(item.dueDate)
        : DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(item.dueDate);
    final subtitle = unallocated
        ? '${l10n.coachActionUnallocatedBody} · ${l10n.coachPaymentRecordedDate(localDate(item.dueDate))}'
        : [
            l10n.coachPaymentDue(date),
            if (!hidden && item.paidMinor != null && item.plannedMinor != null)
              l10n.coachCommitmentProgress(
                money(item.paidMinor!, item.currency ?? 'COP'),
                money(item.plannedMinor!, item.currency ?? 'COP'),
              ),
            if (!hidden && item.remainingMinor != null)
              l10n.coachPaymentRemaining(money(item.remainingMinor!, item.currency ?? 'COP')),
          ].join(' · ');
    return Card(
      child: ListTile(
        minTileHeight: 76,
        leading: Icon(
          unallocated ? Icons.pending_actions_outlined : Icons.event_note_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          unawaited(ref.read(firebaseObservabilityProvider)?.logEvent('coach_action_opened'));
          if (item.operation != null) {
            final paymentId = item.operation!.paymentId ?? item.operation!.debtCommandId;
            unawaited(
              context.push<void>(
                Uri(
                  path: '/debts/${item.debtAccountId}/actions/allocatePayment',
                  queryParameters: {'paymentId': ?paymentId},
                ).toString(),
                extra: [item.operation],
              ),
            );
          } else {
            final action = CoachAction(
              kind: item.kind,
              id: item.id,
              debtAccountId: item.debtAccountId,
              bankAccountId: item.bankAccountId,
              commitmentId: item.commitmentId,
              monthKey: item.monthKey,
              currency: item.currency,
              plannedMinor: item.plannedMinor,
              paidMinor: item.paidMinor,
              remainingMinor: item.remainingMinor,
              dueDate: item.dueDate,
            );
            unawaited(context.push<void>(coachActionRoute(action)));
          }
        },
      ),
    );
  }

  Widget _weeklyInsight(
    BuildContext context,
    AppLocalizations l10n,
    CoachOverview? overview,
    List<FinanceCategory> categories,
    bool hidden,
    String Function(int, String) money, {
    required bool reportIncomplete,
    required VoidCallback onRetry,
  }) {
    if (overview == null || reportIncomplete || !overview.availability.weeklyReport) {
      return _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.coachReportIncomplete),
            TextButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    final insight = overview.insights
        .where((value) => value.kind == CoachInsightKind.largestWeeklyCategory)
        .firstOrNull;
    final incomplete = overview.insights.any(
      (value) => value.kind == CoachInsightKind.incompleteInformation,
    );
    final categoryName = insight == null
        ? null
        : categories.where((value) => value.id == insight.categoryId).firstOrNull?.customName ??
              l10n.category;
    final start = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(overview.weekStart);
    final end = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(overview.weekEndExclusive.subtract(const Duration(days: 1)));
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$start – $end', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (incomplete) ...[
            Text(l10n.coachIncompleteInfo),
            const SizedBox(height: 8),
          ],
          if (insight != null)
            Text(
              hidden
                  ? l10n.coachWeeklyCategoryInsight(categoryName!, '••••••')
                  : l10n.coachWeeklyCategoryInsight(
                      categoryName!,
                      money(insight.amountMinor ?? 0, insight.currency ?? 'COP'),
                    ),
            )
          else
            Text(l10n.coachNoRecords),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => context.push('/coach/weekly'),
              child: Text(l10n.coachReviewFullWeek),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routineCard(
    BuildContext context,
    AppLocalizations l10n,
    String uid,
    CoachRoutinePreferences? preference,
    AsyncValue<CoachRoutinePreferences> routineState,
    CoachPreferences? legacyPreferences,
    List<CoachCompletion> completions,
    String todayKey,
    String weeklyKey,
    bool dailyDue,
    bool weeklyDue,
  ) {
    if (routineState.isLoading && preference == null) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
      );
    }
    if (routineState.hasError && preference == null) {
      return _SurfaceCard(child: Text(l10n.coachReadFailure));
    }
    var current = preference ?? const CoachRoutinePreferences();
    if (!current.configured &&
        (legacyPreferences?.dailyEnabled == true || legacyPreferences?.weeklyEnabled == true)) {
      current = CoachRoutinePreferences.fromProfile(null, legacy: legacyPreferences!);
    }
    if (_routineDraft != null) current = _routineDraft!;
    final configured = current.configured;
    final dailyDone = completions.any(
      (item) => item.kind == CoachReviewKind.daily && item.periodKey == todayKey,
    );
    final weeklyDone = completions.any(
      (item) => item.kind == CoachReviewKind.weekly && item.periodKey == weeklyKey,
    );
    String routineStatus({
      required bool enabled,
      required bool due,
      required bool done,
      required String action,
    }) {
      if (done) return l10n.coachReviewed;
      if (!configured) return l10n.coachRoutineNotConfigured;
      if (!enabled) return l10n.coachRoutineOff;
      return due ? action : l10n.coachRoutineNotDue;
    }

    return Card(
      key: _routineKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!configured) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(l10n.coachRoutineInvite),
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('coach_invite_daily'),
                title: Text(l10n.coachRoutineDaily),
                value: _inviteDaily,
                onChanged: _routineSaving ? null : (value) => setState(() => _inviteDaily = value),
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('coach_invite_weekly'),
                title: Text(l10n.coachRoutineWeekly),
                value: _inviteWeekly,
                onChanged: _routineSaving ? null : (value) => setState(() => _inviteWeekly = value),
              ),
              if (_routineFailed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.coachRoutineSaveError,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      key: const ValueKey('coach_routine_later'),
                      onPressed: _routineSaving
                          ? null
                          : () =>
                                _saveRoutine(uid, const CoachRoutinePreferences(configured: true)),
                      child: Text(l10n.coachRoutineLater),
                    ),
                    FilledButton(
                      key: const ValueKey('coach_routine_start'),
                      onPressed: _routineSaving || (!_inviteDaily && !_inviteWeekly)
                          ? null
                          : () => _saveRoutine(
                              uid,
                              CoachRoutinePreferences(
                                configured: true,
                                dailyEnabled: _inviteDaily,
                                weeklyEnabled: _inviteWeekly,
                              ),
                            ),
                      child: Text(l10n.coachRoutineStart),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (_routineSaving) const LinearProgressIndicator(),
              if (current.hasPendingWrites)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(l10n.coachSavePending),
                ),
              if (_routineFailed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.coachRoutineSaveError,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                      TextButton(
                        onPressed: _routineSaving || _routineDraft == null
                            ? null
                            : () => _saveRoutine(uid, _routineDraft!),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              SwitchListTile.adaptive(
                title: Text(l10n.coachRoutineDaily),
                value: current.dailyEnabled,
                onChanged: _routineSaving
                    ? null
                    : (value) => _saveRoutine(
                        uid,
                        current.copyWith(configured: true, dailyEnabled: value),
                      ),
              ),
              SwitchListTile.adaptive(
                title: Text(l10n.coachRoutineWeekly),
                value: current.weeklyEnabled,
                onChanged: _routineSaving
                    ? null
                    : (value) => _saveRoutine(
                        uid,
                        current.copyWith(configured: true, weeklyEnabled: value),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  current.dailyEnabled || current.weeklyEnabled
                      ? l10n.coachRoutineOn
                      : l10n.coachRoutineOff,
                ),
              ),
            ],
            const Divider(height: 1),
            ListTile(
              minTileHeight: 60,
              leading: Icon(dailyDone ? Icons.check_circle_outline : Icons.today_outlined),
              title: Text(l10n.coachDailyTitle),
              subtitle: Text(
                routineStatus(
                  enabled: current.dailyEnabled,
                  due: dailyDue,
                  done: dailyDone,
                  action: l10n.coachDailyAction,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/coach/daily'),
            ),
            ListTile(
              minTileHeight: 60,
              leading: Icon(weeklyDone ? Icons.check_circle_outline : Icons.date_range_outlined),
              title: Text(l10n.coachWeeklyTitle),
              subtitle: Text(
                routineStatus(
                  enabled: current.weeklyEnabled,
                  due: weeklyDue,
                  done: weeklyDone,
                  action: l10n.coachWeeklyAction,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/coach/weekly'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _history(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<CoachCompletion>> state,
    List<CoachCompletion> completions,
  ) {
    if (state.isLoading) return const LinearProgressIndicator();
    if (state.hasError) return _SurfaceCard(child: Text(l10n.coachReadFailure));
    if (completions.isEmpty) return _SurfaceCard(child: Text(l10n.coachHistoryEmpty));
    final sorted = [...completions]
      ..sort((a, b) {
        final date = (b.reviewedAt ?? DateTime.tryParse(b.periodKey) ?? DateTime(0)).compareTo(
          a.reviewedAt ?? DateTime.tryParse(a.periodKey) ?? DateTime(0),
        );
        return date == 0 ? b.periodKey.compareTo(a.periodKey) : date;
      });
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final item in sorted.take(8))
            ListTile(
              minTileHeight: 58,
              leading: const Icon(Icons.task_alt_outlined),
              title: Text(
                item.kind == CoachReviewKind.daily ? l10n.coachDailyTitle : l10n.coachWeeklyTitle,
              ),
              subtitle: Text(item.periodKey),
              trailing: Text(item.pending ? l10n.coachSavePending : l10n.coachReviewed),
              onTap: () => context.push(
                item.kind == CoachReviewKind.daily
                    ? '/coach/daily?date=${item.periodKey}'
                    : '/coach/weekly?date=${item.periodKey}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String label) => Text(
    label,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  );
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.warning = false,
  });
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool warning;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning ? scheme.tertiary : scheme.primary;
    return Card(
      color: warning ? scheme.tertiaryContainer : scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
            if (actionLabel != null && onAction != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ),
          ],
        ),
      ),
    );
  }
}
