import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_operation_form_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('opens category management without losing the operation draft', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/operations/new',
      routes: [
        GoRoute(
          path: '/operations/new',
          builder: (context, state) => const CanonicalOperationFormScreen(),
        ),
        GoRoute(
          path: '/categories',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Category management route')),
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
          canonicalAccountsProvider('user-1').overrideWith(
            (ref) =>
                Stream.value(const [FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash')]),
          ),
          canonicalCategoriesProvider('user-1').overrideWith(
            (ref) => Stream.value(const [
              FinanceCategory(
                id: 'food',
                type: CategoryType.expense,
                icon: 'food',
                sortOrder: 1,
                isSystem: true,
                isArchived: false,
                customName: 'Comida',
              ),
            ]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
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

    final amountField = find.byKey(const ValueKey('operation_amount'));
    await tester.enterText(amountField, '250');
    await tester.tap(find.byKey(const ValueKey('operation_manage_categories')));
    await tester.pumpAndSettle();
    expect(find.text('Category management route'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(amountField).controller!.text, '250');
    expect(find.byKey(const ValueKey('operation_manage_categories')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
