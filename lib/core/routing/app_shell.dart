import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('global_add_operation'),
        onPressed: () => _showAddMovementSheet(context, l10n),
        icon: const Icon(Icons.add),
        label: Text(l10n.addMovement),
      ),
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('finance_bottom_navigation'),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: l10n.home),
          NavigationDestination(icon: const Icon(Icons.list_alt_outlined), label: l10n.activity),
          NavigationDestination(icon: const Icon(Icons.pie_chart_outline), label: l10n.budget),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: l10n.accounts,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMovementSheet(BuildContext context, AppLocalizations l10n) async {
    final route = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('add_income_action'),
                leading: const Icon(Icons.add_circle_outline),
                title: Text(l10n.addIncome),
                onTap: () => Navigator.pop(context, '/operations/new?type=income'),
              ),
              ListTile(
                key: const ValueKey('add_expense_action'),
                leading: const Icon(Icons.remove_circle_outline),
                title: Text(l10n.addExpense),
                onTap: () => Navigator.pop(context, '/operations/new?type=expense'),
              ),
              ListTile(
                key: const ValueKey('add_transfer_action'),
                leading: const Icon(Icons.swap_horiz),
                title: Text(l10n.transferMoney),
                onTap: () => Navigator.pop(context, '/transfers/new'),
              ),
            ],
          ),
        ),
      ),
    );
    if (route != null && context.mounted) await context.push<void>(route);
  }
}
