import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../finance/presentation/providers/canonical_finance_providers.dart';
import '../../domain/usecases/coach_overview.dart';
import '../coach_action_presentation.dart';
import '../providers/coach_providers.dart';

class CoachNextStepCard extends ConsumerWidget {
  const CoachNextStepCard({
    required this.userId,
    required this.timeZone,
    this.hidePlanningActions = false,
    super.key,
  });
  final String userId;
  final String timeZone;
  final bool hidePlanningActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(coachRepositoryProvider) == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(coachOverviewProvider(userId));
    final accounts = ref.watch(canonicalAccountsProvider(userId)).valueOrNull ?? const [];
    final colors = Theme.of(context).colorScheme;
    final action = state.overview?.action;
    if (hidePlanningActions &&
        (action == null ||
            {
              CoachActionKind.dueCommitment,
              CoachActionKind.upcomingCommitment,
              CoachActionKind.dueBudgetExpense,
              CoachActionKind.upcomingBudgetExpense,
            }.contains(action.kind))) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        key: const ValueKey('coach_next_step'),
        color: colors.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.coachNextStepTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (state.loading)
                const LinearProgressIndicator()
              else if (action == null) ...[
                Text(
                  state.actionIncomplete
                      ? l10n.coachNoReliableRecommendation
                      : l10n.coachReadFailure,
                ),
                TextButton(
                  key: const ValueKey('coach_next_step_retry'),
                  onPressed: () => retryCoachOverview(ref, userId),
                  child: Text(l10n.retry),
                ),
              ] else ...[
                if (state.actionIncomplete) ...[
                  Text(
                    l10n.coachProvisionalRecommendation,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  coachActionTitle(l10n, action, accounts),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  coachActionBody(
                    context,
                    l10n,
                    action,
                    amountsHidden: ref.watch(dashboardAmountsHiddenProvider),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () {
                    unawaited(
                      ref.read(firebaseObservabilityProvider)?.logEvent('coach_action_opened'),
                    );
                    _open(context, action);
                  },
                  child: Text(coachActionButtonLabel(l10n, action.kind)),
                ),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(l10n.coachWhyThis),
                      content: Text(l10n.coachActionExplain),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(l10n.close),
                        ),
                      ],
                    ),
                  ),
                  child: Text(l10n.coachWhyThis),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, CoachAction action) {
    final route = coachActionRoute(action);
    if (action.operation != null) {
      unawaited(context.push<void>(route, extra: [action.operation]));
    } else {
      unawaited(context.push<void>(route));
    }
  }
}
