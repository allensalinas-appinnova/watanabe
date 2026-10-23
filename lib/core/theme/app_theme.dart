import 'package:flutter/material.dart';

import '../../features/finance/domain/entities/appearance_preferences.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => forAppearance(AppearancePalette.lumio, Brightness.light);
  static ThemeData get dark => forAppearance(AppearancePalette.lumio, Brightness.dark);

  static ThemeData forAppearance(AppearancePalette palette, Brightness brightness) {
    final primary = appPalettePrimary(palette);
    final highlight = appPaletteHighlight(palette);
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? _lighten(primary, 0.35) : primary,
          onPrimary: isDark ? const Color(0xFF071523) : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF203549)
              : switch (palette) {
                  AppearancePalette.lumio || AppearancePalette.classicBlue => AppColors.blueSoft,
                  AppearancePalette.ocean || AppearancePalette.plum => _tint(primary, 0.88),
                },
          onPrimaryContainer: isDark ? const Color(0xFFDCEAF7) : AppColors.navy,
          secondary: isDark ? _lighten(highlight, 0.25) : highlight,
          tertiary: isDark ? const Color(0xFFFFD166) : const Color(0xFFC28A16),
          surface: isDark ? const Color(0xFF111B26) : Colors.white,
          onSurface: isDark ? const Color(0xFFE8EEF5) : AppColors.navy,
          onSurfaceVariant: isDark ? const Color(0xFFB6C4D2) : AppColors.muted,
          outline: isDark ? const Color(0xFF526273) : AppColors.line,
          outlineVariant: isDark ? const Color(0xFF354555) : AppColors.line,
          error: isDark ? const Color(0xFFFF8A80) : const Color(0xFFC73338),
          onError: isDark ? const Color(0xFF3D0808) : Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0B141E) : AppColors.background,
      fontFamily: 'Inter',
      extensions: [
        AppThemeColors(
          brandHighlight: scheme.secondary,
          income: isDark ? const Color(0xFF53D18C) : AppColors.green,
          expense: scheme.error,
          warning: isDark ? const Color(0xFFFFD166) : const Color(0xFF8A5600),
          positive: isDark ? const Color(0xFF53D18C) : AppColors.green,
          balanceCardBackground: isDark ? const Color(0xFF17334A) : AppColors.navy,
          balanceCardForeground: const Color(0xFFF7FBFF),
          balanceCardMuted: const Color(0xFFD8E7F8),
        ),
      ],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.symmetric(horizontal: 18),
          ),
          alignment: Alignment.center,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled) ? scheme.primaryContainer : scheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? scheme.onPrimaryContainer
                : scheme.onPrimary;
          }),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.symmetric(horizontal: 18),
          ),
          alignment: Alignment.center,
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }

  static Color _tint(Color color, double amount) => Color.lerp(color, Colors.white, amount)!;

  static Color _lighten(Color color, double amount) => Color.lerp(color, Colors.white, amount)!;
}
