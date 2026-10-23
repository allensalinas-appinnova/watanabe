import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/presentation/widgets/finance_components.dart';
import 'package:personal_finance/features/finance/presentation/widgets/finance_design_assets.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('bottom navigation uses the five destinations and approved styles', (
    tester,
  ) async {
    var selectedIndex = 0;
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('es'),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: FinanceBottomNavigation(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => setState(() => selectedIndex = index),
            ),
          ),
        ),
      ),
    );

    final bar = tester.widget<NavigationBar>(
      find.byKey(const ValueKey('finance_bottom_navigation')),
    );
    expect(bar.selectedIndex, 0);
    final destinations = tester.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    );
    expect(destinations.map((destination) => destination.label), [
      'Inicio',
      'Actividad',
      'Cuentas',
      'Plan',
      'Coach',
    ]);
    expect(
      [
        for (var index = 0; index < 4; index++)
          FinanceDesignAssets.navigation(
            index: index == 2
                ? 3
                : index == 3
                ? 2
                : index,
            selected: true,
          ),
      ],
      [
        'assets/icons/nav_home_selected.svg',
        'assets/icons/nav_activity_selected.svg',
        'assets/icons/nav_accounts_selected.svg',
        'assets/icons/nav_budget_selected.svg',
      ],
    );
    for (final destination in destinations.take(4)) {
      expect(destination.icon, isA<SvgPicture>());
      expect(destination.selectedIcon, isA<SvgPicture>());
    }
    for (final key in const [
      'finance_nav_home',
      'finance_nav_activity',
      'finance_nav_accounts',
      'finance_nav_budget',
      'finance_nav_coach',
    ]) {
      expect(tester.getSize(find.byKey(ValueKey(key))).height, greaterThanOrEqualTo(48));
    }
    final navTheme = tester.widget<NavigationBarTheme>(
      find.ancestor(
        of: find.byKey(const ValueKey('finance_bottom_navigation')),
        matching: find.byType(NavigationBarTheme),
      ),
    );
    expect(navTheme.data.height, 76);
    expect(navTheme.data.backgroundColor, Colors.white);
    expect(navTheme.data.indicatorColor, const Color(0xFFE3F2FD));

    for (final (index, label) in ['Inicio', 'Actividad', 'Cuentas', 'Plan', 'Coach'].indexed) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(selectedIndex, index);
      expect(
        tester
            .widget<NavigationBar>(find.byKey(const ValueKey('finance_bottom_navigation')))
            .selectedIndex,
        index,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation fits compact width with enlarged Portuguese text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('pt'),
        textScale: 1.5,
        home: const Scaffold(
          bottomNavigationBar: FinanceBottomNavigation(selectedIndex: 2),
        ),
      ),
    );

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Atividade'), findsOneWidget);
    expect(find.text('Contas'), findsOneWidget);
    expect(find.text('Plano'), findsOneWidget);
    expect(find.text('Coach'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operation type selector exposes both centered choices and reports selection', (
    tester,
  ) async {
    var selectedIncome = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FinanceOperationTypeSelector(
              expenseLabel: 'Gastos',
              incomeLabel: 'Ingresos',
              isIncomeSelected: selectedIncome,
              onChanged: (value) => setState(() => selectedIncome = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text('Ingresos'), findsOneWidget);
    final incomeBounds = tester.getRect(find.text('Ingresos'));
    final selectedBounds = tester.getRect(
      find.ancestor(of: find.text('Ingresos'), matching: find.byType(Semantics)).first,
    );
    expect(incomeBounds.center.dx, closeTo(selectedBounds.center.dx, 1));

    await tester.tap(find.text('Gastos'));
    await tester.pump();
    expect(selectedIncome, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('labeled field renders a persistent visible label above its control', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: FinanceLabeledField(
              label: 'Cuenta',
              child: TextField(decoration: InputDecoration()),
            ),
          ),
        ),
      ),
    );

    expect(find.text('CUENTA'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('CUENTA')).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _localizedApp({
  required Widget home,
  Locale? locale,
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);
