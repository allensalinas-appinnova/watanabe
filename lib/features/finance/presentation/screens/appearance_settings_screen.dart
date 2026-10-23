import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../finance/domain/entities/appearance_preferences.dart';
import '../providers/canonical_finance_providers.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(authSessionProvider).valueOrNull?.id;
    final preferences = ref.watch(effectiveAppearancePreferencesProvider);
    final saveState = ref.watch(appearancePreferencesControllerProvider);
    final colors = Theme.of(context).colorScheme;
    final schemes = AppearancePalette.values.map((palette) {
      final primary = appPalettePrimary(palette);
      return (palette: palette, primary: primary, accent: appPaletteHighlight(palette));
    }).toList();

    String paletteName(AppearancePalette palette) => switch (palette) {
      AppearancePalette.lumio => l10n.paletteLumio,
      AppearancePalette.classicBlue => l10n.paletteClassicBlue,
      AppearancePalette.ocean => l10n.paletteOcean,
      AppearancePalette.plum => l10n.palettePlum,
    };

    Future<void> save(AppearancePreferences updated) async {
      if (userId != null) {
        await ref.read(appearancePreferencesControllerProvider.notifier).save(userId, updated);
      }
    }

    return Scaffold(
      appBar: FinanceRouteHeader(
        title: l10n.appearanceTitle,
        backLabel: l10n.back,
        onBack: () => popOrGo(context, '/home'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          Text(l10n.appearanceSubtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text(l10n.appearanceMode, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<AppearanceMode>(
            groupValue: preferences.mode,
            onChanged: (mode) {
              if (mode != null) {
                save(AppearancePreferences(mode: mode, palette: preferences.palette));
              }
            },
            child: Column(
              children: [
                for (final option in [
                  (
                    mode: AppearanceMode.system,
                    label: l10n.appearanceSystem,
                    icon: Icons.settings_suggest_outlined,
                  ),
                  (
                    mode: AppearanceMode.light,
                    label: l10n.appearanceLight,
                    icon: Icons.light_mode_outlined,
                  ),
                  (
                    mode: AppearanceMode.dark,
                    label: l10n.appearanceDark,
                    icon: Icons.dark_mode_outlined,
                  ),
                ])
                  RadioListTile<AppearanceMode>(
                    contentPadding: EdgeInsets.zero,
                    value: option.mode,
                    title: Text(option.label),
                    secondary: Icon(option.icon),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.appearancePalette, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final item in schemes)
            Card(
              clipBehavior: Clip.antiAlias,
              child: RadioGroup<AppearancePalette>(
                groupValue: preferences.palette,
                onChanged: (palette) {
                  if (palette != null) {
                    save(AppearancePreferences(mode: preferences.mode, palette: palette));
                  }
                },
                child: RadioListTile<AppearancePalette>(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  value: item.palette,
                  title: Text(paletteName(item.palette)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        _ColorSwatch(color: item.primary, label: l10n.appearancePalette),
                        const SizedBox(width: 8),
                        _ColorSwatch(color: item.accent, label: l10n.appearancePalette),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: item.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (saveState.userId == userId && saveState.isSaving)
            _SaveStatus(
              icon: Icons.sync,
              text: l10n.appearanceSaving,
              color: colors.onSurfaceVariant,
            ),
          if (saveState.userId == userId && saveState.hasSaved && !saveState.saveFailed)
            _SaveStatus(
              icon: Icons.cloud_done_outlined,
              text: l10n.appearanceSaved,
              color: colors.primary,
            ),
          if (saveState.userId == userId && saveState.saveFailed) ...[
            _SaveStatus(
              icon: Icons.cloud_off_outlined,
              text: l10n.appearanceSaveFailed,
              color: colors.error,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: saveState.isSaving ? null : () => save(saveState.preferences),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.appearanceRetry),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
  );
}

class _SaveStatus extends StatelessWidget {
  const _SaveStatus({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    ),
  );
}
