import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/financial_operation.dart';
import 'finance_design_assets.dart';
import 'operation_type_icons.dart';

class FinanceHeader extends StatelessWidget {
  const FinanceHeader({
    required this.eyebrow,
    required this.title,
    required this.actionIcon,
    required this.actionTooltip,
    required this.onAction,
    super.key,
  });

  final String eyebrow;
  final String title;
  final IconData actionIcon;
  final String actionTooltip;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: .25,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      SizedBox.square(
        dimension: 36,
        child: Tooltip(
          message: actionTooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('finance_header_action'),
              customBorder: const CircleBorder(),
              onTap: onAction,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SvgPicture.asset(FinanceDesignAssets.headerAction, width: 28, height: 28),
                  Icon(actionIcon, size: 16, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class FinanceBottomNavigation extends StatelessWidget {
  const FinanceBottomNavigation({
    required this.selectedIndex,
    this.onDestinationSelected,
    this.backgroundColor,
    this.indicatorColor,
    this.height,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final double? height;

  static const _routes = ['/home', '/activity', '/accounts', '/budgets', '/coach'];
  static const _destinationKeys = [
    'finance_nav_home',
    'finance_nav_activity',
    'finance_nav_accounts',
    'finance_nav_budget',
    'finance_nav_coach',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.home, l10n.activity, l10n.accounts, l10n.plan, l10n.coachTab];
    final selectedLabelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 18 / 11,
    );
    final unselectedLabelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 18 / 11,
    );

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: height ?? 76,
        backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
        indicatorColor: indicatorColor ?? Theme.of(context).colorScheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? selectedLabelStyle : unselectedLabelStyle;
        }),
      ),
      child: NavigationBar(
        key: const ValueKey('finance_bottom_navigation'),
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected ?? (index) => context.go(_routes[index]),
        destinations: [
          for (var index = 0; index < labels.length; index++)
            NavigationDestination(
              key: ValueKey(_destinationKeys[index]),
              icon: index == 4
                  ? const Icon(Icons.explore_outlined, size: 24)
                  : SvgPicture.asset(
                      FinanceDesignAssets.navigation(
                        index: index == 2
                            ? 3
                            : index == 3
                            ? 2
                            : index,
                        selected: false,
                      ),
                      width: 24,
                      height: 24,
                      excludeFromSemantics: true,
                    ),
              selectedIcon: index == 4
                  ? const Icon(Icons.explore, size: 24)
                  : SvgPicture.asset(
                      FinanceDesignAssets.navigation(
                        index: index == 2
                            ? 3
                            : index == 3
                            ? 2
                            : index,
                        selected: true,
                      ),
                      width: 24,
                      height: 24,
                      excludeFromSemantics: true,
                    ),
              label: labels[index],
            ),
        ],
      ),
    );
  }
}

class FinanceSectionHeading extends StatelessWidget {
  const FinanceSectionHeading({required this.title, this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      ?action,
    ],
  );
}

class FinanceLabeledField extends StatelessWidget {
  const FinanceLabeledField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: .7,
          ),
        ),
      ),
      child,
    ],
  );
}

class FinanceOperationTypeSelector extends StatelessWidget {
  const FinanceOperationTypeSelector({
    required this.expenseLabel,
    required this.incomeLabel,
    required this.isIncomeSelected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String expenseLabel;
  final String incomeLabel;
  final bool isIncomeSelected;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _OperationTypeOption(
            label: expenseLabel,
            icon: operationTypeIcon(OperationType.expense),
            selected: !isIncomeSelected,
            onPressed: enabled ? () => onChanged(false) : null,
          ),
          _OperationTypeOption(
            label: incomeLabel,
            icon: operationTypeIcon(OperationType.income),
            selected: isIncomeSelected,
            onPressed: enabled ? () => onChanged(true) : null,
          ),
        ],
      ),
    ),
  );
}

class _OperationTypeOption extends StatelessWidget {
  const _OperationTypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class FinancePill extends StatelessWidget {
  const FinancePill({
    required this.label,
    this.selected = false,
    this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class FinanceIconBadge extends StatelessWidget {
  const FinanceIconBadge({
    required this.color,
    required this.icon,
    this.size = 36,
    this.asset,
    this.glyph,
    this.glyphColor = Colors.white,
    super.key,
  });

  final Color color;
  final IconData icon;
  final double size;
  final String? asset;
  final String? glyph;
  final Color glyphColor;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (asset case final assetPath?)
          SvgPicture.asset(assetPath)
        else
          DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: SizedBox.square(dimension: size),
          ),
        if (glyph case final text?)
          Text(
            text,
            style: TextStyle(color: glyphColor, fontSize: size * .39, fontWeight: FontWeight.w700),
          )
        else
          Icon(icon, color: glyphColor, size: size * .5),
      ],
    ),
  );
}

class FinanceLoadingView extends StatelessWidget {
  const FinanceLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(),
  );
}

class FinanceErrorView extends StatelessWidget {
  const FinanceErrorView({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(AppLocalizations.of(context).genericError, textAlign: TextAlign.center),
    ),
  );
}
