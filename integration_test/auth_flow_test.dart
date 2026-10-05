import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/app.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/features/finance/data/datasources/receipt_image_picker.dart';
import 'package:personal_finance/features/finance/domain/entities/receipt_attachment.dart';
import 'package:personal_finance/features/finance/presentation/providers/finance_providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const emulatorHost = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    );
    debugPrint('E2E Firebase emulator host: $emulatorHost');
    final httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    late final int healthStatusCode;
    try {
      final healthResponse = await httpClient
          .getUrl(Uri(scheme: 'http', host: emulatorHost, port: 59199))
          .then((request) => request.close())
          .timeout(const Duration(seconds: 10));
      healthStatusCode = healthResponse.statusCode;
      await healthResponse.drain<void>().timeout(const Duration(seconds: 2));
    } finally {
      httpClient.close(force: true);
    }
    if (healthStatusCode != HttpStatus.ok) {
      throw StateError(
        'Firebase Auth Emulator health check failed: '
        '$healthStatusCode at $emulatorHost:59199',
      );
    }

    await FirebaseBootstrap.initialize(
      AppEnvironment.dev,
      useEmulators: true,
      emulatorHost: emulatorHost,
    );
    await configureDependencies();
    await FirebaseAuth.instance.signOut();
  });

  tearDownAll(() async {
    await FirebaseAuth.instance.signOut();
    await GetIt.I.reset();
  });

  testWidgets(
    'email login, Firestore owner rules, anonymous login and sign out work end to end',
    (tester) async {
      final email = 'e2e-${DateTime.now().microsecondsSinceEpoch}@example.test';
      const password = 'ClearBudget-E2E-123';

      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      final userRoot = FirebaseFirestore.instance.collection('users').doc(uid);
      final accountFixtures = <Map<String, Object>>[
        {
          'id': 'checking',
          'name': 'Main checking',
          'type': 'Checking',
          'balance': 6420500,
          'sortOrder': 0,
        },
        {
          'id': 'savings',
          'name': 'Savings goal',
          'type': 'Savings',
          'balance': 4800000,
          'sortOrder': 1,
        },
        {
          'id': 'wallet',
          'name': 'Cash wallet',
          'type': 'Wallet',
          'balance': 760000,
          'sortOrder': 2,
        },
        {
          'id': 'credit',
          'name': 'Credit card',
          'type': 'Credit card',
          'balance': -500000,
          'sortOrder': 3,
        },
      ];
      for (final account in accountFixtures) {
        await userRoot.collection('accounts').doc(account['id']! as String).set({
          'name': account['name'],
          'type': account['type'],
          'balance': account['balance'],
          'sortOrder': account['sortOrder'],
        });
      }
      final budgetFixtures = <Map<String, Object>>[
        {
          'id': 'housing',
          'category': 'Housing',
          'spent': 1200000,
          'limit': 1400000,
          'color': 0xFF6646C2,
        },
        {'id': 'food', 'category': 'Food', 'spent': 420000, 'limit': 600000, 'color': 0xFFFFB74D},
        {
          'id': 'transport',
          'category': 'Transport',
          'spent': 185000,
          'limit': 350000,
          'color': 0xFF1C61D1,
        },
        {
          'id': 'entertainment',
          'category': 'Entertainment',
          'spent': 120000,
          'limit': 250000,
          'color': 0xFF14A765,
        },
      ];
      for (final budget in budgetFixtures) {
        await userRoot.collection('budgets').doc(budget['id']! as String).set({
          'category': budget['category'],
          'spent': budget['spent'],
          'limit': budget['limit'],
          'color': budget['color'],
        });
      }
      final now = DateTime.now();
      final transactionFixtures = <Map<String, Object>>[
        {
          'id': 'coffee',
          'description': 'Coffee shop',
          'category': 'Food',
          'accountId': 'checking',
          'amount': 6500,
          'type': 'expense',
          'date': now,
        },
        {
          'id': 'salary',
          'description': 'Salary',
          'category': 'Income',
          'accountId': 'checking',
          'amount': 3200000,
          'type': 'income',
          'date': now.subtract(const Duration(days: 1)),
        },
        {
          'id': 'rent',
          'description': 'Rent payment',
          'category': 'Housing',
          'accountId': 'checking',
          'amount': 1200000,
          'type': 'expense',
          'date': now.subtract(const Duration(days: 4)),
        },
        {
          'id': 'metro',
          'description': 'Metro card',
          'category': 'Transport',
          'accountId': 'wallet',
          'amount': 45000,
          'type': 'expense',
          'date': now.subtract(const Duration(days: 6)),
          'receiptPath': 'users/$uid/receipts/metro.png',
        },
        {
          'id': 'freelance',
          'description': 'Freelance',
          'category': 'Income',
          'accountId': 'checking',
          'amount': 850000,
          'type': 'income',
          'date': now.subtract(const Duration(days: 8)),
        },
      ];
      for (final transaction in transactionFixtures) {
        await userRoot.collection('cashflow').doc(transaction['id']! as String).set({
          'description': transaction['description'],
          'category': transaction['category'],
          'accountId': transaction['accountId'],
          'amount': transaction['amount'],
          'type': transaction['type'],
          'date': Timestamp.fromDate(transaction['date']! as DateTime),
          if (transaction['receiptPath'] case final String path) 'receiptPath': path,
        });
      }
      await FirebaseStorage.instance
          .ref('users/$uid/receipts/metro.png')
          .putData(_FakeReceiptImagePicker.bytes, SettableMetadata(contentType: 'image/png'));
      await FirebaseAuth.instance.signOut();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            receiptImagePickerProvider.overrideWithValue(
              _FakeReceiptImagePicker(),
            ),
          ],
          child: const PersonalFinanceApp(),
        ),
      );
      await _settle(tester);

      expect(find.byKey(const ValueKey('auth_email_field')), findsOneWidget);

      final signupEmail = 'e2e-signup-${DateTime.now().microsecondsSinceEpoch}@example.test';
      await tester.tap(find.byKey(const ValueKey('auth_signup_tab')));
      await _settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('auth_email_field')),
        signupEmail,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth_password_field')),
        password,
      );
      await _dismissKeyboard(tester);
      await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
      await _settle(tester);

      expect(find.byKey(const ValueKey('dashboard_screen')), findsOneWidget);
      expect(FirebaseAuth.instance.currentUser?.email, signupEmail);
      debugPrint('E2E created account through the sign-up form');

      await tester.tap(find.byKey(const ValueKey('finance_header_action')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('auth_sign_out_button')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('auth_email_field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('auth_email_field')),
        email,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth_password_field')),
        password,
      );
      await _dismissKeyboard(tester);
      await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
      await _settle(tester);

      expect(find.text('Your money, clearly.'), findsOneWidget);
      // Keep stage markers in the device log to make a stalled E2E action diagnosable.
      debugPrint('E2E reached dashboard');
      expect(FirebaseAuth.instance.currentUser?.uid, uid);

      final firestore = FirebaseFirestore.instance;
      final ownProfile = firestore.collection('users').doc(uid);
      await ownProfile.set({'displayName': 'E2E user'});
      final ownSnapshot = await ownProfile.get();
      expect(ownSnapshot.data()?['displayName'], 'E2E user');

      await expectLater(
        firestore.collection('users').doc('another-user').set({'displayName': 'Denied'}),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('finance_nav_activity')));
      await _settle(tester);
      debugPrint('E2E reached activity');
      expect(find.byKey(const ValueKey('activity_screen')), findsOneWidget);
      expect(find.text('Coffee shop'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('activity_account_filter')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('activity_account_savings')));
      await _settle(tester);
      expect(find.text('Coffee shop'), findsNothing);
      expect(find.text('No transactions yet'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('activity_account_filter')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('activity_account_all')));
      await _settle(tester);
      expect(find.text('Coffee shop'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('finance_nav_budgets')));
      await _settle(tester);
      debugPrint('E2E reached budgets');
      expect(find.byKey(const ValueKey('budgets_screen')), findsOneWidget);
      expect(find.text('Housing'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('budget_edit_button')));
      await _settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('budget_limit_field_food')),
        '650000',
      );
      await _dismissKeyboard(tester);
      await tester.tap(find.byKey(const ValueKey('budget_save_button')));
      await _settle(tester);
      final updatedFoodBudget = await firestore
          .collection('users')
          .doc(uid)
          .collection('budgets')
          .doc('food')
          .get();
      expect(updatedFoodBudget.data()?['limit'], 650000);

      await tester.tap(find.byKey(const ValueKey('finance_nav_accounts')));
      await _settle(tester);
      debugPrint('E2E reached accounts');
      expect(find.byKey(const ValueKey('accounts_screen')), findsOneWidget);
      expect(find.text('Main checking'), findsOneWidget);
      expect(find.text('4 active accounts'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('accounts_manage_button')));
      await _settle(tester);
      expect(find.text('Manage accounts'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('account_edit_checking')));
      await _settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('account_edit_name_field')),
        'Primary checking',
      );
      await _dismissKeyboard(tester);
      await tester.tap(find.byKey(const ValueKey('account_update_button')));
      await _settle(tester);
      expect(find.text('Primary checking'), findsOneWidget);
      final renamedAccount = await firestore
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .doc('checking')
          .get();
      expect(renamedAccount.data()?['name'], 'Primary checking');
      await tester.tap(find.byKey(const ValueKey('accounts_manage_button')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('account_delete_wallet')));
      await _settle(tester);
      expect(find.textContaining('permanently deletes its transactions'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('account_confirm_delete_wallet')));
      await _settle(tester);
      final deletedWallet = await firestore
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .doc('wallet')
          .get();
      expect(deletedWallet.exists, isFalse);
      await tester.pump(const Duration(milliseconds: 500));
      await _settle(tester);
      expect(find.text('Cash wallet'), findsNothing);
      expect((await renamedAccount.reference.get()).exists, isTrue);
      final deletedWalletTransactions = await firestore
          .collection('users')
          .doc(uid)
          .collection('cashflow')
          .where('accountId', isEqualTo: 'wallet')
          .get();
      expect(deletedWalletTransactions.docs, isEmpty);
      await expectLater(
        FirebaseStorage.instance.ref('users/$uid/receipts/metro.png').getData(),
        throwsA(isA<FirebaseException>()),
      );

      await tester.tap(find.byKey(const ValueKey('finance_nav_activity')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('activity_add_expense_button')));
      await _settle(tester);
      debugPrint('E2E reached expense form');
      expect(find.byKey(const ValueKey('expense_form_screen')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('expense_amount_field')), '42000');
      await tester.enterText(find.byKey(const ValueKey('expense_description_field')), 'E2E market');
      await _dismissKeyboard(tester);
      await tester.tap(find.byKey(const ValueKey('expense_receipt_button')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('expense_receipt_gallery')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('expense_receipt_preview')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('expense_save_button')));
      await tester.tap(find.byKey(const ValueKey('expense_save_button')));
      await _settle(tester);
      debugPrint('E2E saved expense');
      expect(find.text('E2E market'), findsOneWidget);

      final savedExpense = await firestore
          .collection('users')
          .doc(uid)
          .collection('cashflow')
          .where('description', isEqualTo: 'E2E market')
          .limit(1)
          .get();
      final receiptPath = savedExpense.docs.single.data()['receiptPath'] as String;
      final uploadedReceipt = await FirebaseStorage.instance.ref(receiptPath).getData();
      expect(uploadedReceipt, _FakeReceiptImagePicker.bytes);
      await expectLater(
        FirebaseStorage.instance.ref('users/another-user/receipts/forbidden.png').getData(),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            anyOf('unauthorized', 'permission-denied'),
          ),
        ),
      );

      final accountAfterExpense = await firestore
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .doc('checking')
          .get();
      expect(accountAfterExpense.data()?['balance'], 6378500);
      final foodBudget = await firestore
          .collection('users')
          .doc(uid)
          .collection('budgets')
          .doc('food')
          .get();
      expect(foodBudget.data()?['spent'], 462000);

      await tester.tap(find.byKey(const ValueKey('finance_nav_home')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('finance_header_action')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('auth_sign_out_button')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('auth_email_field')), findsOneWidget);
      expect(FirebaseAuth.instance.currentUser, isNull);

      await tester.tap(find.byKey(const ValueKey('auth_guest_button')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('dashboard_screen')), findsOneWidget);
      expect(FirebaseAuth.instance.currentUser?.isAnonymous, isTrue);

      await tester.tap(find.byKey(const ValueKey('finance_header_action')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('auth_sign_out_button')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('auth_email_field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('auth_email_field')),
        email,
      );
      await _dismissKeyboard(tester);
      await tester.tap(
        find.byKey(const ValueKey('auth_forgot_password_button')),
      );
      await _settle(tester);
      expect(
        find.text(
          'If an account exists for this email, a reset link has been sent.',
        ),
        findsOneWidget,
      );
    },
  );
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 8),
);

Future<void> _dismissKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(tester);
}

class _FakeReceiptImagePicker implements ReceiptImagePicker {
  static final Uint8List bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

  @override
  Future<ReceiptAttachment?> pick(ImageSource source) async => ReceiptAttachment(
    bytes: bytes,
    contentType: 'image/png',
  );
}
