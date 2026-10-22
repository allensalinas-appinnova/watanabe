import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/budget.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_command_failure.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_flow_type.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_item.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/domain/entities/monthly_summary.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_budget_detail_screen.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_budget_item_edit_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _MockActions extends Mock implements CanonicalFinanceActions {}

class _FakeBudgetItem extends Fake implements BudgetItem {}

class _FakeBudgetItemDraft extends Fake implements CanonicalBudgetItemDraft {}

const _budget = Budget(
  id: 'budget-1',
  categoryId: 'food',
  flowType: BudgetFlowType.expense,
  monthKey: '2026-10',
  currency: 'COP',
  plannedAmountMinor: 420000,
  status: 'active',
);

const _item1 = BudgetItem(
  id: 'item-1',
  description: 'Mercado semanal',
  amountMinor: 280000,
  dayOfMonth: 15,
);
const _items = [
  _item1,
  BudgetItem(id: 'item-2', description: 'Frutas y verduras', amountMinor: 140000, dayOfMonth: 10),
];

const _category = FinanceCategory(
  id: 'food',
  type: CategoryType.expense,
  icon: 'restaurant',
  sortOrder: 1,
  isSystem: true,
  isArchived: false,
  customName: 'Comida',
);

MonthlySummary get _summary => const MonthlySummary(
  monthKey: '2026-10',
  currency: 'COP',
  incomeMinor: 0,
  expenseMinor: 256000,
  transferInMinor: 0,
  transferOutMinor: 0,
  byCategory: {'food': -256000},
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBudgetItem());
    registerFallbackValue(_FakeBudgetItemDraft());
  });
  late _MockActions actions;

  setUp(() {
    actions = _MockActions();
    when(() => actions.deleteBudgetItem(any(), any(), any())).thenAnswer((_) async {});
    when(() => actions.archiveBudget(any(), any())).thenAnswer((_) async => null);
    when(() => actions.updateBudgetItem(any(), any(), any())).thenAnswer((_) async {});
    when(() => actions.addBudgetItem(any(), any(), any())).thenAnswer((_) async {});
  });

  Widget subject({
    Widget initial = const CanonicalBudgetDetailScreen(budgetId: 'budget-1'),
    Locale locale = const Locale('es'),
    List<BudgetItem> items = _items,
    double textScale = 1,
    bool editFails = false,
  }) {
    if (editFails) {
      when(() => actions.updateBudgetItem(any(), any(), any())).thenThrow(Exception('offline'));
    }
    final router = GoRouter(
      initialLocation: '/budgets/budget-1',
      routes: [
        GoRoute(
          path: '/budgets',
          name: 'budgets',
          builder: (context, state) => const Scaffold(body: Text('Budgets list')),
        ),
        GoRoute(
          path: '/budgets/:id',
          builder: (context, state) => initial,
          routes: [
            GoRoute(
              path: 'items/new',
              builder: (context, state) => CanonicalBudgetItemEditScreen(
                budgetId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: 'items/:itemId/edit',
              builder: (context, state) => CanonicalBudgetItemEditScreen(
                budgetId: state.pathParameters['id']!,
                itemId: state.pathParameters['itemId']!,
                initialItem: state.extra as BudgetItem?,
              ),
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: false)),
        ),
        canonicalBudgetProvider.overrideWith((ref, input) => Stream.value(_budget)),
        canonicalFinanceRepositoryItemsProvider.overrideWith((ref, input) => Stream.value(items)),
        canonicalCategoriesProvider.overrideWith((ref, userId) => Stream.value([_category])),
        canonicalMonthlySummaryProvider.overrideWith((ref, input) => Stream.value(_summary)),
        canonicalActionsProvider.overrideWithValue(actions),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: locale,
        routerConfig: router,
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
      ),
    );
  }

  testWidgets('renders budget details in profile currency and hides remove on the last item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(subject(items: const [_item1]));
    await tester.pumpAndSettle();

    expect(find.text('Comida'), findsNWidgets(2));
    expect(find.textContaining('Gastado'), findsOneWidget);
    expect(find.textContaining('COP'), findsWidgets);
    expect(find.byKey(const ValueKey('budget_item_edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_item_remove')), findsNothing);
    expect(find.byKey(const ValueKey('budget_last_item_hint')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_archive_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_add_item_detail')), findsOneWidget);
  });

  testWidgets('adds an item from the budget detail and submits minor units', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('budget_add_item_detail')),
      300,
    );
    await tester.tap(find.byKey(const ValueKey('budget_add_item_detail')));
    await tester.pumpAndSettle();
    expect(find.text('Agregar elemento'), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const ValueKey('budget_item_create_description')),
      'Servicios públicos',
    );
    await tester.enterText(find.byKey(const ValueKey('budget_item_create_amount')), '45000');
    await tester.enterText(find.byKey(const ValueKey('budget_item_create_day')), '12');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_item_create_save')));
    await tester.pumpAndSettle();

    verify(
      () => actions.addBudgetItem(
        'user-1',
        'budget-1',
        any(
          that: isA<CanonicalBudgetItemDraft>()
              .having((draft) => draft.description, 'description', 'Servicios públicos')
              .having((draft) => draft.amountMinor, 'amountMinor', 45000)
              .having((draft) => draft.dayOfMonth, 'dayOfMonth', 12),
        ),
      ),
    ).called(1);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('budget_detail_category')),
      -300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('budget_detail_scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(const ValueKey('budget_detail_category')), findsOneWidget);
  });

  testWidgets('validates a new item and preserves fields after a recoverable error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => actions.addBudgetItem(any(), any(), any())).thenThrow(
      const BudgetCommandException(BudgetCommandIssue.network),
    );

    await tester.pumpWidget(
      subject(
        locale: const Locale('pt'),
        textScale: 1.2,
        initial: const CanonicalBudgetItemEditScreen(budgetId: 'budget-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Adicionar item'), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const ValueKey('budget_item_create_description')),
      'Água',
    );
    await tester.enterText(find.byKey(const ValueKey('budget_item_create_amount')), '45000');
    await tester.enterText(find.byKey(const ValueKey('budget_item_create_day')), '12');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('budget_item_create_save')));
    await tester.tap(find.byKey(const ValueKey('budget_item_create_save')));
    await tester.pumpAndSettle();
    verify(() => actions.addBudgetItem('user-1', 'budget-1', any())).called(1);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(
      find.text('É necessário ter conexão para salvar este orçamento. Suas alterações continuam aqui; tente novamente.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('budget_item_create_description')))
          .controller!
          .text,
      'Água',
    );
    expect(find.byKey(const ValueKey('budget_item_create_save')), findsOneWidget);
  });

  testWidgets('confirms item removal and archives the budget only after confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('budget_item_remove')).first);
    await tester.pumpAndSettle();
    expect(find.text('¿Quitar este elemento?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm_budget_item_delete')));
    await tester.pumpAndSettle();
    verify(() => actions.deleteBudgetItem('user-1', 'budget-1', 'item-1')).called(1);

    await tester.drag(
      find.byKey(const ValueKey('budget_detail_scroll')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_archive_button')));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar este presupuesto?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm_budget_archive')));
    await tester.pumpAndSettle();
    verify(() => actions.archiveBudget('user-1', 'budget-1')).called(1);
    expect(find.text('Budgets list'), findsOneWidget);
    expect(find.text('Presupuesto eliminado de la lista activa.'), findsOneWidget);
  });

  testWidgets('shows actionable safe diagnostics when archiving is rejected', (tester) async {
    when(() => actions.archiveBudget('user-1', 'budget-1')).thenAnswer(
      (_) async => const AuthFailure(
        'internal message must not be shown',
        technicalCode: 'permission-denied',
      ),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey('budget_detail_scroll')), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_archive_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_budget_archive')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Firebase no autorizó el cambio'), findsOneWidget);
    expect(find.textContaining('permission-denied'), findsOneWidget);
    expect(find.textContaining('internal message must not be shown'), findsNothing);
  });

  testWidgets('edits a budget item and keeps values visible after a recoverable error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_item_edit')).first);
    await tester.pumpAndSettle();
    expect(find.text('Editar elemento'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('budget_item_edit_description')),
      'Mercado quincenal',
    );
    await tester.enterText(find.byKey(const ValueKey('budget_item_edit_amount')), '300000');
    await tester.enterText(find.byKey(const ValueKey('budget_item_edit_day')), '20');
    await tester.ensureVisible(find.byKey(const ValueKey('budget_item_edit_save')));
    await tester.tap(find.byKey(const ValueKey('budget_item_edit_save')));
    await tester.pumpAndSettle();
    verify(
      () => actions.updateBudgetItem(
        'user-1',
        'budget-1',
        any(that: isA<BudgetItem>().having((item) => item.amountMinor, 'amount', 300000)),
      ),
    ).called(1);

    await tester.pumpWidget(
      subject(
        initial: const CanonicalBudgetItemEditScreen(
          budgetId: 'budget-1',
          itemId: 'item-1',
          initialItem: _item1,
        ),
        editFails: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('budget_item_edit_description')),
      'Texto conservado',
    );
    tester.binding.focusManager.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    tester
        .widget<FilledButton>(find.byKey(const ValueKey('budget_item_edit_save')))
        .onPressed!
        .call();
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos guardar los cambios. Tus datos siguen aquí; inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('budget_item_edit_description')))
          .controller!
          .text,
      'Texto conservado',
    );
  });

  testWidgets('validates description and day and renders Portuguese with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      subject(
        locale: const Locale('pt'),
        textScale: 1.3,
        initial: const CanonicalBudgetItemEditScreen(
          budgetId: 'budget-1',
          itemId: 'item-1',
          initialItem: _item1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('budget_item_edit_description')), '');
    await tester.enterText(find.byKey(const ValueKey('budget_item_edit_day')), '32');
    await tester.ensureVisible(find.byKey(const ValueKey('budget_item_edit_save')));
    await tester.tap(find.byKey(const ValueKey('budget_item_edit_save')));
    await tester.pumpAndSettle();
    expect(find.text('Informe uma descrição.'), findsOneWidget);
    expect(find.text('Escolha um dia existente no mês selecionado.'), findsWidgets);
    verifyNever(() => actions.updateBudgetItem(any(), any(), any()));
  });
}
