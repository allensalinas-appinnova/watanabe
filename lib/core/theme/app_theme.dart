import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.blueDark,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.blueDark,
          secondary: AppColors.orange,
          surface: Colors.white,
          onSurface: AppColors.navy,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.line),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
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
            return states.contains(WidgetState.disabled) ? AppColors.blueSoft : AppColors.blueDark;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled) ? AppColors.navy : Colors.white;
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
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(0, 52)),
          padding: WidgetStatePropertyAll(
            EdgeInsetsDirectional.symmetric(horizontal: 18),
          ),
          alignment: Alignment.center,
          foregroundColor: WidgetStatePropertyAll(AppColors.navy),
          backgroundColor: WidgetStatePropertyAll(Colors.white),
          side: WidgetStatePropertyAll(BorderSide(color: AppColors.line)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}
