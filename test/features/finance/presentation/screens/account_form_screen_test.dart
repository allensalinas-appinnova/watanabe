import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/account_form_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _MockActions extends Mock implements CanonicalFinanceActions {}

class _FakeAccount extends Fake implements FinanceAccount {}

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
  setUpAll(() => registerFallbackValue(_FakeAccount()));

  Widget buildSubject({
    Locale locale = const Locale('es'),
    double textScale = 1,
    FinanceAccount? account,
    _MockActions? actions,
  }) => ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: false)),
      ),
      canonicalUserProfileProvider.overrideWith((ref, userId) => Stream.value(_profile)),
      if (actions != null) canonicalActionsProvider.overrideWithValue(actions),
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

  for (final locale in const [Locale('es'), Locale('en'), Locale('pt')]) {
    testWidgets('shows complete opening balance help with enlarged text: $locale', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildSubject(locale: locale, textScale: 1.4));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('account_initial_balance_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.decoration!.helperMaxLines, greaterThan(1));
      expect(find.text(field.decoration!.helperText!), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('account_save')));
      expect(find.byKey(const ValueKey('account_save')).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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

  testWidgets('shows the Home balance preference only when editing an account', (tester) async {
    const account = FinanceAccount(
      id: 'cash',
      name: 'Efectivo',
      type: 'cash',
      includeInDashboard: false,
    );
    await tester.pumpWidget(buildSubject(account: account));
    await tester.pumpAndSettle();

    final control = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('account_include_in_home')),
    );
    expect(control.value, isFalse);
    expect(find.text('Incluir en el saldo de Inicio'), findsOneWidget);
    expect(find.byKey(const ValueKey('account_initial_balance_field')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves the selected Home balance inclusion value', (tester) async {
    const account = FinanceAccount(
      id: 'cash',
      name: 'Efectivo',
      type: 'cash',
      includeInDashboard: false,
    );
    final actions = _MockActions();
    when(
      () => actions.updateAccount(
        any(),
        any(),
        name: any(named: 'name'),
        includeInDashboard: any(named: 'includeInDashboard'),
      ),
    ).thenThrow(Exception('simulated failure'));
    await tester.pumpWidget(buildSubject(account: account, actions: actions));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('account_include_in_home')));
    await tester.tap(find.byKey(const ValueKey('account_include_in_home')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('account_save')));
    await tester.tap(find.byKey(const ValueKey('account_save')));
    await tester.pumpAndSettle();

    verify(
      () => actions.updateAccount(
        'user-1',
        account,
        name: 'Efectivo',
        includeInDashboard: true,
      ),
    ).called(1);
  });
}
