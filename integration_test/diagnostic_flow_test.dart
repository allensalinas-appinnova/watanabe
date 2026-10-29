import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/core/utils/request_id.dart';
import 'package:personal_finance/features/diagnostics/data/firebase_diagnostic_repository.dart';
import 'package:personal_finance/features/diagnostics/domain/diagnostic_engine.dart';
import 'package:personal_finance/features/diagnostics/domain/diagnostic_record.dart';
import 'package:personal_finance/features/diagnostics/presentation/diagnostic_providers.dart';
import 'package:personal_finance/features/diagnostics/presentation/diagnostic_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

Future<T> next<T>(StreamIterator<T> iterator, bool Function(T) matches) async {
  return (() async {
    while (await iterator.moveNext()) {
      if (matches(iterator.current)) return iterator.current;
    }
    throw StateError('Stream ended');
  })().timeout(const Duration(seconds: 30));
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find
        .descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable))
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'complete context, project cash, save reserve, record payment and refresh diagnosis',
    (tester) async {
      if (!const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
        throw StateError('Emulators are required');
      }
      const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '10.0.2.2');
      await FirebaseBootstrap.initialize(
        AppEnvironment.dev,
        useEmulators: true,
        emulatorHost: host,
      );
      expect(FirebaseBootstrap.app.options.projectId, 'demo-clearbudget');
      await configureDependencies(useEmulators: true);
      final auth = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app);
      await auth.signOut();
      final uid = (await auth.signInAnonymously()).user!.uid;
      final db = FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app);
      final functions = FirebaseFunctions.instanceFor(
        app: FirebaseBootstrap.app,
        region: 'us-central1',
      );
      final root = db.collection('users').doc(uid);
      final stamp = FieldValue.serverTimestamp();
      final today = DateTime.now();
      final month = diagnosticMonth(today);
      await root.set({
        'locale': 'es',
        'countryCode': 'CO',
        'timeZone': 'America/Bogota',
        'defaultCurrency': 'COP',
        'onboardingStatus': 'complete',
        'categoryCatalogVersion': 3,
        'dataGeneration': 0,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
      await root.collection('accounts').doc('bank').set({
        'name': 'Synthetic Bank',
        'type': 'bank',
        'currency': 'COP',
        'openingBalanceMinor': 5000000,
        'currentBalanceMinor': 5000000,
        'includeInDashboard': false,
        'status': 'active',
        'dataGeneration': 0,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
      await root.collection('categories').doc('expense').set({
        'name': 'Synthetic expense',
        'type': 'expense',
        'icon': 'category',
        'sortOrder': 0,
        'isSystem': false,
        'isArchived': false,
        'dataGeneration': 0,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
      final budgetResult = await functions.httpsCallable('mutateBudget').call<Map<String, dynamic>>(
        {
          'action': 'create',
          'requestId': newRequestId(),
          'expectedGeneration': 0,
          'categoryId': 'expense',
          'flowType': 'expense',
          'monthKey': month,
          'currency': 'COP',
          'items': [
            {'description': 'Synthetic payment', 'amountMinor': 2000000, 'dayOfMonth': today.day},
          ],
        },
      );
      expect(budgetResult.data, isNotEmpty);
      final repository = FirebaseDiagnosticRepository(db, functions, auth);
      Future<void> save(String id, String kind, Map<String, Object> values) async {
        final result = await repository.save(
          uid,
          DiagnosticRecord(id, kind, values),
          generation: 0,
          revision: 0,
          requestId: newRequestId(),
        );
        result.match((failure) => fail(failure.message), (_) {});
      }

      await save('account-bank', 'account', {'accountId': 'bank', 'availability': 'immediate'});
      final iterator = StreamIterator(
        repository.watch(uid, today, DateTime(today.year, today.month - 12).toUtc()),
      );
      addTearDown(iterator.cancel);
      final initial = await next(iterator, (s) => s.input.plan.isNotEmpty && !s.input.cached);
      final payment = initial.input.plan.first;
      await save('mapping', 'plan', {'entryId': payment.id, 'accountId': 'bank', 'effect': 'cash'});
      await save('reserve', 'reserve', {
        'name': 'Synthetic emergency',
        'accountId': 'bank',
        'currency': 'COP',
        'amountMinor': 500000,
        'purpose': 'emergency',
      });
      await save('payment-reserve', 'reserve', {
        'name': 'Synthetic payment reserve',
        'accountId': 'bank',
        'currency': 'COP',
        'amountMinor': 2000000,
        'purpose': 'obligation',
        'entryId': payment.id,
      });
      final baseline = await next(
        iterator,
        (s) =>
            s.input.records.any((r) => r.id == 'payment-reserve') &&
            s.input.records.any((r) => r.id == 'reserve') &&
            s.input.records.any((r) => r.id == 'mapping'),
      );
      expect(
        const DiagnosticEngine()
            .calculate(baseline.input)
            .metrics
            .firstWhere((m) => m.key == 'freeMoney')
            .value,
        2500000,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [diagnosticRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DiagnosticScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('diagnostic_setup')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('diagnostic_add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('diagnostic_dependents')), '1');
      await tapVisible(tester, find.byKey(const ValueKey('diagnostic_save')));
      final contextValues =
          (await root.collection('diagnosticRecords').doc('context').get()).data()?['values']
              as Map<String, dynamic>;
      expect(contextValues['dependents'], 1);
      final requestId = newRequestId();
      await functions.httpsCallable('mutateOperation').call<Map<String, dynamic>>({
        'action': 'create',
        'requestId': requestId,
        'idempotencyKey': requestId,
        'expectedGeneration': 0,
        'type': 'expense',
        'amountMinor': 2000000,
        'currency': 'COP',
        'accountId': 'bank',
        'categoryId': 'expense',
        'monthKey': month,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
        'description': 'Synthetic payment',
        'budgetId': payment.budgetId,
        'budgetItemId': payment.itemId,
      });
      final updated = await next(
        iterator,
        (s) =>
            s.input.plan.any((p) => p.id == payment.id && p.pendingMinor == 0) &&
            s.input.accounts.any((a) => a.id == 'bank' && a.currentBalanceMinor == 3000000),
      );
      final report = const DiagnosticEngine().calculate(updated.input);
      expect(report.metrics.firstWhere((m) => m.key == 'freeMoney').value, 2500000);
      expect(report.metrics.firstWhere((m) => m.key == 'cashFlow').value, -2000000);
      expect(report.projection.any((p) => p.reference == payment.id), isFalse);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(DiagnosticScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await auth.signOut();
    },
  );
}
