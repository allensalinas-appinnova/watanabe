import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/budget.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_flow_type.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_budget_create_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _MockActions extends Mock implements CanonicalFinanceActions {}

void main() {
  late _MockActions actions;

  setUp(() {
    actions = _MockActions();
    when(
      () => actions.createBudget(
        any(),
        categoryId: any(named: 'categoryId'),
        flowType: any(named: 'flowType'),
        monthKey: any(named: 'monthKey'),
        currency: any(named: 'currency'),
        items: any(named: 'items'),
      ),
    ).thenAnswer(
      (_) async => Budget(
        id: 'created-budget',
        categoryId: 'food',
        flowType: BudgetFlowType.expense,
        monthKey: DateFormat('yyyy-MM').format(DateTime.now()),
        currency: 'COP',
        plannedAmountMinor: 100,
        status: 'active',
      ),
    );
  });

  Widget subject({
    Locale locale = const Locale('es'),
    List<FinanceCategory>? categories,
    double textScale = 1,
  }) => ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: false)),
      ),
      canonicalUserProfileProvider('user-1').overrideWith(
        (ref) => Stream.value(
          const UserProfile(
            id: 'user-1',
            locale: 'es',
            countryCode: 'CO',
            timeZone: 'America/Bogota',
            defaultCurrency: 'COP',
            onboardingStatus: 'complete',
            categoryCatalogVersion: 1,
          ),
        ),
      ),
      canonicalCategoriesProvider('user-1').overrideWith(
        (ref) => Stream.value(categories ?? _categories),
      ),
      canonicalRecentOperationsProvider('user-1').overrideWith((ref) => Stream.value(const [])),
      canonicalActionsProvider.overrideWithValue(actions),
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const CanonicalBudgetCreateScreen(),
    ),
  );

  testWidgets('starts with current budget defaults, one item, and profile currency', (
    tester,
  ) async {
    _setViewport(tester);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('Planea por categoría'), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_type_selector')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_item_description_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_item_amount_0')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('budget_planned_total'))).data,
      contains('0'),
    );
    expect(find.byKey(const ValueKey('budget_remove_item_0')), findsNothing);
    expect(find.byKey(const ValueKey('budget_manage_categories')), findsOneWidget);
  });

  testWidgets('adds items, recalculates total, and never removes the last item', (tester) async {
    _setViewport(tester);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await _enter(tester, 'budget_item_amount_0', '100');
    await _tap(tester, 'budget_add_item');
    await tester.pumpAndSettle();
    await _enter(tester, 'budget_item_amount_1', '250');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('budget_item_description_1')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('budget_planned_total'))).data,
      contains('350'),
    );
    await _tap(tester, 'budget_remove_item_0');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('budget_item_description_1')), findsNothing);
    expect(find.byKey(const ValueKey('budget_item_description_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_remove_item_0')), findsNothing);
  });

  testWidgets('filters categories by flow and submits all item drafts', (tester) async {
    _setViewport(tester);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await _enter(tester, 'budget_item_description_0', 'Mercado');
    await _enter(tester, 'budget_item_amount_0', '100');
    await _tap(tester, 'budget_category_selector_expense');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comida').last);
    await tester.pumpAndSettle();
    await _tap(tester, 'budget_type_selector');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingresos').last);
    await tester.pumpAndSettle();
    await _tap(tester, 'budget_category_selector_income');
    await tester.pumpAndSettle();
    expect(find.text('Salario'), findsOneWidget);
    await tester.tap(find.text('Salario').last);
    await tester.pumpAndSettle();
    await _tap(tester, 'budget_save');
    await tester.pumpAndSettle();

    verify(
      () => actions.createBudget(
        'user-1',
        categoryId: 'salary',
        flowType: 'income',
        monthKey: any(named: 'monthKey'),
        currency: 'COP',
        items: any(named: 'items'),
      ),
    ).called(1);
  });

  testWidgets('preserves entered details after recoverable save failure', (tester) async {
    _setViewport(tester);
    when(
      () => actions.createBudget(
        any(),
        categoryId: any(named: 'categoryId'),
        flowType: any(named: 'flowType'),
        monthKey: any(named: 'monthKey'),
        currency: any(named: 'currency'),
        items: any(named: 'items'),
      ),
    ).thenThrow(Exception('temporary failure'));

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await _enter(tester, 'budget_item_description_0', 'Mercado');
    await _enter(tester, 'budget_item_amount_0', '100');
    await _tap(tester, 'budget_category_selector_expense');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comida').last);
    await tester.pumpAndSettle();
    await _tap(tester, 'budget_save');
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos guardar el presupuesto. Tus datos siguen aquí; inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('budget_item_description_0')))
          .controller!
          .text,
      'Mercado',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('budget_item_amount_0')))
          .controller!
          .text,
      '100',
    );
  });

  testWidgets('validates blank item description and supports Portuguese copy', (tester) async {
    _setViewport(tester);
    await tester.pumpWidget(subject(locale: const Locale('pt')));
    await tester.pumpAndSettle();
    await _enter(tester, 'budget_item_amount_0', '100');
    await _tap(tester, 'budget_save');
    await tester.pumpAndSettle();

    expect(find.text('Planeje por categoria'), findsOneWidget);
    expect(find.text('Informe uma descrição.'), findsOneWidget);
    verifyNever(
      () => actions.createBudget(
        any(),
        categoryId: any(named: 'categoryId'),
        flowType: any(named: 'flowType'),
        monthKey: any(named: 'monthKey'),
        currency: any(named: 'currency'),
        items: any(named: 'items'),
      ),
    );
  });

  testWidgets('shows duplicate-specific recovery without losing entered values', (tester) async {
    _setViewport(tester);
    when(
      () => actions.createBudget(
        any(),
        categoryId: any(named: 'categoryId'),
        flowType: any(named: 'flowType'),
        monthKey: any(named: 'monthKey'),
        currency: any(named: 'currency'),
        items: any(named: 'items'),
      ),
    ).thenThrow(Exception('budget-already-exists'));
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await _enter(tester, 'budget_item_description_0', 'Comida del mes');
    await _enter(tester, 'budget_item_amount_0', '450');
    await _tap(tester, 'budget_category_selector_expense');
    await tester.tap(find.text('Comida').last);
    await tester.pumpAndSettle();
    await _tap(tester, 'budget_save');

    expect(find.text('Ya existe un presupuesto para esta categoría y este mes.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('budget_item_description_0')))
          .controller!
          .text,
      'Comida del mes',
    );
  });

  testWidgets('fits a compact width with enlarged English text', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject(locale: const Locale('en'), textScale: 1.4));
    await tester.pumpAndSettle();

    expect(find.text('Plan by category'), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changes the selected budget month', (tester) async {
    _setViewport(tester);
    await tester.pumpWidget(subject(locale: const Locale('en')));
    await tester.pumpAndSettle();
    await _tap(tester, 'budget_month_selector');
    await tester.pumpAndSettle();
    final nextMonth = DateTime(DateTime.now().year, DateTime.now().month + 1);
    await tester.tap(find.byKey(ValueKey('budget_month_option_${nextMonth.month}')));
    await tester.tap(find.byKey(const ValueKey('budget_month_confirm')));
    await tester.pumpAndSettle();

    final expectedLabel = DateFormat('MMMM yyyy', 'en').format(nextMonth);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('budget_month_selector')),
        matching: find.text(expectedLabel),
      ),
      findsOneWidget,
    );
  });

  testWidgets('limits item days to the selected month and clamps the draft on month change', (
    tester,
  ) async {
    _setViewport(tester);
    await tester.pumpWidget(subject(locale: const Locale('en')));
    await tester.pumpAndSettle();

    final daySelector = find.byKey(const ValueKey('budget_item_day_0'));
    await tester.tap(daySelector);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Day 31'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Day 31'));
    await tester.pumpAndSettle();

    await _tap(tester, 'budget_month_selector');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_month_option_2')));
    await tester.tap(find.byKey(const ValueKey('budget_month_confirm')));
    await tester.pumpAndSettle();

    final selector = find.byKey(const ValueKey('budget_item_day_0'));
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const ValueKey('day_of_month_budget_item_day_0_1_28_28')),
          )
          .initialValue,
      28,
    );
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(find.text('Day 28'), findsWidgets);
    expect(find.text('Day 29'), findsNothing);
  });

  testWidgets('explains when the selected flow has no categories', (tester) async {
    _setViewport(tester);
    await tester.pumpWidget(subject(categories: const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('budget_create_category')), findsOneWidget);
    expect(find.textContaining('No hay categorías'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

const _categories = [
  FinanceCategory(
    id: 'food',
    type: CategoryType.expense,
    customName: 'Comida',
    icon: 'food',
    sortOrder: 1,
    isSystem: true,
    isArchived: false,
  ),
  FinanceCategory(
    id: 'salary',
    type: CategoryType.income,
    customName: 'Salario',
    icon: 'salary',
    sortOrder: 1,
    isSystem: true,
    isArchived: false,
  ),
];
