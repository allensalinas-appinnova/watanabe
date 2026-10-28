import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../finance/domain/entities/finance_account.dart';
import '../domain/usecases/coach_overview.dart';

String coachActionTitle(
  AppLocalizations l10n,
  CoachAction action,
  List<FinanceAccount> accounts,
) {
  final account = accounts.where((item) => item.id == action.debtAccountId).firstOrNull;
  return switch (action.kind) {
    CoachActionKind.syncRejected => l10n.coachActionSyncTitle,
    CoachActionKind.dueCommitment => l10n.coachActionDueTitle(account?.name ?? l10n.accountName),
    CoachActionKind.unallocatedPayment => l10n.coachActionUnallocatedTitle,
    CoachActionKind.upcomingCommitment => l10n.coachActionUpcomingTitle(
      account?.name ?? l10n.accountName,
    ),
    CoachActionKind.budgetReached => l10n.coachActionBudgetTitle,
    CoachActionKind.weeklyReview => l10n.coachActionWeeklyTitle,
    CoachActionKind.dailyReview => l10n.coachActionDailyTitle,
    CoachActionKind.configureRoutines => l10n.coachActionConfigureTitle,
    CoachActionKind.current => l10n.coachAllCurrent,
  };
}

String coachActionBody(
  BuildContext context,
  AppLocalizations l10n,
  CoachAction action, {
  required bool amountsHidden,
}) {
  final locale = Localizations.localeOf(context).toString();
  String money(int amount, String currency) =>
      CurrencyFormatter.formatMinor(amount, currency, locale: locale);
  return switch (action.kind) {
    CoachActionKind.syncRejected => l10n.coachActionSyncBody,
    CoachActionKind.dueCommitment => [
      if (!amountsHidden && action.plannedMinor != null && action.paidMinor != null)
        l10n.coachCommitmentProgress(
          money(action.paidMinor!, action.currency ?? 'COP'),
          money(action.plannedMinor!, action.currency ?? 'COP'),
        ),
      l10n.coachActionDueBody,
    ].join(' '),
    CoachActionKind.unallocatedPayment => l10n.coachActionUnallocatedBody,
    CoachActionKind.upcomingCommitment => [
      if (action.dueDate != null)
        l10n.coachPaymentDue(DateFormat.yMMMd(locale).format(action.dueDate!)),
      if (!amountsHidden && action.remainingMinor != null)
        l10n.coachPaymentRemaining(money(action.remainingMinor!, action.currency ?? 'COP')),
    ].join(' · '),
    CoachActionKind.budgetReached =>
      amountsHidden || action.plannedMinor == null || action.paidMinor == null
          ? l10n.coachActionBudgetBody
          : l10n.coachActionBudgetProgress(
              money(action.paidMinor!, action.currency ?? 'COP'),
              money(action.plannedMinor!, action.currency ?? 'COP'),
            ),
    CoachActionKind.weeklyReview => l10n.coachWeeklyIntro,
    CoachActionKind.dailyReview => l10n.coachReviewIntro,
    CoachActionKind.configureRoutines => l10n.coachRoutineInvite,
    CoachActionKind.current => l10n.coachActionCurrentBody,
  };
}

String coachActionButtonLabel(AppLocalizations l10n, CoachActionKind kind) => switch (kind) {
  CoachActionKind.syncRejected => l10n.coachViewMovements,
  CoachActionKind.dueCommitment || CoachActionKind.upcomingCommitment => l10n.coachReviewPayment,
  CoachActionKind.unallocatedPayment => l10n.coachCompleteAllocation,
  CoachActionKind.budgetReached => l10n.coachReviewBudget,
  CoachActionKind.weeklyReview => l10n.coachWeeklyTitle,
  CoachActionKind.dailyReview || CoachActionKind.current => l10n.coachDailyTitle,
  CoachActionKind.configureRoutines => l10n.coachConfigure,
};

String coachActionRoute(CoachAction action) {
  switch (action.kind) {
    case CoachActionKind.syncRejected:
      return '/activity';
    case CoachActionKind.dueCommitment:
    case CoachActionKind.upcomingCommitment:
      final query = <String, String>{
        if (action.commitmentId != null) 'commitmentId': action.commitmentId!,
        if (action.monthKey != null) 'month': action.monthKey!,
        if (action.remainingMinor != null) 'amountMinor': '${action.remainingMinor}',
        if (action.bankAccountId != null) 'bankAccountId': action.bankAccountId!,
      };
      return Uri(
        path: '/debts/${action.debtAccountId}/actions/pay',
        queryParameters: query,
      ).toString();
    case CoachActionKind.unallocatedPayment:
      final paymentId = action.operation?.paymentId ?? action.operation?.debtCommandId;
      return Uri(
        path: '/debts/${action.debtAccountId}/actions/allocatePayment',
        queryParameters: {'paymentId': ?paymentId},
      ).toString();
    case CoachActionKind.budgetReached:
      return action.budgetId == null
          ? '/budgets/tracking?month=${action.monthKey ?? ''}'
          : '/budgets/${action.budgetId}';
    case CoachActionKind.weeklyReview:
      return '/coach/weekly${action.periodKey == null ? '' : '?date=${action.periodKey}'}';
    case CoachActionKind.dailyReview:
      return '/coach/daily${action.periodKey == null ? '' : '?date=${action.periodKey}'}';
    case CoachActionKind.configureRoutines:
    case CoachActionKind.current:
      return '/coach';
  }
}
