import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../finance/domain/entities/financial_operation.dart';
import '../../../finance/presentation/providers/canonical_finance_providers.dart';
import '../../domain/entities/coach_models.dart';
import '../../domain/usecases/coach_routine.dart';
import '../providers/coach_providers.dart';
import '../widgets/coach_panel.dart';

class CoachReviewScreen extends ConsumerStatefulWidget {
  const CoachReviewScreen({required this.kind, this.periodKey, super.key});
  final CoachReviewKind kind;
  final String? periodKey;
  @override
  ConsumerState<CoachReviewScreen> createState() => _CoachReviewScreenState();
}

class _CoachReviewScreenState extends ConsumerState<CoachReviewScreen> {
  bool _saving = false;
  bool _failed = false;
  bool _noMovements = false;
  CoachWriteState? _saved;
  String? _resolvedPeriodKey;
  String? _resolvedZone;
  String? _activeUid;
  int _writeGeneration = 0;
  bool _declarationUnavailable = false;

  @override
  void didUpdateWidget(CoachReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind || oldWidget.periodKey != widget.periodKey) {
      _resolvedPeriodKey = null;
      _resolvedZone = null;
      _saved = null;
      _failed = false;
      _saving = false;
      ++_writeGeneration;
    }
  }

  Future<void> _complete(String uid, String key, bool noMovements) async {
    if (ref.read(authSessionProvider).value?.id != uid) return;
    final generation = ++_writeGeneration;
    setState(() {
      _saving = true;
      _failed = false;
      _noMovements = noMovements;
      _declarationUnavailable = false;
    });
    if (noMovements) {
      final routine = ref.read(coachRoutineProvider);
      final date = routine.parseDay(key, _resolvedZone!);
      final verified = await ref
          .read(coachRepositoryProvider)!
          .loadReport(
            uid,
            startAt: date.toUtc(),
            endAtExclusive: routine.shift(date, _resolvedZone!, 1).toUtc(),
          );
      if (!mounted ||
          generation != _writeGeneration ||
          ref.read(authSessionProvider).value?.id != uid) {
        return;
      }
      final allowed = verified.match(
        (_) => null,
        (report) => report.freshness == CoachFreshness.fresh && report.operations.isEmpty,
      );
      if (allowed != true) {
        setState(() {
          _saving = false;
          _failed = allowed == null;
          _declarationUnavailable = allowed == false;
        });
        ref.invalidate(coachReportProvider);
        return;
      }
    }
    final result = await ref
        .read(coachRepositoryProvider)!
        .complete(uid, periodKey: key, kind: widget.kind, noMovements: noMovements);
    if (!mounted ||
        generation != _writeGeneration ||
        ref.read(authSessionProvider).value?.id != uid) {
      return;
    }
    setState(() {
      _saving = false;
      result.match((_) => _failed = true, (value) => _saved = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).value?.id;
    if (_activeUid != uid) {
      _activeUid = uid;
      ++_writeGeneration;
      _resolvedPeriodKey = null;
      _resolvedZone = null;
      _saved = null;
      _failed = false;
      _saving = false;
      _declarationUnavailable = false;
    }
    if (uid != null) {
      ref.listen(coachWriteFailureProvider(uid), (_, next) {
        if (next.hasValue &&
            mounted &&
            _resolvedPeriodKey != null &&
            next.requireValue.commandKey == '${widget.kind.name}:$_resolvedPeriodKey') {
          setState(() {
            _saved = null;
            _failed = true;
          });
        }
      });
    }
    final weekly = widget.kind == CoachReviewKind.weekly;
    final title = weekly ? l10n.coachWeeklyTitle : l10n.coachDailyTitle;
    final header = FinanceRouteHeader(
      title: title,
      backLabel: l10n.back,
      onBack: () => popOrGo(context, '/home'),
    );
    if (uid == null) {
      return Scaffold(
        appBar: header,
        body: Center(child: Text(l10n.sessionExpired)),
      );
    }
    final profile = ref.watch(canonicalUserProfileProvider(uid));
    if (profile.isLoading) {
      return Scaffold(
        appBar: header,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (profile.hasError || profile.value == null) {
      return Scaffold(
        appBar: header,
        body: Center(child: Text(l10n.coachReadFailure)),
      );
    }
    final zone = _resolvedZone ??= profile.requireValue!.timeZone;
    final routine = ref.watch(coachRoutineProvider);
    final today = routine.today(zone);
    DateTime start;
    try {
      final requestedKey = _resolvedPeriodKey ?? widget.periodKey;
      start = requestedKey == null
          ? weekly
                ? routine.previousWeek(zone)
                : today
          : routine.parseDay(requestedKey, zone);
      if (start.isAfter(today) ||
          (weekly &&
              (start.weekday != DateTime.monday ||
                  !start.isBefore(routine.shift(today, zone, 1 - today.weekday))))) {
        throw const FormatException('future-coach-review');
      }
    } on FormatException {
      return Scaffold(
        appBar: header,
        body: Center(child: Text(l10n.coachReadFailure)),
      );
    }
    final key = coachDateKey(start);
    _resolvedPeriodKey = key;
    final end = routine.shift(start, zone, weekly ? 7 : 1);
    final request = (userId: uid, startAt: start.toUtc(), endAtExclusive: end.toUtc());
    final report = ref.watch(coachReportProvider(request));
    final completions = ref.watch(coachCompletionsProvider(uid));
    final selectedCompletion = ref.watch(
      coachSelectedCompletionProvider((userId: uid, kind: widget.kind, periodKey: key)),
    );
    final matching =
        selectedCompletion.value ??
        completions.value
            ?.where((item) => item.kind == widget.kind && item.periodKey == key)
            .firstOrNull;
    final reviewed = matching != null || _saved != null;
    final pending =
        matching?.pending == true || (_saved == CoachWriteState.pending && matching == null);
    final locale = Localizations.localeOf(context).toString();
    String money(int amount, String currency) =>
        CurrencyFormatter.formatMinor(amount, currency, locale: locale);
    final categories = ref.watch(canonicalCategoriesProvider(uid)).value ?? const [];
    String category(String id) =>
        categories.where((item) => item.id == id).firstOrNull?.customName ?? l10n.category;
    Future<void> register(String location) async {
      final at = routine.calendar.at(zone, start.year, start.month, start.day, 12).toUtc();
      final uri = Uri.parse(location);
      await context.push(
        uri
            .replace(queryParameters: {...uri.queryParameters, 'occurredAt': at.toIso8601String()})
            .toString(),
      );
      if (mounted) ref.invalidate(coachReportProvider(request));
    }

    return Scaffold(
      appBar: header,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(coachCompletionsProvider(uid));
          final _ = await ref.refresh(coachReportProvider(request).future);
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              weekly
                  ? '${DateFormat.yMMMd(locale).format(start)} – ${DateFormat.yMMMd(locale).format(routine.shift(end, zone, -1))}'
                  : DateFormat.yMMMMEEEEd(locale).format(start),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('${l10n.timeZone}: $zone'),
            const SizedBox(height: 12),
            Text(weekly ? l10n.coachWeeklyIntro : l10n.coachReviewIntro),
            const SizedBox(height: 16),
            if (selectedCompletion.hasError) Text(l10n.coachReadFailure),
            if (reviewed)
              Semantics(
                liveRegion: true,
                child: Text(
                  pending ? l10n.coachSavePending : l10n.coachReviewed,
                  key: const ValueKey('coach_reviewed'),
                  style: const TextStyle(color: AppColors.green),
                ),
              ),
            if (matching?.reviewedAt != null)
              Text(
                DateFormat.yMMMd(
                  locale,
                ).add_Hm().format(routine.calendar.local(matching!.reviewedAt!, zone)),
              ),
            report.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Column(
                children: [
                  Text(l10n.coachReadFailure),
                  TextButton(
                    onPressed: () => ref.invalidate(coachReportProvider(request)),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
              data: (value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (value.freshness == CoachFreshness.cached)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l10n.coachCached),
                    ),
                  _metric(context, l10n.coachConfirmedCount, '${value.confirmedCount}'),
                  if (value.pendingCount > 0)
                    _metric(context, l10n.coachPendingCount, '${value.pendingCount}'),
                  if (value.rejectedCount > 0)
                    _metric(context, l10n.coachRejectedCount, '${value.rejectedCount}'),
                  ...[
                    for (final total in value.totalsByCurrency.values)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _metric(
                                context,
                                l10n.income,
                                money(total.incomeMinor, total.currency),
                              ),
                              _metric(
                                context,
                                l10n.expense,
                                money(total.expenseMinor, total.currency),
                              ),
                              _metric(
                                context,
                                l10n.activityTotalsNet,
                                money(total.netMinor, total.currency),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (weekly && value.topCategoriesByCurrency.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      CoachPanel(
                        children: [
                          Text(
                            l10n.coachTopCategories,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          for (final list in value.topCategoriesByCurrency.values)
                            for (final entry in list.take(3))
                              _metric(
                                context,
                                category(entry.categoryId),
                                money(entry.amountMinor, entry.currency),
                              ),
                        ],
                      ),
                    ],
                  ],
                  if (value.operations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(l10n.coachNoRecords),
                    ),
                  if (!weekly || value.pendingCount + value.rejectedCount > 0)
                    for (final operation in value.operations.where(
                      (item) => !weekly || item.status != OperationStatus.confirmed,
                    ))
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                operation.description.isEmpty
                                    ? switch (operation.type) {
                                        OperationType.income => l10n.income,
                                        OperationType.expense => l10n.expense,
                                        OperationType.transfer => l10n.transfer,
                                        OperationType.expenseRefund => l10n.debtRefund,
                                        OperationType.debtAdjustment => l10n.debtAdjust,
                                      }
                                    : operation.description,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(switch (operation.status) {
                                OperationStatus.confirmed => l10n.coachConfirmedCount,
                                OperationStatus.pending => l10n.coachPendingCount,
                                OperationStatus.rejected => l10n.coachRejectedCount,
                              }),
                              Text(
                                money(operation.amountMinor, operation.currency),
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: 20),
                  if (!weekly) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => register('/operations/new?type=income'),
                          child: Text(l10n.income),
                        ),
                        OutlinedButton(
                          onPressed: () => register('/operations/new?type=expense'),
                          child: Text(l10n.expense),
                        ),
                        OutlinedButton(
                          onPressed: () => register('/transfers/new'),
                          child: Text(l10n.transfer),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_declarationUnavailable) Text(l10n.coachNoMovementsUnavailable),
                  if (_failed) ...[
                    Text(l10n.coachSaveFailed),
                    TextButton(
                      onPressed: _saving ? null : () => _complete(uid, key, _noMovements),
                      child: Text(l10n.retry),
                    ),
                  ],
                  FilledButton(
                    key: const ValueKey('coach_complete'),
                    onPressed: _saving ? null : () => _complete(uid, key, false),
                    child: _saving
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator())
                        : Text(weekly ? l10n.coachFinishWeekly : l10n.coachFinishDaily),
                  ),
                  if (!weekly &&
                      key == coachDateKey(today) &&
                      value.operations.isEmpty &&
                      value.freshness == CoachFreshness.fresh)
                    OutlinedButton(
                      key: const ValueKey('coach_no_movements'),
                      onPressed: _saving ? null : () => _complete(uid, key, true),
                      child: Text(l10n.coachNoMovements),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final value = Text(
          amount,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.titleSmall,
        );
        if (constraints.maxWidth < 310 || MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text(label), value],
          );
        }
        return Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(child: value),
          ],
        );
      },
    ),
  );
}
