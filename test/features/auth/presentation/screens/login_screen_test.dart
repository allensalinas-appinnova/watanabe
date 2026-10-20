import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/auth/presentation/screens/login_screen.dart';
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
    testWidgets('localizes authentication fields in Spanish and Portuguese', (tester) async {
      await tester.pumpWidget(buildSubject(locale: const Locale('es')));
      expect(find.text('CORREO ELECTRÓNICO'), findsOneWidget);
      expect(find.text('CONTRASEÑA'), findsOneWidget);

      await tester.pumpWidget(buildSubject(locale: const Locale('pt')));
      expect(find.text('E-MAIL'), findsOneWidget);
      expect(find.text('SENHA'), findsOneWidget);
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
