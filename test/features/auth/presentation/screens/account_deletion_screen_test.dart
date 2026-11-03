import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/domain/repositories/auth_repository.dart';
import 'package:personal_finance/features/auth/domain/services/account_deletion_repository.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/auth/presentation/screens/account_deletion_screen.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class Auth extends Mock implements FirebaseAuth {}

class FirebaseUser extends Mock implements User {}

class PasswordInfo extends Fake implements UserInfo {
  @override
  String get providerId => 'password';
}

class Repository extends Mock implements AuthRepository {}

class Deletion extends Mock implements AccountDeletionRepository {}

void main() {
  testWidgets(
    'requires confirmation and password; a failed request preserves the original command',
    (tester) async {
      final auth = Auth(), user = FirebaseUser(), repository = Repository(), deletion = Deletion();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.providerData).thenReturn([PasswordInfo()]);
      when(
        () => repository.reauthenticateForDeletion(password: any(named: 'password')),
      ).thenAnswer((_) async => const Right(unit));
      final requests = <String>[];
      when(
        () => deletion.request(
          userId: 'qa',
          requestId: any(named: 'requestId'),
          expectedGeneration: 1,
        ),
      ).thenAnswer((invocation) async {
        requests.add(invocation.namedArguments[#requestId] as String);
        return const Left(NetworkFailure('synthetic-offline'));
      });
      getIt
        ..registerSingleton<FirebaseAuth>(auth)
        ..registerSingleton<AccountDeletionRepository>(deletion);
      addTearDown(getIt.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (_) => Stream.value(
                const AuthUser(id: 'qa', isAnonymous: false, email: 'qa@example.test'),
              ),
            ),
            authRepositoryProvider.overrideWithValue(repository),
            canonicalUserProfileProvider('qa').overrideWith(
              (_) => Stream.value(
                const UserProfile(
                  id: 'qa',
                  locale: 'es',
                  countryCode: 'CO',
                  timeZone: 'America/Bogota',
                  defaultCurrency: 'COP',
                  onboardingStatus: 'complete',
                  categoryCatalogVersion: 1,
                  dataGeneration: 1,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountDeletionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(FilledButton, 'Solicitar eliminación permanente');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'local-test-password');
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.textContaining('No pudimos confirmar'), findsOneWidget);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests[0], requests[1]);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'local-test-password',
      );
      verifyNever(repository.signOut);
    },
  );
}
