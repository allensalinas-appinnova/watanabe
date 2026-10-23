import 'package:flutter/material.dart';

import '../../features/finance/domain/entities/appearance_preferences.dart';

abstract final class AppColors {
  static const navy = Color(0xFF102A43);
  static const blue = Color(0xFF64B5F6);
  static const blueDark = Color(0xFF1C61D1);
  static const blueSoft = Color(0xFFE3F2FD);
  static const background = Color(0xFFF6FAFE);
  static const orange = Color(0xFFFFB74D);
  static const green = Color(0xFF087A4B);
  static const muted = Color(0xFF60748A);
  static const line = Color(0xFFDCE6F0);
}

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.brandHighlight,
    required this.income,
    required this.expense,
    required this.warning,
    required this.positive,
    required this.balanceCardBackground,
    required this.balanceCardForeground,
    required this.balanceCardMuted,
  });

  final Color brandHighlight;
  final Color income;
  final Color expense;
  final Color warning;
  final Color positive;
  final Color balanceCardBackground;
  final Color balanceCardForeground;
  final Color balanceCardMuted;

  @override
  AppThemeColors copyWith({
    Color? brandHighlight,
    Color? income,
    Color? expense,
    Color? warning,
    Color? positive,
    Color? balanceCardBackground,
    Color? balanceCardForeground,
    Color? balanceCardMuted,
  }) => AppThemeColors(
    brandHighlight: brandHighlight ?? this.brandHighlight,
    income: income ?? this.income,
    expense: expense ?? this.expense,
    warning: warning ?? this.warning,
    positive: positive ?? this.positive,
    balanceCardBackground: balanceCardBackground ?? this.balanceCardBackground,
    balanceCardForeground: balanceCardForeground ?? this.balanceCardForeground,
    balanceCardMuted: balanceCardMuted ?? this.balanceCardMuted,
  );

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      brandHighlight: Color.lerp(brandHighlight, other.brandHighlight, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      balanceCardBackground: Color.lerp(balanceCardBackground, other.balanceCardBackground, t)!,
      balanceCardForeground: Color.lerp(balanceCardForeground, other.balanceCardForeground, t)!,
      balanceCardMuted: Color.lerp(balanceCardMuted, other.balanceCardMuted, t)!,
    );
  }
}

extension AppThemeColorsContext on BuildContext {
  AppThemeColors get appColors {
    final scheme = Theme.of(this).colorScheme;
    return Theme.of(this).extension<AppThemeColors>() ??
        AppThemeColors(
          brandHighlight: scheme.secondary,
          income: AppColors.green,
          expense: scheme.error,
          warning: scheme.tertiary,
          positive: AppColors.green,
          balanceCardBackground: AppColors.navy,
          balanceCardForeground: Colors.white,
          balanceCardMuted: const Color(0xFFD8E7F8),
        );
  }
}

Color appPalettePrimary(AppearancePalette palette) => switch (palette) {
  AppearancePalette.lumio || AppearancePalette.classicBlue => AppColors.blueDark,
  AppearancePalette.ocean => const Color(0xFF087E8B),
  AppearancePalette.plum => const Color(0xFF7A3E9D),
};

Color appPaletteHighlight(AppearancePalette palette) => switch (palette) {
  AppearancePalette.lumio => const Color(0xFF16845B),
  AppearancePalette.classicBlue => AppColors.blue,
  AppearancePalette.ocean => const Color(0xFF42B8AE),
  AppearancePalette.plum => const Color(0xFFC49BE8),
};
