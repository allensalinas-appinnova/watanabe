import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';

enum MovementEntryAction { income, expense, transfer, debtPayment }

/// The action selected from the shared global movement entry point.
class MovementActionSheet extends StatelessWidget {
  const MovementActionSheet({super.key});

  static Future<MovementEntryAction?> show(BuildContext context) =>
      showModalBottomSheet<MovementEntryAction>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const MovementActionSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final actions =
        <({MovementEntryAction type, String label, IconData icon, Color tint, Color ink})>[
          (
            type: MovementEntryAction.income,
            label: l10n.addIncome,
            icon: Icons.add,
            tint: const Color(0xFFDDF5E9),
            ink: AppColors.green,
          ),
          (
            type: MovementEntryAction.expense,
            label: l10n.addExpense,
            icon: Icons.remove,
            tint: AppColors.blueSoft,
            ink: AppColors.blueDark,
          ),
          (
            type: MovementEntryAction.transfer,
            label: l10n.moveMoney,
            icon: Icons.swap_horiz,
            tint: const Color(0xFFFFF1D6),
            ink: const Color(0xFFA76A00),
          ),
          (
            type: MovementEntryAction.debtPayment,
            label: l10n.debtPay,
            icon: Icons.credit_score_outlined,
            tint: const Color(0xFFFBE4E7),
            ink: const Color(0xFFC73338),
          ),
        ];

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        key: const ValueKey('movement_action_sheet'),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.blueDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.addMovementChoiceTitle,
                  key: const ValueKey('add_movement_title'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.addMovementChoiceSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                for (var index = 0; index < actions.length; index++) ...[
                  _MovementChoiceTile(
                    action: actions[index],
                    onPressed: () => Navigator.of(context).pop(actions[index].type),
                  ),
                  if (index != actions.length - 1) const SizedBox(height: 12),
                ],
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E9),
                    border: Border.all(color: const Color(0xFFFFD27A)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFA76A00), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.transferExplanation,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.navy,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 52,
                    child: OutlinedButton(
                      key: const ValueKey('add_movement_close'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.navy,
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(l10n.close),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MovementChoiceTile extends StatelessWidget {
  const _MovementChoiceTile({required this.action, required this.onPressed});

  final ({MovementEntryAction type, String label, IconData icon, Color tint, Color ink}) action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: action.label,
    onTap: onPressed,
    child: ExcludeSemantics(
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('add_movement_${action.type.name}'),
          onTap: onPressed,
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: action.tint, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(action.icon, color: action.ink, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.navy,
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
