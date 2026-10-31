import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection.dart';
import '../../../core/routing/finance_route_header.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/request_id.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../finance/presentation/providers/canonical_finance_providers.dart';
import '../../finance/presentation/widgets/planning_follow_up_controls.dart';
import '../domain/commitment_repository.dart';
import '../domain/debt_commitment.dart';

class DebtCommitmentDetailScreen extends ConsumerWidget {
  const DebtCommitmentDetailScreen({required this.commitmentId, this.initialMonthKey, super.key});
  final String commitmentId;
  final String? initialMonthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final plans = ref.watch(debtCommitmentsProvider(uid));
    final links = ref.watch(debtCommitmentPaymentsProvider(uid));
    final accounts = ref.watch(canonicalAccountsProvider(uid));
    final monthKey =
        initialMonthKey ?? DateFormat('yyyy-MM').format(ref.watch(planningMonthProvider(uid)));
    return Scaffold(
      appBar: FinanceRouteHeader(
        title: l10n.debtCommitmentsTitle,
        backLabel: l10n.back,
        onBack: () => popOrGo(context, '/budgets/debt-payments?month=$monthKey'),
      ),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(debtCommitmentsProvider(uid)),
            child: Text(l10n.retry),
          ),
        ),
        data: (items) {
          final plan = items
              .where((item) => item.id == commitmentId)
              .firstOrNull
              ?.forMonth(monthKey);
          if (plan == null) return Center(child: Text(l10n.genericError));
          if (links.isLoading || accounts.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (links.hasError || accounts.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => ref
                  ..invalidate(debtCommitmentPaymentsProvider(uid))
                  ..invalidate(canonicalAccountsProvider(uid)),
                child: Text(l10n.retry),
              ),
            );
          }
          final paidLinks = links.requireValue
              .where((item) => item.commitmentId == plan.id && item.monthKey == monthKey)
              .toList();
          final paid = paidLinks.fold<int>(0, (total, item) => total + item.amountMinor);
          final occurrence = DebtCommitmentOccurrence(
            commitment: plan,
            monthKey: monthKey,
            paidMinor: paid,
            skipped: plan.isSkipped(monthKey),
          );
          final account = accounts.requireValue
              .where((item) => item.id == plan.debtAccountId)
              .firstOrNull;
          final locale = Localizations.localeOf(context).toString();
          String money(int value) =>
              CurrencyFormatter.formatMinor(value, plan.currency, locale: locale);
          final due = plan.scheduledDateFor(monthKey);
          final agenda = ref.watch(
            planningAgendaEntriesProvider((userId: uid, monthKey: monthKey)),
          );
          final entry = agenda.valueOrNull
              ?.where((item) => item.commitmentId == commitmentId)
              .firstOrNull;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              if (entry != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: PlanningFollowUpButton(
                    userId: uid,
                    entry: entry,
                    itemName: account?.name ?? l10n.debtTitle,
                  ),
                ),
              Text(
                account?.name ?? l10n.debtTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (due != null) Text(DateFormat.yMMMd(locale).format(due)),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l10n.debtCommitmentAmount}: ${money(plan.amountMinor)}'),
                      Text('${l10n.debtCommitmentPaid}: ${money(paid)}'),
                      Text('${l10n.debtCommitmentRemaining}: ${money(occurrence.remainingMinor)}'),
                      Text(_statusLabel(l10n, occurrence.status)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.debtCommitmentPaid, style: Theme.of(context).textTheme.titleMedium),
              for (final link in paidLinks)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(money(link.amountMinor)),
                  subtitle: Text(link.paymentId),
                ),
              if (occurrence.remainingMinor > 0 &&
                  !plan.isPausedFor(monthKey) &&
                  !plan.isSkipped(monthKey))
                FilledButton.icon(
                  key: const ValueKey('commitment_register_payment'),
                  onPressed: () => context.push(
                    '/debts/${plan.debtAccountId}/actions/pay?commitmentId=${plan.id}&month=$monthKey&amountMinor=${occurrence.remainingMinor}${plan.bankAccountId == null ? '' : '&bankAccountId=${plan.bankAccountId}'}',
                  ),
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(l10n.debtPay),
                ),
              OutlinedButton.icon(
                key: const ValueKey('commitment_link_existing_payment'),
                onPressed: () => _linkExisting(
                  context,
                  ref,
                  uid,
                  plan,
                  monthKey,
                  links.requireValue.map((link) => link.paymentId).toSet(),
                ),
                icon: const Icon(Icons.link),
                label: Text(l10n.debtLinkExistingPayment),
              ),
              if (paid == 0 && occurrence.plannedMinor > 0 && !plan.isSkipped(monthKey))
                TextButton(
                  onPressed: () => _skip(context, ref, uid, plan, monthKey),
                  child: Text(l10n.debtCommitmentSkip),
                ),
              TextButton(
                onPressed: () => _pause(context, ref, uid, plan, monthKey),
                child: Text(
                  plan.isPausedFor(monthKey) ? l10n.debtCommitmentResume : l10n.debtCommitmentPause,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, DebtInstallmentStatus status) => switch (status) {
    DebtInstallmentStatus.upcoming => l10n.debtCommitmentStatusUpcoming,
    DebtInstallmentStatus.due => l10n.debtCommitmentStatusDue,
    DebtInstallmentStatus.partiallyPaid => l10n.debtCommitmentStatusPartial,
    DebtInstallmentStatus.paid => l10n.debtCommitmentStatusPaid,
    DebtInstallmentStatus.missed => l10n.debtCommitmentStatusMissed,
    DebtInstallmentStatus.skipped => l10n.debtCommitmentStatusSkipped,
    DebtInstallmentStatus.paused => l10n.debtCommitmentStatusPaused,
  };

  Future<void> _skip(
    BuildContext context,
    WidgetRef ref,
    String uid,
    DebtCommitment plan,
    String monthKey,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.debtCommitmentSkip),
        content: Text(l10n.debtCommitmentSkipConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.debtCommitmentConfirmSkip),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await getIt<CommitmentRepository>().execute(uid, {
      'requestId': newRequestId(),
      'action': 'skip',
      'commitmentId': plan.id,
      'monthKey': monthKey,
      'skipped': true,
    });
    if (!context.mounted) return;
    result.match(
      (failure) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => ref.invalidate(debtCommitmentsProvider(uid)),
    );
  }

  Future<void> _pause(
    BuildContext context,
    WidgetRef ref,
    String uid,
    DebtCommitment plan,
    String monthKey,
  ) async {
    final paused = plan.isPausedFor(monthKey);
    final result = await getIt<CommitmentRepository>().execute(uid, {
      'requestId': newRequestId(),
      'action': 'pause',
      'commitmentId': plan.id,
      'fromMonth': monthKey,
      'paused': !paused,
    });
    if (!context.mounted) return;
    result.match(
      (failure) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => ref.invalidate(debtCommitmentsProvider(uid)),
    );
  }

  Future<void> _linkExisting(
    BuildContext context,
    WidgetRef ref,
    String uid,
    DebtCommitment plan,
    String monthKey,
    Set<String> linkedIds,
  ) async {
    final firestore = getIt<FirebaseFirestore>();
    final query = await firestore
        .collection('users')
        .doc(uid)
        .collection('debtPayments')
        .where('debtAccountId', isEqualTo: plan.debtAccountId)
        .get();
    final available = query.docs
        .where(
          (doc) =>
              doc.data()['currency'] == plan.currency &&
              !linkedIds.contains(doc.id) &&
              ['allocated', 'unallocated'].contains(doc.data()['status']),
        )
        .toList();
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    if (available.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.debtNoExistingPayments)));
      return;
    }
    final paymentId = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final doc in available)
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(
                  CurrencyFormatter.formatMinor(
                    (doc.data()['amountMinor'] as num).toInt(),
                    plan.currency,
                    locale: Localizations.localeOf(context).toString(),
                  ),
                ),
                subtitle: Text(doc.id),
                onTap: () => Navigator.pop(sheetContext, doc.id),
              ),
          ],
        ),
      ),
    );
    if (paymentId == null || !context.mounted) return;
    final result = await getIt<CommitmentRepository>().execute(uid, {
      'requestId': newRequestId(),
      'action': 'linkPayment',
      'commitmentId': plan.id,
      'paymentId': paymentId,
      'monthKey': monthKey,
    });
    if (!context.mounted) return;
    result.match(
      (failure) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => ref.invalidate(debtCommitmentPaymentsProvider(uid)),
    );
  }
}
