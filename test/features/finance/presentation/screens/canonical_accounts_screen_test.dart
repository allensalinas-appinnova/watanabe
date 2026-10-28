import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
  FinanceAccount(
    id: 'card',
    name: 'Tarjeta principal',
    type: 'creditCard',
    currency: 'COP',
    nature: 'debt',
    currentBalanceMinor: -45000,
  ),
];

void main() {
  Widget buildSubject({
    Locale locale = const Locale('es'),
    double textScale = 1,
    String? initialSection,
    List<FinanceAccount> accounts = _accounts,
  }) => ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
      ),
      canonicalAccountsProvider.overrideWith((ref, userId) => Stream.value(accounts)),
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
          child: CanonicalAccountsScreen(initialSection: initialSection),
        ),
      ),
    ),
  );

  testWidgets('renders account cards without repeating account actions in the list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('LumioMoney'), findsNothing);
    expect(find.text('Cuentas y deudas'), findsOneWidget);
    expect(find.text('Dinero, tarjetas y préstamos en un solo lugar'), findsOneWidget);
    expect(find.text('Agregar cuenta o deuda'), findsOneWidget);
    expect(find.text('COP · Cuenta de ahorros'), findsOneWidget);
    expect(find.text('COP · Efectivo'), findsOneWidget);
    expect(find.text('Tarjetas de crédito'), findsOneWidget);
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
    expect(secondCard.top - firstCard.bottom, greaterThanOrEqualTo(18));
    expect(find.text('Agregar gasto'), findsNothing);
    expect(find.text('Agregar ingreso'), findsNothing);
    expect(find.text('Mover dinero'), findsNothing);
    expect(find.byKey(const ValueKey('accounts_add_button')).hitTestable(), findsOneWidget);
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

    expect(find.text('Contas e dívidas'), findsOneWidget);
    expect(find.text('Adicionar conta ou dívida'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens directly in the requested account group', (tester) async {
    await tester.pumpWidget(buildSubject(initialSection: 'cards'));
    await tester.pumpAndSettle();

    expect(find.text('Tarjeta principal'), findsOneWidget);
    expect(find.text('Banco1 Ahorros'), findsNothing);
    expect(find.text('Efectivo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the overview add action offers money, card, or loan creation', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/accounts',
      routes: [
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const CanonicalAccountsScreen(),
          routes: [
            GoRoute(
              path: 'new',
              name: 'new-account',
              builder: (context, state) => const Scaffold(body: Text('account creation form')),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => Scaffold(
                body: Text('account detail: ${state.pathParameters['id']}'),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/debts/new',
          builder: (context, state) => Scaffold(
            body: Text('debt form: ${state.uri.queryParameters['product']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
          ),
          canonicalAccountsProvider.overrideWith((ref, userId) => Stream.value(_accounts)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('accounts_add_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('accounts_create_money')), findsOneWidget);
    expect(find.byKey(const ValueKey('accounts_create_card')), findsOneWidget);
    expect(find.byKey(const ValueKey('accounts_create_loan')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('accounts_create_money')));
    await tester.pumpAndSettle();

    expect(find.text('account creation form'), findsOneWidget);
    expect(find.text('account detail: new'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'fixed add action remains visible with many accounts and opens the selected product',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final manyAccounts = List.generate(
        25,
        (index) => FinanceAccount(
          id: 'account-$index',
          name: 'Cuenta $index',
          type: 'creditCard',
          currency: 'COP',
          nature: 'debt',
          currentBalanceMinor: -10000,
        ),
      );
      final router = GoRouter(
        initialLocation: '/accounts?section=cards',
        routes: [
          GoRoute(
            path: '/accounts',
            builder: (context, state) => CanonicalAccountsScreen(
              initialSection: state.uri.queryParameters['section'],
            ),
          ),
          GoRoute(
            path: '/debts/new',
            builder: (context, state) => Scaffold(
              body: Text('debt form: ${state.uri.queryParameters['product']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
            ),
            canonicalAccountsProvider.overrideWith((ref, userId) => Stream.value(manyAccounts)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('es'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tarjetas de crédito'), findsOneWidget);
      expect(find.text('Agregar tarjeta'), findsOneWidget);
      expect(find.byKey(const ValueKey('accounts_add_button')).hitTestable(), findsOneWidget);
      final addButtonTop = tester.getTopLeft(find.byKey(const ValueKey('accounts_add_button'))).dy;
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('accounts_add_button')).hitTestable(), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('accounts_add_button'))).dy,
        addButtonTop,
      );
      await tester.tap(find.byKey(const ValueKey('accounts_add_button')));
      await tester.pumpAndSettle();
      expect(find.text('debt form: creditCard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the Loans section opens the existing loan form with a loan preselected', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/accounts?section=loans',
      routes: [
        GoRoute(
          path: '/accounts',
          builder: (context, state) => CanonicalAccountsScreen(
            initialSection: state.uri.queryParameters['section'],
          ),
        ),
        GoRoute(
          path: '/debts/new',
          builder: (context, state) => Scaffold(
            body: Text('debt form: ${state.uri.queryParameters['product']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
          ),
          canonicalAccountsProvider.overrideWith((ref, userId) => Stream.value(_accounts)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agregar crédito o préstamo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('accounts_add_button')));
    await tester.pumpAndSettle();
    expect(find.text('debt form: bankLoan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Money section opens the existing account form directly', (tester) async {
    final router = GoRouter(
      initialLocation: '/accounts?section=money',
      routes: [
        GoRoute(
          path: '/accounts',
          builder: (context, state) => CanonicalAccountsScreen(
            initialSection: state.uri.queryParameters['section'],
          ),
          routes: [
            GoRoute(
              path: 'new',
              name: 'new-account',
              builder: (context, state) => const Scaffold(body: Text('account creation form')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
          ),
          canonicalAccountsProvider.overrideWith((ref, userId) => Stream.value(_accounts)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agregar cuenta'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('accounts_add_button')));
    await tester.pumpAndSettle();

    expect(find.text('account creation form'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
