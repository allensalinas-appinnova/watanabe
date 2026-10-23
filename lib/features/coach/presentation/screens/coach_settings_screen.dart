import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/finance_route_header.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../finance/presentation/providers/canonical_finance_providers.dart';
import '../../domain/entities/coach_models.dart';
import '../../domain/services/coach_notification_service.dart';
import '../providers/coach_providers.dart';
import '../widgets/coach_panel.dart';

class CoachSettingsScreen extends ConsumerStatefulWidget {
  const CoachSettingsScreen({super.key});
  @override
  ConsumerState<CoachSettingsScreen> createState() => _CoachSettingsScreenState();
}

class _CoachSettingsScreenState extends ConsumerState<CoachSettingsScreen> {
  CoachPreferences? _draft;
  bool _saving = false;
  bool _failed = false;
  bool _deviceBusy = false;
  CoachWriteState? _writeState;
  String? _ownerUid;
  int _writeGeneration = 0;

  Future<void> _save(String uid, CoachPreferences preferences) async {
    if (ref.read(authSessionProvider).value?.id != uid) return;
    final generation = ++_writeGeneration;
    setState(() {
      _draft = preferences;
      _saving = true;
      _failed = false;
    });
    final result = await ref.read(coachRepositoryProvider)!.savePreferences(uid, preferences);
    if (!mounted ||
        generation != _writeGeneration ||
        ref.read(authSessionProvider).value?.id != uid) {
      return;
    }
    setState(() {
      _saving = false;
      result.match((_) => _failed = true, (state) => _writeState = state);
    });
  }

