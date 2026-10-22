import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/core/utils/currency_formatter.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_accounts_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

const _accounts = [
  FinanceAccount(
    id: 'savings',
    name: 'Banco1 Ahorros',
    type: 'savings',
    currency: 'COP',
    currentBalanceMinor: 20,
  ),
  FinanceAccount(
    id: 'cash',
    name: 'Efectivo',
    type: 'cash',
    currency: 'COP',
  ),
];

void main() {
  Widget buildSubject({Locale locale = const Locale('es'), double textScale = 1}) => ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
      ),
      canonicalAccountsProvider.overrideWith((ref, userId) => Stream.value(_accounts)),
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
          child: const CanonicalAccountsScreen(),
        ),
      ),
    ),
  );

  testWidgets('renders account cards and the full-width primary action', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('LumioMoney'), findsNothing);
    expect(find.text('Tus cuentas'), findsOneWidget);
    expect(find.text('Saldos organizados por moneda'), findsOneWidget);
    expect(find.text('COP · Cuenta de ahorros'), findsOneWidget);
    expect(find.text('COP · Efectivo'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('account_balance_savings'))).data,
      CurrencyFormatter.formatMinor(20, 'COP'),
    );
    expect(find.byType(AppBar), findsNothing);

    final firstCard = tester.getRect(find.byKey(const ValueKey('account_row_savings')));
    final secondCard = tester.getRect(find.byKey(const ValueKey('account_row_cash')));
    final addButton = tester.getRect(find.byKey(const ValueKey('accounts_add_button')));
    expect(firstCard.left, 24);
    expect(firstCard.width, 342);
    expect(firstCard.height, 82);
    expect(secondCard.top - firstCard.bottom, 18);
    expect(addButton.left, 24);
    expect(addButton.width, 342);
    expect(addButton.height, 52);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the account list usable on a compact screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject(locale: const Locale('pt'), textScale: 1.6));
    await tester.pumpAndSettle();

    expect(find.text('Suas contas'), findsOneWidget);
    expect(find.text('Adicionar conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
