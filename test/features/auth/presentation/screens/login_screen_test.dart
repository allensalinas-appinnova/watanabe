import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/presentation/screens/login_screen.dart';
import 'package:personal_finance/features/finance/domain/entities/appearance_preferences.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  Widget buildSubject({Locale? locale}) => ProviderScope(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LoginScreen(),
    ),
  );

  group('LoginScreen', () {
    testWidgets('uses dark appearance roles for surfaces and input borders', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.forAppearance(AppearancePalette.ocean, Brightness.light),
            darkTheme: AppTheme.forAppearance(AppearancePalette.ocean, Brightness.dark),
            themeMode: ThemeMode.dark,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginScreen(),
          ),
        ),
      );

      final context = tester.element(find.byKey(const ValueKey('auth_tabs_surface')));
      final scheme = Theme.of(context).colorScheme;
      final tabSurface = tester.widget<Container>(find.byKey(const ValueKey('auth_tabs_surface')));
      expect((tabSurface.decoration! as BoxDecoration).color, scheme.surface);
      expect(scheme.brightness, Brightness.dark);
      final emailInput = tester.widget<InputDecorator>(
        find.descendant(
          of: find.byKey(const ValueKey('auth_email_field')),
          matching: find.byType(InputDecorator),
        ),
      );
      final border = emailInput.decoration.enabledBorder! as OutlineInputBorder;
      expect(border.borderSide.color, scheme.outlineVariant);
      expect(tester.takeException(), isNull);
    });

    testWidgets('localizes authentication fields in Spanish and Portuguese', (tester) async {
      await tester.pumpWidget(buildSubject(locale: const Locale('es')));
      expect(find.text('CORREO ELECTRÓNICO'), findsOneWidget);
      expect(find.text('CONTRASEÑA'), findsOneWidget);
      expect(find.text('nombre@ejemplo.com'), findsOneWidget);
      expect(find.text('Claridad para cada peso.'), findsOneWidget);

      await tester.pumpWidget(buildSubject(locale: const Locale('pt')));
      expect(find.text('E-MAIL'), findsOneWidget);
      expect(find.text('SENHA'), findsOneWidget);
      expect(find.text('voce@exemplo.com'), findsOneWidget);
      expect(find.text('Clareza para cada real.'), findsOneWidget);
      expect(find.text('you@example.com'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses English copy and email hint for the English locale', (tester) async {
      await tester.pumpWidget(buildSubject(locale: const Locale('en')));

      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('you@example.com'), findsOneWidget);
      expect(find.text('Clarity for every peso.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('validates email and password before submitting', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
    });

    testWidgets('asks for a valid email before requesting a password reset', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byKey(const ValueKey('auth_forgot_password_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a valid email address to reset your password.'),
        findsOneWidget,
      );
    });

    testWidgets('switches to account creation and toggles password visibility', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byKey(const ValueKey('auth_signup_tab')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('auth_submit_button')),
          matching: find.text('Create account'),
        ),
        findsOneWidget,
      );

      EditableText passwordField() => tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('auth_password_field')),
          matching: find.byType(EditableText),
        ),
      );

      expect(passwordField().obscureText, isTrue);
      await tester.tap(find.byKey(const ValueKey('auth_password_visibility')));
      await tester.pumpAndSettle();
      expect(passwordField().obscureText, isFalse);
    });
  });
}
