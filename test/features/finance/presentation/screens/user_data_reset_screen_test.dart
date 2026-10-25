import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:personal_finance/core/offline/pending_operation_queue.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/user_data_reset_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  late PendingOperationDatabase database;
  final getIt = GetIt.instance;

  setUp(() {
    database = PendingOperationDatabase(NativeDatabase.memory());
    getIt.registerSingleton<PendingOperationDatabase>(database);
  });

  tearDown(() async {
    await getIt.unregister<PendingOperationDatabase>();
    await database.close();
  });

  Widget subject() => ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(id: 'reset-test-user', isAnonymous: false)),
      ),
      canonicalUserProfileProvider('reset-test-user').overrideWith(
        (ref) => Stream.value(
          const UserProfile(
            id: 'reset-test-user',
            locale: 'es',
            countryCode: 'CO',
            timeZone: 'America/Bogota',
            defaultCurrency: 'COP',
            onboardingStatus: 'complete',
            categoryCatalogVersion: 1,
          ),
        ),
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
      home: const UserDataResetScreen(),
    ),
  );

  testWidgets('requires typed confirmation and a second confirmation before starting', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reset_user_data_button')));
    await tester.pumpAndSettle();
    expect(find.text('Confirma el reinicio'), findsOneWidget);
    expect(find.text('¿Borrar todos tus datos?'), findsNothing);

    await tester.enterText(find.byType(TextField), 'REINICIAR');
    await tester.pump();
    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(continueButton.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar todos tus datos?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reset_user_data_button')), findsOneWidget);
  });

  testWidgets('blocks reset while the local outbox has unresolved movements', (tester) async {
    await database.enqueue(
      idempotencyKey: 'pending-reset-test',
      operationType: 'expense',
      payload: const {'ownerUserId': 'reset-test-user'},
    );

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.textContaining('Resuelve primero'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('reset_user_data_button')),
    );
    expect(button.onPressed, isNull);
  });
}
