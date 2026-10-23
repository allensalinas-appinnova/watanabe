import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/appearance_preferences.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/appearance_settings_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('shows localized options and applies mode and palette immediately', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
        ),
        canonicalUserProfileProvider.overrideWith((ref, userId) => Stream.value(null)),
        appearancePreferencesControllerProvider.overrideWith(_TestAppearanceController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppearanceSettingsScreen(),
        ),
      ),
    );

    expect(find.text('Apariencia'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Oscuro'), findsOneWidget);
    expect(find.text('Lumio'), findsOneWidget);
    expect(find.text('Azul clásico'), findsOneWidget);
    expect(find.text('Océano'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ciruela'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ciruela'), findsOneWidget);

    await tester.tap(find.text('Oscuro'));
    await tester.pump();
    expect(
      container.read(appearancePreferencesControllerProvider).preferences.mode,
      AppearanceMode.dark,
    );

    await tester.tap(find.text('Océano'));
    await tester.pump();
    expect(
      container.read(appearancePreferencesControllerProvider).preferences.palette,
      AppearancePalette.ocean,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the selected appearance on save failure and retries synchronization', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
        ),
        canonicalUserProfileProvider.overrideWith((ref, userId) => Stream.value(null)),
        appearancePreferencesControllerProvider.overrideWith(_TestAppearanceController.new),
      ],
    );
    addTearDown(container.dispose);
    final controller =
        container.read(appearancePreferencesControllerProvider.notifier)
              as _TestAppearanceController
          ..failNextSave = true;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppearanceSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Océano'));
    await tester.pumpAndSettle();
    expect(container.read(appearancePreferencesControllerProvider).saveFailed, isTrue);
    await tester.scrollUntilVisible(
      find.textContaining('No se pudo sincronizar'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('No se pudo sincronizar'), findsOneWidget);
    expect(
      container.read(appearancePreferencesControllerProvider).preferences.palette,
      AppearancePalette.ocean,
    );

    await tester.scrollUntilVisible(
      find.text('Reintentar'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Apariencia sincronizada'), findsOneWidget);
    expect(controller.saveAttempts, 2);
    expect(tester.takeException(), isNull);
  });
}

class _TestAppearanceController extends AppearancePreferencesController {
  bool failNextSave = false;
  int saveAttempts = 0;

  @override
  AppearancePreferencesSaveState build() => const AppearancePreferencesSaveState();

  @override
  Future<void> save(String userId, AppearancePreferences preferences) async {
    saveAttempts++;
    final failed = failNextSave;
    failNextSave = false;
    state = AppearancePreferencesSaveState(
      userId: userId,
      preferences: preferences,
      saveFailed: failed,
      hasSaved: !failed,
    );
  }
}
