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
  setUpAll(() => registerFallbackValue(_FakeFinanceCategory()));

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

    final nameField = find.byKey(const ValueKey('category_edit_name'));
    await tester.enterText(nameField, 'Mercado y comida');
    await tester.tap(find.byKey(const ValueKey('category_edit_save')));
    await tester.pumpAndSettle();
    expect(find.text('Ocurrió un problema. Inténtalo de nuevo.'), findsWidgets);
    expect(tester.widget<TextField>(nameField).controller!.text, 'Mercado y comida');

    await tester.tap(find.byKey(const ValueKey('category_edit_save')));
    await tester.pumpAndSettle();
    expect(find.text('Categoría actualizada'), findsOneWidget);
    verify(() => repository.updateCategory('user-1', any(that: isA<FinanceCategory>()))).called(2);
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
    await tester.tap(find.byKey(const ValueKey('category_edit_archive')));
    await tester.pumpAndSettle();

    expect(find.text('Arquivar esta categoria?'), findsOneWidget);
    expect(find.textContaining('registros existentes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
