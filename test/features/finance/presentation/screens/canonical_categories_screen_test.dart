import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_categories_screen.dart';
import 'package:personal_finance/features/finance/presentation/widgets/finance_category_icon.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _MockFinanceRepository extends Mock implements CanonicalFinanceRepository {}

class _FakeFinanceCategory extends Fake implements FinanceCategory {}

const _categories = [
  FinanceCategory(
    id: 'food',
    type: CategoryType.expense,
    icon: 'restaurant',
    sortOrder: 1,
    isSystem: true,
    isArchived: false,
    customName: 'Comida',
    colorValue: 0xFFB4233A,
  ),
  FinanceCategory(
    id: 'salary',
    type: CategoryType.income,
    icon: 'payments',
    sortOrder: 1,
    isSystem: true,
    isArchived: false,
    customName: 'Salario',
  ),
];

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFinanceCategory());
    registerFallbackValue(CategoryType.expense);
  });

  Widget subject({
    required _MockFinanceRepository repository,
    Locale locale = const Locale('es'),
    double textScale = 1,
  }) => ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: false)),
      ),
      canonicalCategoriesProvider('user-1').overrideWith((ref) => Stream.value(_categories)),
      canonicalFinanceRepositoryProvider.overrideWithValue(repository),
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
      home: const CanonicalCategoriesScreen(),
    ),
  );

  testWidgets('filters category type and edits name with recoverable retry', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MockFinanceRepository();
    var attempts = 0;
    when(() => repository.updateCategory(any(), any())).thenAnswer((_) async {
      attempts++;
      return attempts == 1
          ? const Left<Failure, Unit>(NetworkFailure('offline'))
          : const Right<Failure, Unit>(unit);
    });

    await tester.pumpWidget(subject(repository: repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category_row_food')), findsOneWidget);
    expect(find.byKey(const ValueKey('category_row_salary')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('categories_type_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingresos'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category_row_salary')), findsOneWidget);
    expect(find.byKey(const ValueKey('category_row_food')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('categories_type_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gastos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_edit_food')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('category_icon_change')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_icon_option_health')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_icon_cancel')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FinanceCategoryIcon>(find.byKey(const ValueKey('category_icon_preview')))
          .iconId,
      'restaurant',
    );
    await tester.tap(find.byKey(const ValueKey('category_icon_change')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_icon_option_health')));
    await tester.tap(find.byKey(const ValueKey('category_icon_use')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('category_color_change')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_color_option_ff087e8b')));
    await tester.tap(find.byKey(const ValueKey('category_color_cancel')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FinanceCategoryIcon>(find.byKey(const ValueKey('category_icon_preview')))
          .colorValue,
      0xFFB4233A,
    );

    await tester.tap(find.byKey(const ValueKey('category_color_change')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_color_option_ff147d55')));
    await tester.tap(find.byKey(const ValueKey('category_color_use')));
    await tester.pumpAndSettle();

    final nameField = find.byKey(const ValueKey('category_edit_name'));
    await tester.enterText(nameField, 'Mercado y comida');
    await tester.tap(find.byKey(const ValueKey('category_edit_save')));
    await tester.pumpAndSettle();
    expect(find.text('Ocurrió un problema. Inténtalo de nuevo.'), findsWidgets);
    expect(tester.widget<TextField>(nameField).controller!.text, 'Mercado y comida');
    expect(
      tester
          .widget<FinanceCategoryIcon>(find.byKey(const ValueKey('category_icon_preview')))
          .iconId,
      'health',
    );
    expect(
      tester
          .widget<FinanceCategoryIcon>(find.byKey(const ValueKey('category_icon_preview')))
          .colorValue,
      0xFF147D55,
    );

    await tester.tap(find.byKey(const ValueKey('category_edit_save')));
    await tester.pumpAndSettle();
    expect(find.text('Categoría actualizada'), findsOneWidget);
    verify(
      () => repository.updateCategory(
        'user-1',
        any(
          that: predicate<FinanceCategory>(
            (item) => item.icon == 'health' && item.colorValue == 0xFF147D55,
          ),
        ),
      ),
    ).called(2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a category with the explicitly confirmed icon', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MockFinanceRepository();
    when(
      () => repository.createCategory(
        any(),
        name: any(named: 'name'),
        type: any(named: 'type'),
        icon: any(named: 'icon'),
        colorValue: any(named: 'colorValue'),
      ),
    ).thenAnswer(
      (_) async => const Right<Failure, FinanceCategory>(
        FinanceCategory(
          id: 'custom1',
          type: CategoryType.expense,
          icon: 'transport',
          sortOrder: 9,
          isSystem: false,
          isArchived: false,
          customName: 'Movilidad',
        ),
      ),
    );

    await tester.pumpWidget(subject(repository: repository, locale: const Locale('pt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('categories_create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('category_create_name')), 'Mobilidade');
    await tester.tap(find.byKey(const ValueKey('category_icon_change')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_icon_option_transport')));
    await tester.tap(find.byKey(const ValueKey('category_icon_use')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_color_change')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_color_option_ffb54708')));
    await tester.tap(find.byKey(const ValueKey('category_color_use')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category_create_save')));
    await tester.tap(find.byKey(const ValueKey('category_create_save')));
    await tester.pumpAndSettle();

    verify(
      () => repository.createCategory(
        'user-1',
        name: 'Mobilidade',
        type: CategoryType.expense,
        icon: 'transport',
        colorValue: 0xFFB54708,
      ),
    ).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create category uses the edit form visual system on compact screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MockFinanceRepository();
    await tester.pumpWidget(
      subject(repository: repository, locale: const Locale('es'), textScale: 1.35),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('categories_create')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('category_create_dialog_surface')), findsOneWidget);
    expect(find.byKey(const ValueKey('category_create_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('category_create_name')), findsOneWidget);
    expect(find.byKey(const ValueKey('category_create_type')), findsOneWidget);
    expect(find.byKey(const ValueKey('category_icon_preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('category_icon_change')), findsOneWidget);
    expect(find.byKey(const ValueKey('category_color_preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('category_color_change')), findsOneWidget);
    expect(find.byKey(const ValueKey('category_create_cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('category_create_save')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('category_create_save')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('archive action explains that existing records are preserved', (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MockFinanceRepository();
    await tester.pumpWidget(
      subject(repository: repository, locale: const Locale('pt'), textScale: 1.35),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_edit_food')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category_edit_archive')));
    await tester.tap(find.byKey(const ValueKey('category_edit_archive')));
    await tester.pumpAndSettle();

    expect(find.text('Arquivar esta categoria?'), findsOneWidget);
    expect(find.textContaining('registros existentes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
