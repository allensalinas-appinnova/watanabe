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
    widget.onOpen(
      target.type == CoachNotificationType.weekly
          ? '/coach/weekly?date=$date'
          : '/coach/daily?date=$date',
    );
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
    final device = ref.watch(coachDeviceSettingsProvider(uid));
    final permission = ref.watch(coachPermissionProvider);
    ref.watch(coachTickProvider);
    final l10n = AppLocalizations.of(context);
    if (profile.hasValue &&
        profile.value != null &&
        preferences.hasValue &&
        completions.hasValue &&
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
              await service.replaceSchedule(
                uid,
                [
                  for (var index = 0; index < planned.length; index++)
                    CoachNotification(
                      id: 18000 + index,
                      scheduledAt: planned[index].scheduledAt,
                      type: planned[index].kind == CoachReviewKind.daily
                          ? CoachNotificationType.daily
                          : CoachNotificationType.weekly,
                      periodKey: planned[index].periodKey,
                      ownerToken: owner,
                    ),
                ],
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
