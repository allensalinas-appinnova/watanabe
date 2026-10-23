import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/theme/app_colors.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/finance/domain/entities/appearance_preferences.dart';

void main() {
  group('AppearancePreferences', () {
    test('legacy and malformed values use system mode and Lumio palette', () {
      expect(AppearancePreferences.fromMap(null), const AppearancePreferences());
      expect(
        AppearancePreferences.fromMap({'mode': 'unknown', 'palette': 'custom'}),
        const AppearancePreferences(),
      );
    });

    test('serializes the stable profile contract', () {
      const preferences = AppearancePreferences(
        mode: AppearanceMode.dark,
        palette: AppearancePalette.ocean,
      );
      expect(preferences.toMap(), {'mode': 'dark', 'palette': 'ocean'});
      expect(AppearancePreferences.fromMap(preferences.toMap()), preferences);
    });
  });

  group('AppTheme', () {
    for (final brightness in Brightness.values) {
      for (final palette in AppearancePalette.values) {
        test(
          '$palette provides readable actions and stable financial semantics in $brightness',
          () {
            final theme = AppTheme.forAppearance(palette, brightness);
            final scheme = theme.colorScheme;
            expect(scheme.primary, isNot(scheme.surface));
            expect(_contrastRatio(scheme.primary, scheme.onPrimary), greaterThan(4.5));
            expect(_contrastRatio(scheme.surface, scheme.onSurface), greaterThan(4.5));
            expect(
              _contrastRatio(theme.extension<AppThemeColors>()!.income, scheme.surface),
              greaterThan(4.5),
            );
            expect(
              _contrastRatio(theme.extension<AppThemeColors>()!.expense, scheme.surface),
              greaterThan(4.5),
            );
            expect(
              _contrastRatio(theme.extension<AppThemeColors>()!.warning, scheme.surface),
              greaterThan(4.5),
            );
            expect(
              theme.extension<AppThemeColors>()?.income,
              brightness == Brightness.light ? AppColors.green : const Color(0xFF53D18C),
            );
            expect(theme.extension<AppThemeColors>()?.expense, scheme.error);
            expect(theme.extension<AppThemeColors>()?.warning, isNotNull);
          },
        );
      }
    }
  });
}

double _contrastRatio(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}
