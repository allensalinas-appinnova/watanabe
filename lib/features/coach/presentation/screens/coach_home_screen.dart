import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../finance/domain/entities/financial_operation.dart';
import '../../../finance/presentation/providers/canonical_finance_providers.dart';
import '../../domain/entities/coach_models.dart';
import '../../domain/usecases/coach_routine.dart';
import '../providers/coach_providers.dart';

class CoachHomeScreen extends ConsumerWidget {
  const CoachHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    if (ref.watch(coachRepositoryProvider) == null) {
      return Scaffold(body: Center(child: Text(l10n.coachReadFailure)));
    }
    ref.watch(coachTickProvider);
    final preferences = ref.watch(coachPreferencesProvider(uid));
    final completions = ref.watch(coachCompletionsProvider(uid));
    final profile = ref.watch(canonicalUserProfileProvider(uid)).valueOrNull;
    final recentOperations = ref.watch(canonicalRecentOperationsProvider(uid));
    final timeZone = profile?.timeZone ?? 'UTC';
    final routine = ref.watch(coachRoutineProvider);
    final loading = preferences.isLoading || completions.isLoading;
    final failed = preferences.hasError || completions.hasError;
    final step = !loading && !failed
        ? routine.nextStep(preferences.requireValue, completions.requireValue, timeZone)
        : CoachNextStep.current;
    final nextRoute = step == CoachNextStep.weekly ? '/coach/weekly' : '/coach/daily';
    final nextTitle = step == CoachNextStep.weekly ? l10n.coachWeeklyTitle : l10n.coachDailyTitle;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 104),
          children: [
            Text(
              l10n.coachHubTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.coachHubSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.coachNextStepTitle, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    if (loading)
                      const LinearProgressIndicator()
                    else if (failed) ...[
                      Text(l10n.coachReadFailure),
                      TextButton(
                        onPressed: () {
                          ref
                            ..invalidate(coachPreferencesProvider(uid))
                            ..invalidate(coachCompletionsProvider(uid));
                        },
                        child: Text(l10n.retry),
                      ),
                    ] else ...[
                      Text(
                        step == CoachNextStep.current
                            ? l10n.coachAllCurrent
                            : step == CoachNextStep.weekly
                            ? l10n.coachWeeklyAction
                            : l10n.coachDailyAction,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.push(
                          step == CoachNextStep.current ? '/coach/daily' : nextRoute,
                        ),
                        child: Text(
                          step == CoachNextStep.current ? l10n.coachDailyTitle : nextTitle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            recentOperations.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
              error: (_, _) => const SizedBox.shrink(),
              data: (operations) {
                final unresolved = operations
                    .where(
                      (operation) =>
                          operation.type == OperationType.unallocatedDebtPayment &&
                          operation.status == OperationStatus.confirmed &&
                          operation.projectionDirection == 1 &&
                          operation.allocationStatus == 'unallocated' &&
                          operation.debtAccountId != null,
                    )
                    .toList(growable: false);
                if (unresolved.isEmpty) return const SizedBox.shrink();
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.debtPaymentsToReview,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final operation in unresolved)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.pending_actions_outlined),
                            title: Text(l10n.debtPayUnallocated),
                            subtitle: Text(
                              operation.occurredAt.toLocal().toString().split(' ').first,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              '/debts/${operation.debtAccountId}/actions/allocatePayment',
                              extra: [operation],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _RoutineTile(
              icon: Icons.today_outlined,
              title: l10n.coachDailyTitle,
              subtitle: l10n.coachDailyAction,
              onTap: () => context.push('/coach/daily'),
            ),
            const SizedBox(height: 10),
            _RoutineTile(
              icon: Icons.date_range_outlined,
              title: l10n.coachWeeklyTitle,
              subtitle: l10n.coachWeeklyAction,
              onTap: () => context.push('/coach/weekly'),
            ),
            const SizedBox(height: 22),
            Text(
              l10n.coachHistoryTitle,
              style:
                  Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (loading)
              const LinearProgressIndicator()
            else if (failed)
              Text(l10n.coachReadFailure)
            else if (completions.requireValue.isEmpty)
              Text(
                l10n.coachHistoryEmpty,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              )
            else
              for (final item in completions.requireValue.take(8))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.check_circle_outline, color: context.appColors.income),
                  title: Text(
                    item.kind == CoachReviewKind.daily
                        ? l10n.coachDailyTitle
                        : l10n.coachWeeklyTitle,
                  ),
                  subtitle: Text(item.periodKey),
                  trailing: Text(item.pending ? l10n.coachSavePending : l10n.coachReviewed),
                  onTap: () => context.push(
                    item.kind == CoachReviewKind.daily
                        ? '/coach/daily?date=${item.periodKey}'
                        : '/coach/weekly?date=${item.periodKey}',
                  ),
                ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/coach/settings'),
              icon: const Icon(Icons.notifications_outlined),
              label: Text(l10n.coachSettingsShortcut),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      minTileHeight: 72,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
