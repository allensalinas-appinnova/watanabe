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
import 'package:personal_finance/features/finance/presentation/screens/canonical_accounts_screen.dart';
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
      'createdAt': now,
      'updatedAt': now,
    });
    await root.collection('accounts').doc('bank').set({
      'name': 'Synthetic bank',
      'type': 'checking',
      'currency': 'COP',
      'openingBalanceMinor': 10000,
      'currentBalanceMinor': 10000,
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
      final router = GoRouter(
        initialLocation: '/debts/new',
        routes: [
          GoRoute(path: '/accounts', builder: (_, _) => const CanonicalAccountsScreen()),
          GoRoute(path: '/debts/new', builder: (_, _) => const DebtFormScreen()),
          GoRoute(
            path: '/debts/:id/actions/:action',
            builder: (_, state) => DebtFormScreen(
              accountId: state.pathParameters['id'],
              action: state.pathParameters['action']!,
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
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('debt_save')),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const ValueKey('debt_save')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
        await waitFor(find.byKey(const ValueKey('accounts_add_button')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
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
      await tester.enterText(find.byKey(const ValueKey('debt_amountMinor')), '1000');
      await tester.scrollUntilVisible(
        find.text('Categoría'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic food').last);
      await tester.pumpAndSettle();
      await submit();
      expect((await card.docs.single.reference.get()).data()!['currentBalanceMinor'], -1000);
      router.go('/debts/$cardId/actions/pay');
      await tester.pumpAndSettle();
      await waitFor(find.byKey(const ValueKey('debt_amountMinor')));
      final bankDropdown = find.byKey(const ValueKey('debt_bank_COP'));
      await waitFor(bankDropdown);
      await tester.ensureVisible(bankDropdown);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('debt_amountMinor')), '1000');
      await tester.tap(bankDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic bank').last);
      await tester.pumpAndSettle();
      await submit();
      expect(
        (await card.docs.single.reference.get(
          const GetOptions(source: Source.server),
        )).data()!['currentBalanceMinor'],
        0,
      );
      expect(
        (await root.collection('accounts').doc('bank').get()).data()!['currentBalanceMinor'],
        9000,
      );
      final summaries = await root.collection('monthlySummaries').get();
      expect(summaries.docs.single.data()['expenseMinor'], 1000);
      expect(summaries.docs.single.data()['incomeMinor'], 0);
      expect((await root.collection('operations').get()).size, 2);
      // The Flutter repository also sends explicit loan payment components.
      final debts = getIt<DebtRepository>();
      final result = await debts.execute(
        root.id,
        DebtCommand(
          requestId: 'synthetic_loan01',
          fields: {
            'action': 'create',
            'name': 'Synthetic loan',
            'product': 'bankLoan',
            'currency': 'COP',
            'mode': 'existing',
            'referenceAt': '2026-01-01T00:00:00Z',
            'principalMinor': 1000,
            'chargesMinor': 100,
          },
        ),
      );
      final loanId = result.match((f) => throw StateError(f.message), (r) => r.accountId);
      final paid = await debts.execute(
        root.id,
        DebtCommand(
          requestId: 'synthetic_pay001',
          fields: {
            'action': 'pay',
            'accountId': loanId,
            'bankAccountId': 'bank',
            'occurredAt': DateTime.now().toUtc().toIso8601String(),
            'amountMinor': 450,
            'principalMinor': 300,
            'previousChargesMinor': 100,
            'newChargesMinor': 50,
            'categoryId': 'food',
          },
        ),
      );
      expect(paid.isRight(), true);
      expect((await root.collection('accounts').doc(loanId).get()).data()!['principalMinor'], 700);
      router.dispose();
    },
  );
}
