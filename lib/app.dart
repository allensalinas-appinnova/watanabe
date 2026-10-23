import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/coach/presentation/widgets/coach_lifecycle.dart';
import 'features/finance/domain/entities/appearance_preferences.dart';
import 'features/finance/presentation/providers/canonical_finance_providers.dart';
import 'l10n/generated/app_localizations.dart';

class PersonalFinanceApp extends ConsumerWidget {
  const PersonalFinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(effectiveAppearancePreferencesProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.forAppearance(appearance.palette, Brightness.light),
      darkTheme: AppTheme.forAppearance(appearance.palette, Brightness.dark),
      themeMode: switch (appearance.mode) {
        AppearanceMode.system => ThemeMode.system,
        AppearanceMode.light => ThemeMode.light,
        AppearanceMode.dark => ThemeMode.dark,
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
      builder: (context, child) => CoachLifecycle(
        onOpen: (location) => appRouter.push(location),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
