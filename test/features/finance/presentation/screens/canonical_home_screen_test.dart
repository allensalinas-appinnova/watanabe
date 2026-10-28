import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/theme/app_colors.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/appearance_preferences.dart';
import 'package:personal_finance/features/finance/domain/entities/budget.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_flow_type.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/monthly_summary.dart';
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_home_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('renders the home dashboard with distinct balance, budget and recent activity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final operationsInput = (
      userId: 'u1',
      cursor: null,
      monthKey: null,
      currency: null,
      type: null,
      accountIds: null,
      pageSize: 10,
    );
    var themeMode = ThemeMode.light;
    late void Function(ThemeMode mode) setThemeMode;
    final providers = ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'u1', isAnonymous: false)),
        ),
        pendingOperationAutoSyncProvider.overrideWith((ref) {}),
        pendingOperationsProvider.overrideWith((ref) => Stream.value(const [])),
        canonicalUserProfileProvider('u1').overrideWith(
          (ref) => Stream.value(
            const UserProfile(
              id: 'u1',
              locale: 'es',
              countryCode: 'CO',
              timeZone: 'UTC',
              defaultCurrency: 'COP',
              onboardingStatus: 'complete',
              categoryCatalogVersion: 1,
            ),
          ),
        ),
        canonicalAccountsProvider('u1').overrideWith(
          (ref) => Stream.value([
            const FinanceAccount(
              id: 'bank',
              name: 'Banco1',
              type: 'savings',
              currency: 'COP',
              currentBalanceMinor: 2000,
            ),
            const FinanceAccount(
              id: 'excluded',
              name: 'Oculta',
              type: 'savings',
              currency: 'COP',
              currentBalanceMinor: 9000,
              includeInDashboard: false,
            ),
            const FinanceAccount(
              id: 'archived',
              name: 'Archivada',
              type: 'savings',
              currency: 'COP',
              currentBalanceMinor: 4000,
              status: 'archived',
            ),
          ]),
        ),
        canonicalCategoriesProvider('u1').overrideWith(
          (ref) => Stream.value([
            const FinanceCategory(
              id: 'food',
              type: CategoryType.expense,
              icon: 'food',
              sortOrder: 0,
              isSystem: true,
              isArchived: false,
              customName: 'Comida',
            ),
            const FinanceCategory(
              id: 'salary',
              type: CategoryType.income,
              icon: 'salary',
              sortOrder: 1,
              isSystem: true,
              isArchived: false,
              customName: 'Salario',
            ),
            const FinanceCategory(
              id: 'housing',
              type: CategoryType.expense,
              icon: 'housing',
              sortOrder: 2,
              isSystem: true,
              isArchived: false,
              customName: 'Vivienda',
            ),
          ]),
        ),
        canonicalMonthlySummaryProvider((
          userId: 'u1',
          monthKey: monthKey,
          currency: 'COP',
        )).overrideWith(
          (ref) => Stream.value(
            MonthlySummary(
              monthKey: monthKey,
              currency: 'COP',
              incomeMinor: 10000,
              expenseMinor: 8000,
              transferInMinor: 0,
              transferOutMinor: 0,
              byCategory: const {'food': -8000, 'housing': -6000},
            ),
          ),
        ),
        canonicalBudgetsProvider((userId: 'u1', monthKey: monthKey)).overrideWith(
          (ref) => Stream.value([
            Budget(
              id: 'food-budget',
              categoryId: 'food',
              flowType: BudgetFlowType.expense,
              monthKey: monthKey,
              currency: 'COP',
              plannedAmountMinor: 5000,
              status: 'active',
            ),
            Budget(
              id: 'housing-budget',
              categoryId: 'housing',
              flowType: BudgetFlowType.expense,
              monthKey: monthKey,
              currency: 'COP',
              plannedAmountMinor: 4000,
              status: 'active',
            ),
            Budget(
              id: 'income-budget',
              categoryId: 'salary',
              flowType: BudgetFlowType.income,
              monthKey: monthKey,
              currency: 'COP',
              plannedAmountMinor: 20000,
              status: 'active',
            ),
          ]),
        ),
        canonicalOperationsPageProvider(operationsInput).overrideWith(
          (ref) async => OperationPage(
            items: [
              FinancialOperation(
                id: 'op-1',
                type: OperationType.income,
                amountMinor: 10000,
                currency: 'COP',
                monthKey: monthKey,
                occurredAt: now,
                status: OperationStatus.confirmed,
                idempotencyKey: 'i1',
                categoryId: 'salary',
                accountId: 'bank',
                description: 'Salario',
              ),
            ],
          ),
        ),
      ],
      child: StatefulBuilder(
        builder: (context, updateTheme) {
          setThemeMode = (mode) => updateTheme(() => themeMode = mode);
          return MaterialApp(
            locale: const Locale('es'),
            theme: AppTheme.forAppearance(AppearancePalette.lumio, Brightness.light),
            darkTheme: AppTheme.forAppearance(AppearancePalette.lumio, Brightness.dark),
            themeMode: themeMode,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.25)),
              child: child!,
            ),
            home: const CanonicalHomeScreen(),
          );
        },
      ),
    );

    await tester.pumpWidget(providers);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_dashboard_title')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home_credit_cards_shortcut')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final debtCommitmentsCard = find.byKey(const ValueKey('home_debt_commitments_card'));
    final debtAccountShortcuts = find.byKey(const ValueKey('home_credit_cards_shortcut'));
    expect(
      tester.getTopLeft(debtAccountShortcuts).dy - tester.getBottomLeft(debtCommitmentsCard).dy,
      greaterThanOrEqualTo(12),
    );
    expect(find.byKey(const ValueKey('home_balance_card')), findsOneWidget);
    expect(find.textContaining('Banco1:'), findsNothing);
    expect(find.textContaining('Oculta:'), findsNothing);
    expect(find.textContaining('Archivada:'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('home_toggle_account_breakdown')));
    await tester.tap(find.byKey(const ValueKey('home_toggle_account_breakdown')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Banco1:'), findsOneWidget);
    expect(find.textContaining('Oculta:'), findsNothing);
    expect(find.textContaining('Archivada:'), findsNothing);
    expect(find.byKey(const ValueKey('home_income_summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_expense_summary')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home_expense_budget_ratio')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('home_expense_budget_ratio')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_income_budget_ratio')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('home_expense_budget_percent'))).data,
      '89\u00a0%',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('home_expense_budget_percent'))).style?.color,
      AppTheme.forAppearance(
        AppearancePalette.lumio,
        Brightness.light,
      ).extension<AppThemeColors>()!.warning,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.descendant(
              of: find.byKey(const ValueKey('home_expense_budget_ratio')),
              matching: find.byType(LinearProgressIndicator),
            ),
          )
          .color,
      AppTheme.forAppearance(
        AppearancePalette.lumio,
        Brightness.light,
      ).extension<AppThemeColors>()!.warning,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('home_income_budget_percent'))).data,
      '50\u00a0%',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('home_income_budget_percent'))).style?.color,
      AppTheme.forAppearance(
        AppearancePalette.lumio,
        Brightness.light,
      ).extension<AppThemeColors>()!.expense,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.descendant(
              of: find.byKey(const ValueKey('home_income_budget_ratio')),
              matching: find.byType(LinearProgressIndicator),
            ),
          )
          .color,
      AppTheme.forAppearance(
        AppearancePalette.lumio,
        Brightness.light,
      ).extension<AppThemeColors>()!.expense,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('home_budget_preview_food-budget')));
    expect(find.byKey(const ValueKey('home_budget_preview_food-budget')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_budget_preview_housing-budget')), findsOneWidget);
    expect(find.textContaining('Vivienda ·'), findsOneWidget);
    final exceededLabels = find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data?.startsWith('Excedido') ?? false),
    );
    expect(exceededLabels, findsNWidgets(2));
    final exceededText = tester.widget<Text>(
      find.byKey(const ValueKey('home_budget_remaining_food-budget')),
    );
    expect(exceededText.style?.color, const Color(0xFFC73338));
    final exceededProgress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('home_budget_progress_food-budget')),
    );
    expect(exceededProgress.color, const Color(0xFFC73338));
    expect(find.text('Presupuesto del mes'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('home_dashboard_content')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('home_view_all_activity')));
    expect(find.byKey(const ValueKey('home_view_all_activity')), findsOneWidget);
    expect(find.text('Actividad reciente'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('home_dashboard_content')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    final homeAmount = find.byKey(const ValueKey('home_operation_amount_op-1'));
    expect(tester.widget<Text>(homeAmount).textAlign, TextAlign.end);
    final homeAmountColumn = find.ancestor(of: homeAmount, matching: find.byType(SizedBox)).first;
    expect(tester.getSize(homeAmountColumn).width, greaterThanOrEqualTo(96));

    await tester.drag(
      find.byKey(const ValueKey('home_dashboard_content')),
      const Offset(0, 1800),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('home_toggle_amount_visibility')));
    await tester.tap(find.byKey(const ValueKey('home_toggle_amount_visibility')));
    await tester.pumpAndSettle();
    expect(find.text('••••••'), findsAtLeastNWidgets(1));
    expect(find.byKey(const ValueKey('home_toggle_amount_visibility')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('home_toggle_amount_visibility')));
    await tester.tap(find.byKey(const ValueKey('home_toggle_amount_visibility')));
    await tester.pumpAndSettle();
    expect(find.text('••••••'), findsNothing);
    expect(tester.takeException(), isNull);

    setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('home_balance_card')));
    final cardFinder = find.byKey(const ValueKey('home_balance_card'));
    final balanceCard = tester.widget<Container>(cardFinder);
    final background = (balanceCard.decoration! as BoxDecoration).color!;
    final darkTheme = Theme.of(tester.element(cardFinder));
    final balanceColors = darkTheme.extension<AppThemeColors>()!;
    expect(background, balanceColors.balanceCardBackground);
    expect(background, isNot(darkTheme.colorScheme.onSurface));
    for (final key in const ['home_balance_label', 'home_balance_amount_COP']) {
      final text = tester.widget<Text>(find.byKey(ValueKey(key)));
      expect(_contrastRatio(text.style!.color!, background), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('home recent activity empty state follows dark theme colors', (tester) async {
    const message = 'Aún no tienes movimientos.';
    final darkTheme = AppTheme.forAppearance(AppearancePalette.lumio, Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: HomeRecentActivityEmptyState(message: message),
        ),
      ),
    );

    final emptyCardFinder = find.byKey(const ValueKey('home_empty_activity'));
    final emptyCard = tester.widget<Card>(emptyCardFinder);
    final emptyTheme = Theme.of(tester.element(emptyCardFinder));
    expect(emptyCard.color, isNull);
    expect(emptyTheme.cardTheme.color, emptyTheme.colorScheme.surface);

    final emptyCardMaterial = tester.widget<Material>(
      find.descendant(of: emptyCardFinder, matching: find.byType(Material)).first,
    );
    expect(emptyCardMaterial.color, emptyTheme.colorScheme.surface);
    final textStyle = tester.renderObject<RenderParagraph>(find.text(message)).text.style!;
    expect(textStyle.color, emptyTheme.colorScheme.onSurface);
    expect(
      _contrastRatio(textStyle.color!, emptyCardMaterial.color!),
      greaterThanOrEqualTo(4.5),
    );
    expect(tester.takeException(), isNull);
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker = firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
