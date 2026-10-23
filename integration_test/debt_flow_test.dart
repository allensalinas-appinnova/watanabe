import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/debts/domain/debt_command.dart';
import 'package:personal_finance/features/debts/domain/debt_repository.dart';
import 'package:personal_finance/features/debts/presentation/debt_form_screen.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/domain/usecases/calculate_budget_tracking.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_accounts_screen.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_activity_screen.dart';
import 'package:personal_finance/features/finance/presentation/utils/activity_csv_exporter.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late DocumentReference<Map<String, dynamic>> root;
  late FirebaseFirestore db;
  setUpAll(() async {
    if (!const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      throw StateError('Emulator required');
    }
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '10.0.2.2');
    await FirebaseBootstrap.initialize(AppEnvironment.dev, useEmulators: true, emulatorHost: host);
    if (FirebaseBootstrap.app.options.projectId != 'demo-clearbudget') {
      throw StateError('Synthetic project only');
    }
    await configureDependencies(useEmulators: true);
    final auth = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app);
    await auth.signOut();
    final user = (await auth.signInAnonymously()).user!;
    db = FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app);
    root = db.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();
    await root.set({
      'locale': 'es',
      'countryCode': 'CO',
      'timeZone': 'America/Bogota',
      'defaultCurrency': 'COP',
      'onboardingStatus': 'complete',
      'categoryCatalogVersion': 1,
      'appearancePreferences': {'mode': 'dark', 'palette': 'ocean'},
      'createdAt': now,
      'updatedAt': now,
    });
    await root.collection('accounts').doc('bank').set({
      'name': 'Synthetic bank',
      'type': 'checking',
      'currency': 'COP',
      'openingBalanceMinor': 1000000,
      'currentBalanceMinor': 1000000,
      'includeInDashboard': true,
      'status': 'active',
      'createdAt': now,
      'updatedAt': now,
    });
    await root.collection('categories').doc('food').set({
      'name': 'Synthetic food',
      'type': 'expense',
      'icon': 'category',
      'sortOrder': 0,
      'isSystem': false,
      'isArchived': false,
      'createdAt': now,
      'updatedAt': now,
    });
  });

  testWidgets(
    'Flutter creates a card, buys and pays through authenticated callables without duplicate expense',
    (tester) async {
      final repository = getIt<CanonicalFinanceRepository>();
      final auth = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app);
      final sync = await repository.syncDefaultCategories(root.id, locale: 'es', countryCode: 'CO');
      expect(sync.isRight(), isTrue);
      final profile = (await root.get()).data()!;
      expect(profile['categoryCatalogVersion'], 2);
      expect(profile['appearancePreferences'], {'mode': 'dark', 'palette': 'ocean'});
      final interestCategory = await root.collection('categories').doc('interest_fees').get();
      expect(interestCategory.data()?['name'], 'Intereses y comisiones');
      await interestCategory.reference.update({'name': 'Intereses personales'});
      await repository.syncDefaultCategories(root.id, locale: 'en', countryCode: 'CO');
      final customizedInterestCategory = await interestCategory.reference.get();
      expect(customizedInterestCategory.data()?['name'], 'Intereses personales');
      expect(
        (await root.collection('categories').get()).docs
            .where((d) => d.id == 'interest_fees')
            .length,
        1,
      );
      final now = DateTime.now();
      final monthKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
      for (final categoryId in ['food', 'interest_fees']) {
        final budget = await repository.createBudgetWithItems(
          root.id,
          categoryId: categoryId,
          flowType: 'expense',
          monthKey: monthKey,
          currency: 'COP',
          items: const [
            CanonicalBudgetItemDraft(
              description: 'E2E planned',
              amountMinor: 500000,
              dayOfMonth: 1,
            ),
          ],
        );
        expect(budget.isRight(), isTrue);
      }

      final router = GoRouter(
        initialLocation: '/debts/new',
        routes: [
          GoRoute(path: '/accounts', builder: (_, _) => const CanonicalAccountsScreen()),
          GoRoute(path: '/activity', builder: (_, _) => const CanonicalActivityScreen()),
          GoRoute(path: '/debts/new', builder: (_, _) => const DebtFormScreen()),
          GoRoute(
            path: '/debts/:id/actions/:action',
            builder: (_, state) => DebtFormScreen(
              accountId: state.pathParameters['id'],
              action: state.pathParameters['action']!,
              originalOperationId: state.uri.queryParameters['originalOperationId'],
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      Future<void> waitFor(Finder finder) async {
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(finder, findsWidgets);
      }

      Future<void> submit() async {
        final saveButton = find.byKey(const ValueKey('debt_save')).last;
        await tester.scrollUntilVisible(
          saveButton,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        final accountCount = (await root.collection('accounts').get()).size;
        final operationCount = (await root.collection('operations').get()).size;
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        var committed = false;
        while (!committed && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 250));
          final accountsAfter = await root
              .collection('accounts')
              .get(
                const GetOptions(source: Source.server),
              );
          final operationsAfter = await root
              .collection('operations')
              .get(
                const GetOptions(source: Source.server),
              );
          committed = accountsAfter.size > accountCount || operationsAfter.size > operationCount;
        }
        expect(committed, isTrue);
        router.go('/accounts');
        await waitFor(find.byKey(const ValueKey('accounts_add_button')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }

      Future<void> choosePopup(String controlKey, String optionKey) async {
        final formScroll = find
            .byWidgetPredicate(
              (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
            )
            .last;
        await tester.scrollUntilVisible(
          find.byKey(ValueKey(controlKey)).last,
          140,
          scrollable: formScroll,
        );
        await tester.tap(find.byKey(ValueKey(controlKey)).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(optionKey)).last);
        await tester.pumpAndSettle();
      }

      Future<void> enter(String key, String value) async {
        final field = find.byKey(ValueKey('debt_$key')).last;
        final formScroll = find
            .byWidgetPredicate(
              (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
            )
            .last;
        await tester.scrollUntilVisible(field, 140, scrollable: formScroll);
        await tester.enterText(field, value);
        await tester.pumpAndSettle();
      }

      await waitFor(find.byKey(const ValueKey('debt_name')));
      await tester.enterText(find.byKey(const ValueKey('debt_name')), 'Synthetic card');
      await submit();
      final card = await root
          .collection('accounts')
          .where('nature', isEqualTo: 'debt')
          .get(const GetOptions(source: Source.server));
      expect(card.size, 1);
      final cardId = card.docs.single.id;
      router.go('/debts/$cardId/actions/purchase');
      await waitFor(find.byKey(const ValueKey('debt_amountMinor')));
      await enter('amountMinor', '1000');
      await choosePopup('debt_category_selector_tap', 'finance_popup_option_food');
      await submit();
      expect((await card.docs.single.reference.get()).data()!['currentBalanceMinor'], -1000);

      router.go('/debts/$cardId/actions/pay');
      await tester.pumpAndSettle();
      await enter('amountMinor', '400');
      await choosePopup('debt_bank_COP_tap', 'finance_popup_option_bank');
      await submit();
      expect((await card.docs.single.reference.get()).data()!['currentBalanceMinor'], -600);
      router.go('/debts/$cardId/actions/pay');
      await tester.pumpAndSettle();
      await enter('amountMinor', '600');
      await choosePopup('debt_bank_COP_tap', 'finance_popup_option_bank');
      await submit();
      expect(
        (await card.docs.single.reference.get(
          const GetOptions(source: Source.server),
        )).data()!['currentBalanceMinor'],
        0,
      );
      expect(
        (await root.collection('accounts').doc('bank').get()).data()!['currentBalanceMinor'],
        999000,
      );

      router.go('/debts/$cardId/actions/charge');
      await tester.pumpAndSettle();
      await enter('amountMinor', '100');
      await waitFor(find.text('Intereses personales'));
      await submit();
      final cardCharge = await root
          .collection('operations')
          .where('debtKind', isEqualTo: 'charge')
          .get();
      expect(cardCharge.size, 1);
      expect(cardCharge.docs.single.data()['categoryId'], 'interest_fees');

      router.go('/debts/$cardId/actions/pay');
      await tester.pumpAndSettle();
      await enter('amountMinor', '100');
      await choosePopup('debt_bank_COP_tap', 'finance_popup_option_bank');
      await submit();
      expect((await card.docs.single.reference.get()).data()!['currentBalanceMinor'], 0);

      final purchase =
          (await root.collection('operations').where('debtKind', isEqualTo: 'purchase').get())
              .docs
              .single;
      router.go('/debts/$cardId/actions/refund?originalOperationId=${purchase.id}');
      await tester.pumpAndSettle();
      await enter('amountMinor', '300');
      await submit();
      expect((await card.docs.single.reference.get()).data()!['currentBalanceMinor'], 300);

      router.go('/debts/new');
      await tester.pumpAndSettle();
      await waitFor(find.byKey(const ValueKey('debt_name')));
      await tester.enterText(find.byKey(const ValueKey('debt_name')), 'Same name');
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crédito bancario').last);
      await tester.pumpAndSettle();
      await enter('principalMinor', '500000');
      await enter('chargesMinor', '50000');
      await submit();
      final loan = (await root.collection('accounts').where('type', isEqualTo: 'bankLoan').get())
          .docs
          .single;
      expect(loan.data()['principalMinor'], 500000);
      expect(loan.data()['currentBalanceMinor'], -550000);

      router.go('/debts/${loan.id}/actions/pay');
      await tester.pumpAndSettle();
      await enter('amountMinor', '200000');
      await choosePopup('debt_bank_COP_tap', 'finance_popup_option_bank');
      await enter('principalMinor', '150000');
      await enter('previousChargesMinor', '30000');
      await enter('newChargesMinor', '20000');
      await waitFor(find.byKey(const ValueKey('debt_category_selector_tap')));
      await submit();
      final loanData = (await loan.reference.get()).data()!;
      expect(loanData['principalMinor'], 350000);
      expect(loanData['chargesMinor'], 20000);
      expect(loanData['currentBalanceMinor'], -370000);
      expect(
        (await root.collection('accounts').doc('bank').get()).data()!['currentBalanceMinor'],
        798900,
      );

      final summaries = await root.collection('monthlySummaries').get();
      final currentSummary = summaries.docs.single.data();
      final byCategory = currentSummary['byCategory'] as Map<String, dynamic>;
      expect(currentSummary['expenseMinor'], 20800);
      expect(currentSummary['incomeMinor'], 0);
      expect(byCategory['food'], 700);
      expect(byCategory['interest_fees'], 20100);
      final budgets = await repository.watchBudgets(root.id, monthKey).first;
      final summary = await repository.watchMonthlySummary(root.id, monthKey, 'COP').first;
      const tracking = CalculateBudgetTracking();
      for (final budget in budgets) {
        final actual = tracking(budget, const [], summary: summary).actualMinor;
        expect(actual, budget.categoryId == 'food' ? 700 : 20100);
      }

      router.go('/debts/new');
      await tester.pumpAndSettle();
      await waitFor(find.byKey(const ValueKey('debt_name')));
      await tester.enterText(find.byKey(const ValueKey('debt_name')), 'Same name');
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Préstamo personal').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>).last);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Préstamo recibido ahora').last);
      await tester.pumpAndSettle();
      await enter('principalMinor', '300000');
      await enter('chargesMinor', '0');
      await choosePopup('debt_bank_COP_tap', 'finance_popup_option_bank');
      await submit();
      final personalLoan =
          (await root.collection('accounts').where('type', isEqualTo: 'personalLoan').get())
              .docs
              .single;
      expect(personalLoan.data()['principalMinor'], 300000);
      expect(
        (await root.collection('accounts').doc('bank').get()).data()!['currentBalanceMinor'],
        1098900,
      );
      expect(currentSummary['incomeMinor'], 0);

      router.go('/activity');
      await tester.pumpAndSettle();
      await waitFor(find.byKey(const ValueKey('activity_filter_debt_payments')));
      await tester.ensureVisible(find.byKey(const ValueKey('activity_filter_debt_payments')));
      await tester.tap(find.byKey(const ValueKey('activity_filter_debt_payments')));
      await tester.pumpAndSettle();
      await waitFor(find.text('Pago de tarjeta'));
      expect(find.text('Pago de crédito'), findsWidgets);

      // Build a synthetic history larger than one page through the authenticated
      // command API so this verifies the Firestore scan and cursor path.
      final debtRepository = getIt<DebtRepository>();
      final pageCardResult = await debtRepository.execute(
        root.id,
        DebtCommand(
          requestId: 'synthetic_page_card',
          fields: {
            'action': 'create',
            'name': 'Pagination card',
            'product': 'creditCard',
            'currency': 'COP',
            'mode': 'existing',
            'referenceAt': DateTime.now().toUtc().toIso8601String(),
            'debtMinor': -105,
          },
        ),
      );
      final pageCardId = pageCardResult.match(
        (failure) => throw StateError(failure.message),
        (result) => result.accountId,
      );
      for (var index = 0; index < 105; index++) {
        final payment = await debtRepository.execute(
          root.id,
          DebtCommand(
            requestId: 'synthetic_page_pay_${index.toString().padLeft(3, '0')}',
            fields: {
              'action': 'pay',
              'accountId': pageCardId,
              'bankAccountId': 'bank',
              'occurredAt': DateTime.now().toUtc().toIso8601String(),
              'amountMinor': 1,
            },
          ),
        );
        payment.match((failure) => throw StateError(failure.message), (_) {});
      }

      final paymentPages = <FinancialOperation>[];
      OperationPageCursor? cursor;
      while (true) {
        final page = await repository.fetchOperationsPage(
          root.id,
          cursor: cursor,
          debtPaymentsOnly: true,
          pageSize: 100,
        );
        final value = page.match(
          (failure) => throw StateError(failure.message),
          (result) => result,
        );
        paymentPages.addAll(value.items);
        cursor = value.nextCursor;
        if (cursor == null) break;
      }
      expect(paymentPages, hasLength(110));
      expect(paymentPages.map((operation) => operation.id).toSet(), hasLength(110));
      expect(paymentPages.every((operation) => operation.isDebtPaymentComponent), isTrue);
      expect(paymentPages.any((operation) => operation.type == OperationType.expense), isTrue);
      final csv = ActivityCsvExporter.export(
        operations: paymentPages,
        accounts: [
          const FinanceAccount(id: 'bank', name: 'Synthetic bank', type: 'checking'),
          FinanceAccount(id: cardId, name: 'Synthetic card', type: 'creditCard', nature: 'debt'),
          FinanceAccount(id: loan.id, name: 'Same name', type: 'bankLoan', nature: 'debt'),
          FinanceAccount(
            id: pageCardId,
            name: 'Pagination card',
            type: 'creditCard',
            nature: 'debt',
          ),
        ],
        categories: const [],
        labels: const ActivityCsvLabels(
          date: 'Fecha',
          type: 'Tipo',
          description: 'Descripción',
          account: 'Cuenta',
          category: 'Categoría',
          amount: 'Importe',
          currency: 'Moneda',
          status: 'Estado',
          income: 'Ingreso',
          expense: 'Gasto',
          transfer: 'Transferencia',
          pending: 'Pendiente',
          confirmed: 'Confirmado',
          rejected: 'Rechazado',
          unknownAccount: 'Cuenta desconocida',
          unknownCategory: 'Categoría desconocida',
          paymentType: 'Tipo de pago',
          cardPayment: 'Pago de tarjeta',
          loanPayment: 'Pago de crédito',
        ),
      );
      expect(csv, contains('Pago de tarjeta'));
      expect(csv, contains('Pago de crédito'));
      expect(csv, contains('Transferencia'));
      expect(csv, contains('Gasto'));
      expect(csv.split('\r\n').length - 2, paymentPages.length);

      await root.collection('categories').doc('interest_fees').update({'isArchived': true});
      await repository.syncDefaultCategories(root.id, locale: 'es', countryCode: 'CO');
      final archivedInterestCategory = await root
          .collection('categories')
          .doc('interest_fees')
          .get();
      expect(archivedInterestCategory.data()?['isArchived'], true);

      await auth.signOut();
      final secondUser = (await auth.signInAnonymously()).user!;
      final secondRoot = db.collection('users').doc(secondUser.uid);
      await secondRoot.set({
        'locale': 'en',
        'countryCode': 'CO',
        'timeZone': 'UTC',
        'defaultCurrency': 'COP',
        'onboardingStatus': 'complete',
        'categoryCatalogVersion': 1,
        'appearancePreferences': {'mode': 'light', 'palette': 'plum'},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await repository.syncDefaultCategories(secondUser.uid, locale: 'en', countryCode: 'CO');
      expect(
        (await secondRoot.collection('categories').doc('interest_fees').get()).data()?['name'],
        'Interest and fees',
      );
      final secondProfile = (await secondRoot.get()).data()!;
      expect(secondProfile['appearancePreferences'], {'mode': 'light', 'palette': 'plum'});
      router.dispose();
    },
  );
}
