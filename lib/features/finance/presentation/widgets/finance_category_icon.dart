import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';

/// Maps persisted category icon identifiers to the shared visual family.
abstract final class FinanceCategoryIcons {
  static const options = <String>[
    'food',
    'housing',
    'transport',
    'health',
    'education',
    'salary',
    'other',
  ];

  static const _icons = <String, IconData>{
    'food': Icons.restaurant_outlined,
    'housing': Icons.home_outlined,
    'transport': Icons.directions_car_outlined,
    'health': Icons.favorite_border,
    'education': Icons.menu_book_outlined,
    'salary': Icons.work_outline,
    'other': Icons.sell_outlined,
  };

  static const _aliases = <String, String>{
    'restaurant': 'food',
    'home': 'housing',
    'directions_car': 'transport',
    'medical_services': 'health',
    'spa': 'health',
    'school': 'education',
    'payments': 'salary',
    'work': 'salary',
    'storefront': 'salary',
    'trending_up': 'salary',
    'more_horiz': 'other',
    'bolt': 'other',
    'movie': 'other',
    'shopping_bag': 'other',
    'card_giftcard': 'other',
    'category_outlined': 'other',
    'category': 'other',
  };

  static String? canonicalId(String? identifier) {
    if (identifier == null) return null;
    if (_icons.containsKey(identifier)) return identifier;
    return _aliases[identifier];
  }

  /// Unknown and missing values use a visual fallback without changing storage.
  static IconData resolve(String? identifier) =>
      _icons[canonicalId(identifier)] ?? _icons['other']!;
}

class FinanceCategoryIcon extends StatelessWidget {
  const FinanceCategoryIcon({
    required this.iconId,
    this.size = 36,
    this.iconSize = 20,
    this.semanticLabel,
    super.key,
  });

  final String? iconId;
  final double size;
  final double iconSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.blueSoft,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: FinanceCategoryIcons.canonicalId(iconId) == 'food'
            ? SvgPicture.asset('assets/icons/category_food_utensils.svg')
            : Icon(
                FinanceCategoryIcons.resolve(iconId),
                size: iconSize,
                color: AppColors.blueDark,
              ),
      ),
    ),
  );
}
