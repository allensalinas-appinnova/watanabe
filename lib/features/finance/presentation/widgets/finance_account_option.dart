import 'package:flutter/material.dart';

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
    final icon = switch (account.type) {
      'creditCard' => Icons.credit_card_outlined,
      'bankLoan' => Icons.account_balance_outlined,
      'personalLoan' => Icons.handshake_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };

    return Row(
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
    );
  }
}
