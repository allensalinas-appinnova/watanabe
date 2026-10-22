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

abstract final class FinanceCategoryColors {
  static const int? defaultValue = null;

  // Keep the original values so categories already using the first palette
  // continue to display exactly the same color.
  static const palette = <String, List<int>>{
    'blue': [0xFF163F7A, 0xFF174EA6, 0xFF1C61D1, 0xFF2B74D8, 0xFF3D8BE8],
    'green': [0xFF14532D, 0xFF166534, 0xFF147D55, 0xFF16845B, 0xFF27865D],
    'orange': [0xFF7C2D12, 0xFF9A3412, 0xFFB54708, 0xFFC45C16, 0xFFD97706],
    'purple': [0xFF4C1D95, 0xFF5B21B6, 0xFF7A3E9D, 0xFF7E3BB0, 0xFF9333EA],
    'red': [0xFF7F1D1D, 0xFF991B1B, 0xFFB4233A, 0xFFC0263D, 0xFFDC2626],
    'teal': [0xFF134E4A, 0xFF0F625B, 0xFF087E8B, 0xFF0E7490, 0xFF0F8B8D],
  };

  static const _originalColors = <int>[
    0xFF1C61D1,
    0xFF147D55,
    0xFFB54708,
    0xFF7A3E9D,
    0xFFB4233A,
    0xFF087E8B,
  ];

  static final options = <int?>[
    null,
    ..._originalColors,
    ...palette.values.expand((colors) => colors).where((color) => !_originalColors.contains(color)),
  ];

  static bool isValid(int? value) => value != null && value >= 0 && value <= 0xFFFFFFFF;

  static Color resolve(int? colorValue) {
    if (!isValid(colorValue)) return AppColors.blueDark;
    return Color(colorValue!);
  }

  static Color background(int? colorValue) =>
      !isValid(colorValue) ? AppColors.blueSoft : Color(colorValue!).withAlpha(0x24);
}

class FinanceCategoryIcon extends StatelessWidget {
  const FinanceCategoryIcon({
    required this.iconId,
    this.colorValue,
    this.size = 36,
    this.iconSize = 20,
    this.semanticLabel,
    super.key,
  });

  final String? iconId;
  final int? colorValue;
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
          color: FinanceCategoryColors.background(colorValue),
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: FinanceCategoryIcons.canonicalId(iconId) == 'food'
            ? SvgPicture.asset(
                'assets/icons/category_food_utensils.svg',
                colorFilter: ColorFilter.mode(
                  FinanceCategoryColors.resolve(colorValue),
                  BlendMode.srcIn,
                ),
              )
            : Icon(
                FinanceCategoryIcons.resolve(iconId),
                size: iconSize,
                color: FinanceCategoryColors.resolve(colorValue),
              ),
      ),
    ),
  );
}
