import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../finance/presentation/providers/canonical_finance_providers.dart';
import '../../domain/entities/coach_models.dart';
import '../../domain/services/coach_notification_service.dart';
import '../providers/coach_providers.dart';

class CoachLifecycle extends ConsumerStatefulWidget {
  const CoachLifecycle({required this.child, required this.onOpen, super.key});
  final Widget child;
  final void Function(String location) onOpen;
  @override
  ConsumerState<CoachLifecycle> createState() => _CoachLifecycleState();
}

class _CoachLifecycleState extends ConsumerState<CoachLifecycle> with WidgetsBindingObserver {
  bool _ready = false;
  String? _signature;
  String? _lastUid;
  int _generation = 0;
  Future<void> _updates = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final service = ref.read(coachNotificationServiceProvider);
    try {
      await service?.initialize(onOpen: _open);
      if (mounted) setState(() => _ready = true);
    } on Object {
      if (mounted) ref.read(coachSchedulingIssueProvider.notifier).set(true);
    }
  }

  void _open(CoachNotificationTarget target) {
    if (!mounted || ref.read(authSessionProvider).value == null) return;
    final date = Uri.encodeQueryComponent(target.periodKey);
    final location = switch (target.type) {
      CoachNotificationType.weekly => '/coach/weekly?date=$date',
      CoachNotificationType.daily => '/coach/daily?date=$date',
      CoachNotificationType.debtBefore ||
      CoachNotificationType.debtDue => '/budgets/debt-payments?month=$date',
    };
    widget.onOpen(location);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final uid = ref.read(authSessionProvider).value?.id;
    ref
      ..invalidate(coachPermissionProvider)
      ..invalidate(coachTickProvider)
      ..invalidate(coachReportProvider);
    if (uid != null) {
      ref
        ..invalidate(coachDeviceSettingsProvider(uid))
        ..invalidate(coachCompletionsProvider(uid))
        ..invalidate(coachPreferencesProvider(uid));
    }
    _signature = null;
    if (!_ready) unawaited(_initialize());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(coachNotificationServiceProvider);
    final revision = ref.watch(coachRescheduleProvider);
    ref.listen(coachRescheduleProvider, (_, _) {
      if (!_ready) unawaited(_initialize());
    });
    final session = ref.watch(authSessionProvider);
    final uid = session.value?.id;
    if (_lastUid != uid && !session.isLoading) {
      final previousUid = _lastUid;
      _lastUid = uid;
      ++_generation;
      _signature = null;
      if (uid == null || previousUid != null) {
        unawaited(service?.cancelAll().catchError((Object _) {}) ?? Future.value());
      }
    }
    if (!_ready || service == null || uid == null) return widget.child;
    final profile = ref.watch(canonicalUserProfileProvider(uid));
    final preferences = ref.watch(coachPreferencesProvider(uid));
    final completions = ref.watch(coachCompletionsProvider(uid));
    final commitments = ref.watch(debtCommitmentsProvider(uid));
    final commitmentPayments = ref.watch(debtCommitmentPaymentsProvider(uid));
    final device = ref.watch(coachDeviceSettingsProvider(uid));
    final permission = ref.watch(coachPermissionProvider);
    ref.watch(coachTickProvider);
    final l10n = AppLocalizations.of(context);
    if (profile.hasValue &&
        profile.value != null &&
        preferences.hasValue &&
        completions.hasValue &&
        commitments.hasValue &&
        commitmentPayments.hasValue &&
        device.hasValue &&
        permission.hasValue) {
      final signature = jsonEncode([
        uid,
        revision,
        profile.value!.timeZone,
        preferences.requireValue.toMap(),
        completions.requireValue
            .map((item) => '${item.kind.name}:${item.periodKey}:${item.pending}')
            .toList(),
        commitments.requireValue
            .map(
              (item) =>
                  '${item.id}:${item.amountMinor}:${item.remindersEnabled}:${item.pauseRanges}',
            )
            .toList(),
        commitmentPayments.requireValue
            .map((item) => '${item.paymentId}:${item.amountMinor}:${item.monthKey}')
            .toList(),
        device.requireValue.enabled,
        device.requireValue.pausedUntil?.toIso8601String(),
        permission.requireValue.name,
        l10n.coachNotificationTitle,
        ref.read(coachRoutineProvider).today(profile.value!.timeZone).toIso8601String(),
      ]);
      if (_signature != signature) {
        _signature = signature;
        final generation = ++_generation;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updates = _updates.then((_) async {
            if (!mounted || generation != _generation) return;
            try {
              final owner = await service.ownerTokenFor(uid);
              if (!mounted || generation != _generation) return;
              final planned = ref
                  .read(coachRoutineProvider)
                  .plan(
                    preferences: preferences.requireValue,
                    completions: completions.requireValue,
                    zone: profile.value!.timeZone,
                    pausedUntil: device.requireValue.pausedUntil,
                  );
              final routine = ref.read(coachRoutineProvider);
              final zone = profile.value!.timeZone;
              final now = routine.clock.now();
              final start = routine.today(zone);
              final debtByInstant = <DateTime, (CoachNotificationType, String)>{};
              for (var offset = 0; offset < 29; offset++) {
                final date = routine.shift(start, zone, offset);
                final monthKey =
                    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
                for (final commitment in commitments.requireValue) {
                  if (!commitment.remindersEnabled) continue;
                  final due = commitment.dueDateFor(monthKey);
                  if (due == null) continue;
                  final paid = commitmentPayments.requireValue
                      .where(
                        (link) => link.commitmentId == commitment.id && link.monthKey == monthKey,
                      )
                      .fold<int>(0, (sum, link) => sum + link.amountMinor);
                  if (paid >= commitment.amountMinor) continue;
                  for (final candidate in [
                    (routine.shift(due, zone, -1), CoachNotificationType.debtBefore),
                    (due, CoachNotificationType.debtDue),
                  ]) {
                    final instant = routine.calendar
                        .at(zone, candidate.$1.year, candidate.$1.month, candidate.$1.day, 9)
                        .toUtc();
                    if (instant.isAfter(now) &&
                        instant.difference(now) <= const Duration(days: 28)) {
                      debtByInstant.putIfAbsent(instant, () => (candidate.$2, monthKey));
                    }
                  }
                }
              }
              final notifications = <CoachNotification>[];
              for (var index = 0; index < planned.length; index++) {
                notifications.add(
                  CoachNotification(
                    id: 18000 + index,
                    scheduledAt: planned[index].scheduledAt,
                    type: planned[index].kind == CoachReviewKind.daily
                        ? CoachNotificationType.daily
                        : CoachNotificationType.weekly,
                    periodKey: planned[index].periodKey,
                    ownerToken: owner,
                  ),
                );
              }
              for (final entry in debtByInstant.entries) {
                if (notifications.any((item) => item.scheduledAt == entry.key)) continue;
                notifications.add(
                  CoachNotification(
                    id: 19000 + notifications.length,
                    scheduledAt: entry.key,
                    type: entry.value.$1,
                    periodKey: entry.value.$2,
                    ownerToken: owner,
                  ),
                );
              }
              await service.replaceSchedule(
                uid,
                notifications,
                title: l10n.coachNotificationTitle,
                body: l10n.coachNotificationBody,
              );
              if (!mounted || generation != _generation) return;
              ref.read(coachSchedulingIssueProvider.notifier).set(false);
              final target = service.takeInitialTarget();
              if (target != null) _open(target);
            } on Object {
              if (mounted && generation == _generation) {
                ref.read(coachSchedulingIssueProvider.notifier).set(true);
              }
            }
          });
        });
      }
    }
    return widget.child;
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
