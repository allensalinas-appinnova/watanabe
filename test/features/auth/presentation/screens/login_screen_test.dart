import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/auth/presentation/screens/login_screen.dart';

void main() {
  Widget buildSubject() => const ProviderScope(
    child: MaterialApp(home: LoginScreen()),
  );

  group('LoginScreen', () {
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