  Future<void> _device(
    String uid,
    Future<void> Function(CoachNotificationService service) action,
  ) async {
    final service = ref.read(coachNotificationServiceProvider);
    if (service == null) return;
    setState(() => _deviceBusy = true);
    try {
      await action(service);
      ref
        ..invalidate(coachDeviceSettingsProvider(uid))
        ..invalidate(coachPermissionProvider);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).coachSaveFailed)));
      }
    } finally {
      if (mounted) setState(() => _deviceBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).value?.id;
    if (_ownerUid != uid) {
      _ownerUid = uid;
      ++_writeGeneration;
      _draft = null;
      _saving = false;
      _failed = false;
      _deviceBusy = false;
      _writeState = null;
    }
    final title = l10n.coachTitle;
    if (uid == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final state = ref.watch(coachPreferencesProvider(uid));
    ref.listen(coachWriteFailureProvider(uid), (_, next) {
      if (next.hasValue && mounted && next.requireValue.commandKey == 'preferences') {
        setState(() {
          _failed = true;
          _writeState = null;
        });
      }
    });
    final preferences = _draft ?? state.value ?? const CoachPreferences();
    ref.listen(coachPreferencesProvider(uid), (_, next) {
      if (!_saving && !_failed && next.hasValue && mounted) {
        if (_writeState == CoachWriteState.pending &&
            _draft != null &&
            jsonEncode(next.requireValue.toMap()) != jsonEncode(_draft!.toMap())) {
          return;
        }
        setState(() {
          _draft = next.requireValue;
          if (!next.requireValue.hasPendingWrites) _writeState = CoachWriteState.confirmed;
        });
      }
    });
    final zone = ref.watch(canonicalUserProfileProvider(uid)).value?.timeZone ?? 'UTC';
    final device = ref.watch(coachDeviceSettingsProvider(uid));
    final permission = ref.watch(coachPermissionProvider);
    final supported = ref.watch(coachNotificationServiceProvider)?.supported ?? false;
    final now = ref.watch(coachClockProvider).now();
    final paused = device.value?.pausedUntil?.isAfter(now) ?? false;
    String weekday(int day) =>
        DateFormat.EEEE(Localizations.localeOf(context).toString()).format(DateTime(2024, 1, day));
    Future<void> pickTime(bool weekly) async {
      final selected = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: weekly ? preferences.weeklyHour : preferences.dailyHour,
          minute: weekly ? preferences.weeklyMinute : preferences.dailyMinute,
        ),
      );
      if (selected == null || !mounted) return;
      await _save(
        uid,
        weekly
            ? preferences.copyWith(weeklyHour: selected.hour, weeklyMinute: selected.minute)
            : preferences.copyWith(dailyHour: selected.hour, dailyMinute: selected.minute),
      );
    }

    return Scaffold(
      appBar: FinanceRouteHeader(
        title: title,
        backLabel: l10n.back,
        onBack: () => popOrGo(context, '/home'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.coachReadFailure),
              TextButton(
                onPressed: () => ref.invalidate(coachPreferencesProvider(uid)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (_) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(l10n.coachSettingsIntro),
            const SizedBox(height: 12),
            Text('${l10n.timeZone}: $zone'),
            const SizedBox(height: 16),
            if (_saving) const LinearProgressIndicator(),
            if (_failed) ...[
              Text(l10n.coachSaveFailed),
              TextButton(onPressed: () => _save(uid, preferences), child: Text(l10n.retry)),
            ],
            if (state.value?.hasPendingWrites == true || _writeState == CoachWriteState.pending)
              Text(l10n.coachPreferencesPending, semanticsLabel: l10n.coachPreferencesPending),
            if (ref.watch(coachSchedulingIssueProvider)) ...[
              Text(l10n.coachScheduleFailed),
              TextButton(
                onPressed: () => ref.read(coachRescheduleProvider.notifier).retry(),
                child: Text(l10n.retry),
              ),
            ],
            CoachPanel(
              children: [
                SwitchListTile.adaptive(
                  key: const ValueKey('coach_daily_enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.coachDailyReminder),
                  value: preferences.dailyEnabled,
                  onChanged: _saving
                      ? null
                      : (value) => _save(uid, preferences.copyWith(dailyEnabled: value)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.coachReminderTime),
                  trailing: Text(
                    TimeOfDay(
                      hour: preferences.dailyHour,
                      minute: preferences.dailyMinute,
                    ).format(context),
                  ),
                  onTap: _saving ? null : () => pickTime(false),
                ),
                Text(l10n.coachReminderDays),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                        key: ValueKey('coach_daily_day_$day'),
                        label: Text(weekday(day)),
                        selected: preferences.dailyWeekdays.contains(day),
                        onSelected: _saving
                            ? null
                            : (selected) {
                                final days = {...preferences.dailyWeekdays};
                                if (selected) {
                                  days.add(day);
                                } else {
                                  days.remove(day);
                                }
                                if (days.isNotEmpty) {
                                  _save(uid, preferences.copyWith(dailyWeekdays: days));
                                }
                              },
                      ),
                  ],
                ),
              ],
            ),
            CoachPanel(
              children: [
                SwitchListTile.adaptive(
                  key: const ValueKey('coach_weekly_enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.coachWeeklyReminder),
                  value: preferences.weeklyEnabled,
                  onChanged: _saving
                      ? null
                      : (value) => _save(uid, preferences.copyWith(weeklyEnabled: value)),
                ),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: preferences.weeklyWeekday,
                  decoration: InputDecoration(labelText: l10n.coachReminderDays),
                  items: [
                    for (var day = 1; day <= 7; day++)
                      DropdownMenuItem(value: day, child: Text(weekday(day))),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) _save(uid, preferences.copyWith(weeklyWeekday: value));
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.coachReminderTime),
                  trailing: Text(
                    TimeOfDay(
                      hour: preferences.weeklyHour,
                      minute: preferences.weeklyMinute,
                    ).format(context),
                  ),
                  onTap: _saving ? null : () => pickTime(true),
                ),
              ],
            ),
            CoachPanel(
              children: [
                Text(l10n.coachDevice, style: Theme.of(context).textTheme.titleMedium),
                SwitchListTile.adaptive(
                  key: const ValueKey('coach_device_enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.coachEnableDevice),
                  value: device.value?.enabled ?? false,
                  onChanged: !supported || _deviceBusy || !device.hasValue
                      ? null
                      : (enabled) => _device(uid, (service) async {
                          final allowed =
                              !enabled ||
                              await service.requestPermission() == CoachPermission.granted;
                          await service.saveDeviceSettings(
                            uid,
                            CoachDeviceSettings(
                              enabled: enabled && allowed,
                              pausedUntil: device.value?.pausedUntil,
                            ),
                          );
                        }),
                ),
                if (device.hasError || permission.hasError) Text(l10n.coachReadFailure),
                Text(switch (permission.value) {
                  CoachPermission.granted => l10n.coachPermissionGranted,
                  CoachPermission.denied => l10n.coachPermissionDenied,
                  CoachPermission.unsupported => l10n.coachUnsupported,
                  _ => supported ? l10n.coachPermissionUnknown : l10n.coachUnsupported,
                }),
                if (permission.value == CoachPermission.denied)
                  TextButton(
                    onPressed: _deviceBusy
                        ? null
                        : () => _device(uid, (service) => service.openSettings()),
                    child: Text(l10n.coachOpenSettings),
                  ),
              ],
            ),
            if (paused) Text(l10n.coachPaused),
            if (supported)
              OutlinedButton(
                onPressed: _deviceBusy || !device.hasValue
                    ? null
                    : () => _device(
                        uid,
                        (service) => service.saveDeviceSettings(
                          uid,
                          CoachDeviceSettings(
                            enabled: device.requireValue.enabled,
                            pausedUntil: paused ? null : now.add(const Duration(days: 7)),
                          ),
                        ),
                      ),
                child: Text(paused ? l10n.coachResume : l10n.coachPause),
              ),
            const SizedBox(height: 12),
            Text(l10n.coachDevicePrivacy),
            const SizedBox(height: 8),
            Text(l10n.coachWindowNotice),
            const SizedBox(height: 8),
            Text(l10n.coachReminderTiming),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => context.push('/coach/daily'),
              child: Text(l10n.coachDailyTitle),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push('/coach/weekly'),
              child: Text(l10n.coachWeeklyTitle),
            ),
          ],
        ),
      ),
    );
  }
}
