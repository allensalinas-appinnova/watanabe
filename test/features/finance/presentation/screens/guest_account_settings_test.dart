import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_more_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  Widget buildSubject() => ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(id: 'guest-uid', isAnonymous: true)),
      ),
      pendingOperationsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
    child: const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: CanonicalMoreScreen(),
    ),
  );

  testWidgets('offers account protection in Settings for a guest', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings_secure_guest_account')), findsOneWidget);
    expect(find.text('Guardar mi cuenta'), findsOneWidget);
  });

  testWidgets('warns guest users before sign-out and offers to save the account', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('more_sign_out')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('more_sign_out')));
    await tester.pumpAndSettle();

    expect(find.textContaining('podrías perder el acceso'), findsOneWidget);
    expect(find.byKey(const ValueKey('guest_sign_out_save_account')), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
