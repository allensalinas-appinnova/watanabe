import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/routing/finance_route_header.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../../core/utils/money_parser.dart';
import '../../../core/utils/request_id.dart';
import '../../../core/widgets/day_of_month_selector.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../finance/presentation/providers/canonical_finance_providers.dart';
import '../domain/commitment_repository.dart';

class DebtCommitmentEditScreen extends ConsumerStatefulWidget {
  const DebtCommitmentEditScreen({required this.commitmentId, required this.monthKey, super.key});
  final String commitmentId;
  final String monthKey;
  @override
  ConsumerState<DebtCommitmentEditScreen> createState() => _DebtCommitmentEditScreenState();
}

class _DebtCommitmentEditScreenState extends ConsumerState<DebtCommitmentEditScreen> {
  final _amount = TextEditingController();
  bool _initialized = false;
  bool _thisOnly = true;
  bool _saving = false;
  bool _failed = false;
  int _day = 1;
  String? _signature;
  String _requestId = newRequestId();
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final plans = ref.watch(debtCommitmentsProvider(uid));
    final plan = plans.valueOrNull
        ?.where((item) => item.id == widget.commitmentId)
        .firstOrNull
        ?.forMonth(widget.monthKey);
    if (plan != null && !_initialized) {
      _initialized = true;
      _day = plan.dueDay;
      _amount.text = MoneyParser.zeroDecimalCurrencies.contains(plan.currency)
          ? '${plan.amountMinor}'
          : '${plan.amountMinor ~/ 100}.${(plan.amountMinor % 100).toString().padLeft(2, '0')}';
    }
    return Scaffold(
      appBar: FinanceRouteHeader(
        title: l10n.planningFollowUpText('edit'),
        backLabel: l10n.cancel,
        onBack: () => popOrGo(
          context,
          '/budgets/debt-payments/${widget.commitmentId}?month=${widget.monthKey}',
        ),
      ),
      body: plan == null
          ? Center(
              child: plans.hasError || plans.hasValue
                  ? TextButton(
                      onPressed: () => ref.invalidate(debtCommitmentsProvider(uid)),
                      child: Text(l10n.retry),
                    )
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(widget.monthKey, style: Theme.of(context).textTheme.titleLarge),
                TextField(
                  key: const ValueKey('commitment_edit_amount'),
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.debtCommitmentAmount,
                    prefixText: '${plan.currency} ',
                  ),
                ),
                const SizedBox(height: 16),
                DayOfMonthSelector(
                  fieldId: 'commitment_edit_due',
                  selectedDay: _day,
                  dayLabel: l10n.day,
                  label: l10n.debtCommitmentDueDay,
                  enabled: !_saving,
                  onChanged: (value) {
                    if (value != null) setState(() => _day = value);
                  },
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(l10n.planningFollowUpText('thisOnly'))),
                    ButtonSegment(value: false, label: Text(l10n.planningFollowUpText('future'))),
                  ],
                  selected: {_thisOnly},
                  onSelectionChanged: _saving
                      ? null
                      : (values) => setState(() => _thisOnly = values.first),
                ),
                if (_failed)
                  Text(
                    l10n.planningFollowUpText('error'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          late int amount;
                          try {
                            amount = MoneyParser.minorUnits(_amount.text, plan.currency);
                          } catch (_) {
                            setState(() => _failed = true);
                            return;
                          }
                          final signature = '$amount:$_day:$_thisOnly';
                          if (_signature != signature) {
                            _signature = signature;
                            _requestId = newRequestId();
                          }
                          setState(() {
                            _saving = true;
                            _failed = false;
                          });
                          final result = await getIt<CommitmentRepository>().execute(uid, {
                            'requestId': _requestId,
                            'action': _thisOnly ? 'editOccurrence' : 'edit',
                            'commitmentId': widget.commitmentId,
                            'amountMinor': amount,
                            'dueDay': _day,
                            if (_thisOnly)
                              'monthKey': widget.monthKey
                            else
                              'effectiveFromMonth': widget.monthKey,
                          });
                          if (!context.mounted) return;
                          result.fold(
                            (_) => setState(() {
                              _failed = true;
                              _saving = false;
                            }),
                            (_) {
                              ref.invalidate(debtCommitmentsProvider(uid));
                              context.pop();
                            },
                          );
                        },
                  child: _saving ? const CircularProgressIndicator() : Text(l10n.save),
                ),
              ],
            ),
    );
  }
}
