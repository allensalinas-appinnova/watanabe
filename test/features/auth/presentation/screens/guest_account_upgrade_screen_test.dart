import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_account_link_result.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/domain/repositories/auth_repository.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/auth/presentation/screens/guest_account_upgrade_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;

  setUp(() => repository = _MockAuthRepository());

  Widget buildSubject() => ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      authSessionProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(id: 'same-uid', isAnonymous: true)),
      ),
    ],
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
      home: const GuestAccountUpgradeScreen(),
    ),
  );

  testWidgets('links email to current guest and confirms verification', (tester) async {
    when(
      () => repository.linkEmailPassword(email: 'person@example.com', password: 'password123'),
    ).thenAnswer(
      (_) async => const Right(
        AuthAccountLinkResult(
          user: AuthUser(id: 'same-uid', isAnonymous: false, email: 'person@example.com'),
          emailVerificationSent: true,
        ),
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('guest_upgrade_email')), 'person@example.com');
    await tester.enterText(find.byKey(const ValueKey('guest_upgrade_password')), 'password123');
    await tester.enterText(
      find.byKey(const ValueKey('guest_upgrade_confirm_password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('guest_upgrade_email_submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enviamos un correo'), findsOneWidget);
    verify(
      () => repository.linkEmailPassword(email: 'person@example.com', password: 'password123'),
    ).called(1);
  });

  testWidgets('keeps form values and guest session after a credential conflict', (tester) async {
    when(
      () => repository.linkEmailPassword(email: 'person@example.com', password: 'password123'),
    ).thenAnswer(
      (_) async => const Left(
        AuthFailure('conflict', technicalCode: 'credential-already-in-use'),
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('guest_upgrade_email')), 'person@example.com');
    await tester.enterText(find.byKey(const ValueKey('guest_upgrade_password')), 'password123');
    await tester.enterText(
      find.byKey(const ValueKey('guest_upgrade_confirm_password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('guest_upgrade_email_submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('ya pertenece a otra cuenta'), findsOneWidget);
    expect(find.text('person@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('guest_upgrade_email_submit')), findsOneWidget);
  });
}
