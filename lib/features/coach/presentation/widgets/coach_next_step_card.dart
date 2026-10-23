import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/usecases/coach_routine.dart';
import '../providers/coach_providers.dart';

class CoachNextStepCard extends ConsumerWidget {
  const CoachNextStepCard({required this.userId, required this.timeZone, super.key});
  final String userId;
  final String timeZone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(coachRepositoryProvider) == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    ref.watch(coachTickProvider);
    final preferences = ref.watch(coachPreferencesProvider(userId));
    final completions = ref.watch(coachCompletionsProvider(userId));
    final loading = preferences.isLoading || completions.isLoading;
    final failed = preferences.hasError || completions.hasError;
    final routine = ref.watch(coachRoutineProvider);
    final step = !loading && !failed
        ? routine.nextStep(preferences.requireValue, completions.requireValue, timeZone)
        : CoachNextStep.current;
    final label = switch (step) {
      CoachNextStep.weekly => l10n.coachWeeklyAction,
      CoachNextStep.daily => l10n.coachDailyAction,
      CoachNextStep.current => l10n.coachAllCurrent,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        key: const ValueKey('coach_next_step'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.coachNextStepTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (loading)
                const LinearProgressIndicator()
              else if (failed) ...[
                Text(l10n.coachReadFailure),
                TextButton(
                  onPressed: () {
                    ref
                      ..invalidate(coachPreferencesProvider(userId))
                      ..invalidate(coachCompletionsProvider(userId));
                  },
                  child: Text(l10n.retry),
                ),
              ] else ...[
                Text(label, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () =>
                      context.push(step == CoachNextStep.weekly ? '/coach/weekly' : '/coach/daily'),
                  child: Text(
                    step == CoachNextStep.weekly ? l10n.coachWeeklyTitle : l10n.coachDailyTitle,
                  ),
                ),
              ],
              TextButton(
                onPressed: () => context.push('/coach/settings'),
                child: Text(l10n.coachConfigure),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
