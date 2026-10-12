import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/account_form_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

const _profile = UserProfile(
  id: 'user-1',
  locale: 'es',
  countryCode: 'CO',
  timeZone: 'America/Bogota',
  defaultCurrency: 'MXN',
  onboardingStatus: 'complete',
  categoryCatalogVersion: 1,
);

void main() {
  Widget buildSubject({
    Locale locale = const Locale('es'),
    double textScale = 1,
    FinanceAccount? account,
  }) => ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: false)),
      ),
      canonicalUserProfileProvider.overrideWith((ref, userId) => Stream.value(_profile)),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: AccountFormScreen(accountId: account?.id, initialAccount: account),
        ),
      ),
    ),
  );

  testWidgets('uses the profile currency and offers all account types and currencies', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('MXN'), findsOneWidget);
    expect(find.text('La moneda de tu perfil es MXN.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account_type_selector')));
    await tester.pumpAndSettle();
    expect(find.text('Efectivo'), findsWidgets);
    expect(find.text('Cuenta corriente'), findsOneWidget);
    expect(find.text('Cuenta de ahorros'), findsOneWidget);
    await tester.tap(find.text('Cuenta de ahorros').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account_currency_selector')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account_currency_selector')));
    await tester.pumpAndSettle();
    for (final currency in ['COP', 'MXN', 'BRL']) {
      expect(find.text(currency), findsWidgets);
    }
    await tester.tap(find.text('BRL').last);
    await tester.pumpAndSettle();
    final layoutException = tester.takeException();
    expect(layoutException, isNull, reason: '$layoutException');
  });

  testWidgets('requires a name and accepts a zero opening balance', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('account_save')));
    await tester.tap(find.byKey(const ValueKey('account_save')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el nombre de la cuenta.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('account_name_field')), 'Ahorros');
    await tester.enterText(find.byKey(const ValueKey('account_initial_balance_field')), '-1');
    await tester.tap(find.byKey(const ValueKey('account_save')));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un saldo válido de 0 o más.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('account_initial_balance_field')), '0');
    await tester.tap(find.byKey(const ValueKey('account_save')));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un saldo válido de 0 o más.'), findsNothing);
    expect(find.textContaining('No pudimos guardar la cuenta.'), findsOneWidget);
  });

  testWidgets('edit mode keeps type, currency, and balance read-only in Portuguese', (
    tester,
  ) async {
    const account = FinanceAccount(
      id: 'account-1',
      name: 'Reserva',
      type: 'savings',
      currency: 'BRL',
      openingBalanceMinor: 125050,
      currentBalanceMinor: 121000,
    );
    await tester.pumpWidget(
      buildSubject(locale: const Locale('pt'), textScale: 1.25, account: account),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account_type_read_only')), findsOneWidget);
    expect(find.byKey(const ValueKey('account_currency_read_only')), findsOneWidget);
    expect(find.byKey(const ValueKey('account_balance_read_only')), findsOneWidget);
    expect(find.text('Conta poupança'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account_currency_read_only')),
        matching: find.text('BRL'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('account_type_selector')), findsNothing);
    expect(find.byKey(const ValueKey('account_initial_balance_field')), findsNothing);
    expect(find.byKey(const ValueKey('account_save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow on a compact viewport with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildSubject(textScale: 1.4));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account_name_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('account_save')), findsOneWidget);
    final layoutException = tester.takeException();
    expect(layoutException, isNull, reason: '$layoutException');
  });
}
