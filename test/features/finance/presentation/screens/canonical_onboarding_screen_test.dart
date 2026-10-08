import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/theme/app_colors.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_onboarding_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  Widget buildSubject() => ProviderScope(
    overrides: [authSessionProvider.overrideWith((ref) => const Stream.empty())],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      debugShowCheckedModeBanner: false,
      home: const CanonicalOnboardingScreen(),
    ),
  );

  testWidgets('uses the selected language and enables continue after account entry', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Prepara tu espacio'), findsOneWidget);
    expect(find.text('Elige tus preferencias. Puedes cambiarlas después.'), findsOneWidget);

    final continueButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('onboarding_continue')),
    );
    expect(continueButton.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('onboarding_account_name')),
      'Cuenta principal',
    );
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.byKey(const ValueKey('onboarding_continue'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('relocalizes the whole screen after the language selection changes', (tester) async {
    await tester.pumpWidget(buildSubject());
    final languageField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('onboarding_language')),
    );

    languageField.onChanged?.call('en');
    await tester.pumpAndSettle();

    expect(find.text('Set up your space'), findsOneWidget);
    expect(find.text('Choose your preferences. You can change them later.'), findsOneWidget);
    expect(find.text('LANGUAGE'), findsOneWidget);
  });

  testWidgets('shows the complete onboarding form and a full-width primary action', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());

    final language = tester.getRect(find.byKey(const ValueKey('onboarding_language')));
    final country = tester.getRect(find.byKey(const ValueKey('onboarding_country')));
    final currency = tester.getRect(find.byKey(const ValueKey('onboarding_currency')));
    final timezone = tester.getRect(find.byKey(const ValueKey('onboarding_timezone')));
    final accountName = tester.getRect(find.byKey(const ValueKey('onboarding_account_name')));
    final button = tester.getRect(find.byKey(const ValueKey('onboarding_continue')));

    expect(language.top, greaterThanOrEqualTo(0));
    expect(country.top, greaterThan(language.bottom));
    expect(currency.top, greaterThan(country.bottom));
    expect(timezone.top, greaterThan(currency.bottom));
    expect(accountName.top, greaterThan(timezone.bottom));
    expect(accountName.bottom, lessThan(button.top));
    expect(accountName.bottom, lessThanOrEqualTo(844));
    expect(button.left, closeTo(24, 1));
    expect(button.right, closeTo(366, 1));
    expect(find.text('Continuar'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('onboarding_account_name')),
      'Cuenta principal',
    );
    await tester.pump();
    final label = tester.getRect(find.text('Continuar'));
    expect(label.center.dx, closeTo(button.center.dx, 1));
    expect(tester.takeException(), isNull);
  });

  test('defines a shared primary button style with explicit states', () {
    final style = AppTheme.light.filledButtonTheme.style!;

    expect(style.minimumSize?.resolve(const {}), const Size(0, 52));
    expect(style.padding?.resolve(const {})?.horizontal, 36);
    expect(style.alignment, Alignment.center);
    expect(
      style.backgroundColor?.resolve(const {WidgetState.disabled}),
      AppColors.blueSoft,
    );
    expect(
      style.foregroundColor?.resolve(const {WidgetState.disabled}),
      AppColors.navy,
    );
    expect(style.backgroundColor?.resolve(const {}), AppColors.blueDark);
    expect(style.foregroundColor?.resolve(const {}), Colors.white);
  });

  testWidgets('keeps the form scrollable on a compact, enlarged-text viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(buildSubject());
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final accountName = find.byKey(const ValueKey('onboarding_account_name'));
    await tester.ensureVisible(accountName);
    await tester.pumpAndSettle();
    expect(tester.getRect(accountName).bottom, lessThanOrEqualTo(520));
    expect(
      tester.getRect(find.byKey(const ValueKey('onboarding_continue'))).bottom,
      lessThanOrEqualTo(520),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('onboarding_continue'))).width,
      closeTo(312, 1),
    );
    expect(tester.takeException(), isNull);
  });
}
