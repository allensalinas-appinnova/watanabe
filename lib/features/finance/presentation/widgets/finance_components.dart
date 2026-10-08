import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'finance_design_assets.dart';

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
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
                letterSpacing: .25,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.navy,
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
                  Icon(actionIcon, size: 16, color: AppColors.blueDark),
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
  const FinanceBottomNavigation({required this.selectedIndex, super.key});

  final int selectedIndex;

  static const _routes = ['/home', '/activity', '/budgets', '/accounts'];
  static const _labels = ['Home', 'Activity', 'Budgets', 'Accounts'];
  static const _icons = [
    Icons.home_outlined,
    Icons.swap_vert,
    Icons.receipt_long_outlined,
    Icons.account_circle_outlined,
  ];

  @override
  Widget build(BuildContext context) => NavigationBar(
    key: const ValueKey('finance_bottom_navigation'),
    selectedIndex: selectedIndex,
    height: 80,
    backgroundColor: Colors.white,
    indicatorColor: Colors.transparent,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    onDestinationSelected: (index) => context.go(_routes[index]),
    destinations: [
      for (var index = 0; index < _labels.length; index++)
        NavigationDestination(
          key: ValueKey('finance_nav_${_labels[index].toLowerCase()}'),
          icon: Icon(_icons[index]),
          selectedIcon: Icon(_icons[index]),
          label: _labels[index],
        ),
    ],
  );
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
            color: AppColors.navy,
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
            color: AppColors.muted,
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
    super.key,
  });

  final String expenseLabel;
  final String incomeLabel;
  final bool isIncomeSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: AppColors.blueSoft, borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _OperationTypeOption(
            label: expenseLabel,
            selected: !isIncomeSelected,
            onPressed: () => onChanged(false),
          ),
          _OperationTypeOption(
            label: incomeLabel,
            selected: isIncomeSelected,
            onPressed: () => onChanged(true),
          ),
        ],
      ),
    ),
  );
}

class _OperationTypeOption extends StatelessWidget {
  const _OperationTypeOption({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.blueDark : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
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
    color: selected ? AppColors.blueSoft : Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? AppColors.blueDark : AppColors.navy,
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
