import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/finance_route_header.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/request_id.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../finance/domain/entities/financial_operation.dart';
import '../../finance/domain/entities/operation_page.dart';
import '../../finance/presentation/providers/canonical_finance_providers.dart';
import '../domain/debt_command.dart';
import 'debt_error_message.dart';
import 'debt_form_screen.dart';
import 'debt_providers.dart';

final debtHistoryProvider = FutureProvider.autoDispose
    .family<List<FinancialOperation>, ({String uid, String accountId})>((ref, key) async {
      final repository = ref.read(canonicalFinanceRepositoryProvider);
      final operations = <FinancialOperation>[];
      OperationPageCursor? cursor;
      do {
        final result = await repository.fetchOperationsPage(
          key.uid,
          accountId: key.accountId,
          cursor: cursor,
        );
        final page = result.match((failure) => throw StateError(failure.message), (page) => page);
        operations.addAll(page.items);
        cursor = page.nextCursor;
      } while (cursor != null);
      return operations;
    });

class DebtDetailScreen extends ConsumerStatefulWidget {
  const DebtDetailScreen({required this.accountId, super.key});
  final String accountId;
  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  final _reversalRequests = <String, String>{};
  bool _saving = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) return Scaffold(body: Center(child: Text(l.sessionExpired)));
    final accounts = ref.watch(
      canonicalAccountProvider((userId: uid, accountId: widget.accountId)),
    );
    final record = accounts.valueOrNull;
    final account = record?.isDebt == true ? record : null;
    final key = (uid: uid, accountId: widget.accountId);
    final history = ref.watch(debtHistoryProvider(key));
    String money(int amount) => CurrencyFormatter.formatMinor(amount, account?.currency ?? 'COP');
    return Scaffold(
      appBar: FinanceRouteHeader(
        title: l.debtTitle,
        backLabel: l.back,
        onBack: () => popOrGo(context, '/accounts'),
      ),
      body: account == null
          ? Center(
              child: accounts.isLoading
                  ? const CircularProgressIndicator()
                  : Text(l.debtErrorReference),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 104),
              children: [
                Text(account.name, style: Theme.of(context).textTheme.headlineSmall),
                Text(
                  '${account.currency} · ${account.isCreditCard
                      ? l.debtCreditCard
                      : account.type == 'bankLoan'
                      ? l.debtBankLoan
                      : l.debtPersonalLoan}',
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.debtRegistered),
                        Text(
                          money(account.debtMinor),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (account.creditBalanceMinor > 0)
                          Text('${l.debtCreditBalance}: ${money(account.creditBalanceMinor)}'),
                        if (!account.isCreditCard) ...[
                          Text('${l.debtPrincipal}: ${money(account.principalMinor)}'),
                          Text('${l.debtCharges}: ${money(account.chargesMinor)}'),
                        ],
                        if (account.limitMinor != null)
                          Text('${l.debtLimit}: ${money(account.limitMinor!)}'),
                        if (account.referenceAt != null)
                          Text(
                            '${l.debtReferenceDate}: ${MaterialLocalizations.of(context).formatMediumDate(account.referenceAt!.toLocal())}',
                          ),
                        if (account.isCreditCard &&
                            (account.statementClosingDay != null ||
                                account.paymentDueDay != null)) ...[
                          const Divider(height: 24),
                          Text(l.cardBillingCycle, style: Theme.of(context).textTheme.titleMedium),
                          if (account.statementClosingDay != null)
                            Text('${l.cardStatementClosingDay}: ${account.statementClosingDay}'),
                          if (account.paymentDueDay != null)
                            Text('${l.cardPaymentDueDay}: ${account.paymentDueDay}'),
                        ],
                        if (!account.isCreditCard && account.paymentDueDay != null) ...[
                          const Divider(height: 24),
                          Text(
                            l.debtPaymentPlanning,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text('${l.debtPaymentDueDay}: ${account.paymentDueDay}'),
                          Text(l.debtPaymentDayExplanation),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (account.isCreditCard && account.status == 'active')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.icon(
                      key: const ValueKey('debt_plan_payment'),
                      onPressed: () => context.push(
                        '/budgets/debt-payments/new?debtAccountId=${Uri.encodeQueryComponent(account.id)}',
                      ),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(l.cardPlanPayment),
                    ),
                  ),
                if (account.status == 'active')
                  for (final action in [
                    if (account.isCreditCard) 'purchase' else 'disburse',
                    'pay',
                    'charge',
                    if (account.isCreditCard) 'refund',
                    'adjust',
                    'update',
                    'archive',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                await context.push('/debts/${account.id}/actions/$action');
                                ref.invalidate(debtHistoryProvider(key));
                              },
                        child: Text(debtActionLabel(l, action)),
                      ),
                    ),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 20),
                Text(l.activity, style: Theme.of(context).textTheme.titleLarge),
                history.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => TextButton(
                    onPressed: () => ref.invalidate(debtHistoryProvider(key)),
                    child: Text(l.retry),
                  ),
                  data: (operations) => Column(
                    children: [
                      if (operations.isEmpty) Text(l.noTransactions),
                      for (final operation in operations)
                        Card(
                          child: ExpansionTile(
                            title: Text(
                              operation.description.isEmpty
                                  ? debtActionLabel(l, operation.debtKind ?? '')
                                  : operation.description,
                            ),
                            subtitle: Text(
                              '${operation.occurredAt.toLocal()} · ${money(operation.amountMinor * operation.projectionDirection)}',
                            ),
                            children: [
                              if (operation.type.name == 'unallocatedDebtPayment' &&
                                  operation.projectionDirection == 1 &&
                                  operation.allocationStatus == 'unallocated') ...[
                                ListTile(
                                  title: Text(l.unallocatedPaymentStatus),
                                  subtitle: Text(l.unallocatedPaymentExplanation),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    final paymentId =
                                        operation.paymentId ?? operation.debtCommandId;
                                    context.push(
                                      Uri(
                                        path: '/debts/${account.id}/actions/allocatePayment',
                                        queryParameters: {'paymentId': ?paymentId},
                                      ).toString(),
                                      extra: [operation],
                                    );
                                  },
                                  icon: const Icon(Icons.rule_outlined),
                                  label: Text(l.debtAllocatePayment),
                                ),
                              ],
                              if (!account.isCreditCard) ...[
                                ListTile(
                                  title: Text(l.debtPrincipal),
                                  trailing: Text(
                                    money(
                                      operation.principalDeltaMinor * operation.projectionDirection,
                                    ),
                                  ),
                                ),
                                ListTile(
                                  title: Text(l.debtCharges),
                                  trailing: Text(
                                    money(
                                      operation.chargesDeltaMinor * operation.projectionDirection,
                                    ),
                                  ),
                                ),
                              ],
                              if (operation.reversalOf != null)
                                ListTile(title: Text(l.debtReversal)),
                              if (operation.previousBalanceMinor != null)
                                ListTile(
                                  title: Text(l.balanceAdjustmentPrevious),
                                  subtitle: Text(money(-operation.previousBalanceMinor!)),
                                ),
                              if (operation.targetBalanceMinor != null)
                                ListTile(
                                  title: Text(l.balanceAdjustmentTarget),
                                  subtitle: Text(money(-operation.targetBalanceMinor!)),
                                ),
                              if (account.status == 'active' &&
                                  operation.projectionDirection == 1 &&
                                  [
                                    'purchase',
                                    'pay',
                                    'charge',
                                    'disburse',
                                    'refund',
                                    'adjust',
                                    'newChargePaid',
                                    'newChargePaid',
                                  ].contains(operation.debtKind))
                                TextButton(
                                  onPressed: () {
                                    final components = operations
                                        .where(
                                          (op) =>
                                              op.debtCommandId == operation.debtCommandId &&
                                              op.projectionDirection == 1,
                                        )
                                        .toList();
                                    final action = operation.debtKind == 'newChargePaid'
                                        ? 'pay'
                                        : operation.debtKind!;
                                    context.push(
                                      '/debts/${account.id}/actions/$action',
                                      extra: components,
                                    );
                                  },
                                  child: Text(l.edit),
                                ),
                              if (operation.debtKind == 'purchase' &&
                                  operation.projectionDirection == 1)
                                TextButton(
                                  onPressed: () => context.push(
                                    '/debts/${account.id}/actions/refund?original=${operation.id}',
                                  ),
                                  child: Text(l.debtRefund),
                                ),
                              if (operation.debtCommandId != null &&
                                  operation.projectionDirection == 1 &&
                                  [
                                    'purchase',
                                    'pay',
                                    'charge',
                                    'disburse',
                                  ].contains(operation.debtKind))
                                TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _reverse(uid, operation.debtCommandId!),
                                  child: Text(l.debtReverse),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _reverse(String uid, String commandId) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.debtReverse),
        content: Text(l.debtReview),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.debtReverse)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(debtRepositoryProvider)
        .execute(
          uid,
          DebtCommand(
            requestId: _reversalRequests.putIfAbsent(commandId, newRequestId),
            fields: {
              'action': 'reverse',
              'accountId': widget.accountId,
              'originalRequestId': commandId,
            },
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    result.match((f) => setState(() => _error = debtErrorMessage(l, f)), (_) {
      ref
        ..invalidate(debtHistoryProvider((uid: uid, accountId: widget.accountId)))
        ..invalidate(canonicalAccountsProvider(uid))
        ..invalidate(activityReportProvider(uid));
      invalidateOperationLists(ref, uid);
    });
  }
}
