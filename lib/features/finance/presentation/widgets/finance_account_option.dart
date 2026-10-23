import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/finance_account.dart';

String financeAccountKindLabel(FinanceAccount account, AppLocalizations l10n) =>
    switch (account.type) {
      'creditCard' => l10n.accountKindCreditCard,
      'bankLoan' => l10n.accountKindBankLoan,
      'personalLoan' => l10n.accountKindPersonalLoan,
      _ => l10n.accountKindMoney,
    };

String financeAccountSelectionLabel(FinanceAccount account, AppLocalizations l10n) =>
    '${financeAccountKindLabel(account, l10n)} · ${account.name} · ${account.currency}';

/// A compact account identity that stays clear when names are reused.
class FinanceAccountOption extends StatelessWidget {
  const FinanceAccountOption({required this.account, super.key});

  final FinanceAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final balanceLabel = account.isDebt
        ? account.isCreditCard && account.currentBalanceMinor > 0
              ? l10n.accountOptionCreditBalance
              : l10n.accountOptionDebt
        : l10n.accountOptionBalance;
    final balanceMinor = account.isDebt && account.currentBalanceMinor < 0
        ? -account.currentBalanceMinor
        : account.currentBalanceMinor;
    final balance = CurrencyFormatter.formatMinor(
      balanceMinor,
      account.currency,
      locale: Localizations.localeOf(context).toString(),
    );
    final icon = switch (account.type) {
      'creditCard' => Icons.credit_card_outlined,
      'bankLoan' => Icons.account_balance_outlined,
      'personalLoan' => Icons.handshake_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                financeAccountSelectionLabel(account, l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 30, top: 3),
          child: Text(
            '$balanceLabel · $balance',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
