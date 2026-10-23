import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/finance_route_header.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../features/finance/presentation/providers/canonical_finance_providers.dart';
import '../../../l10n/generated/app_localizations.dart';

class DebtPaymentPickerScreen extends ConsumerWidget {
  const DebtPaymentPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final accounts = ref.watch(canonicalAccountsProvider(uid));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: FinanceRouteHeader(
        title: l10n.debtPayCard,
        backLabel: l10n.back,
        onBack: () => popOrGo(context, '/accounts'),
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.genericError)),
        data: (items) {
          final debts = items.where((item) => item.isDebt && item.status == 'active').toList();
          if (debts.isEmpty) return Center(child: Text(l10n.accountsSectionEmpty));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(l10n.debtSelectForPayment, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final account in debts)
                Card(
                  child: ListTile(
                    minTileHeight: 72,
                    leading: Icon(
                      account.isCreditCard ? Icons.credit_card : Icons.account_balance,
                      color: AppColors.blueDark,
                    ),
                    title: Text(account.name),
                    subtitle: Text(account.isCreditCard ? l10n.debtCards : l10n.debtLoans),
                    trailing: Text(
                      CurrencyFormatter.formatMinor(account.debtMinor, account.currency),
                    ),
                    onTap: () => context.push('/debts/${account.id}/actions/pay'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
