import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/features/commitments/domain/commitment_repository.dart';
import 'package:personal_finance/features/debts/domain/debt_command.dart';
import 'package:personal_finance/features/debts/domain/debt_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'monthly loan payment can be recorded unallocated and reconciled without double cash effect',
    (tester) async {
      if (!const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
        throw StateError('Firebase Emulator is required for this test');
      }
      const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '10.0.2.2');
      await FirebaseBootstrap.initialize(
        AppEnvironment.dev,
        useEmulators: true,
        emulatorHost: host,
      );
      if (FirebaseBootstrap.app.options.projectId != 'demo-clearbudget') {
        throw StateError('Synthetic Firebase project only');
      }
      await configureDependencies(useEmulators: true);

      final auth = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app);
      await auth.signOut();
      final user = (await auth.signInAnonymously()).user!;
      final db = FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app);
      final root = db.collection('users').doc(user.uid);
      final now = DateTime.now().toUtc();
      final occurredAt = now.toIso8601String();
      final monthKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
      final serverNow = FieldValue.serverTimestamp();

      await root.set({
        'locale': 'es',
        'countryCode': 'CO',
        'timeZone': 'America/Bogota',
        'defaultCurrency': 'COP',
        'onboardingStatus': 'complete',
        'categoryCatalogVersion': 1,
        'dataGeneration': 0,
        'createdAt': serverNow,
        'updatedAt': serverNow,
      });
      await root.collection('accounts').doc('bank').set({
        'name': 'Cuenta sintética',
        'type': 'checking',
        'nature': 'money',
        'currency': 'COP',
        'openingBalanceMinor': 5000000,
        'currentBalanceMinor': 5000000,
        'includeInDashboard': true,
        'status': 'active',
        'dataGeneration': 0,
        'createdAt': serverNow,
        'updatedAt': serverNow,
      });
      await root.collection('categories').doc('interest_fees').set({
        'name': 'Intereses y comisiones',
        'type': 'expense',
        'icon': 'category',
        'sortOrder': 0,
        'isSystem': false,
        'isArchived': false,
        'dataGeneration': 0,
        'createdAt': serverNow,
        'updatedAt': serverNow,
      });

      final debtResult = await getIt<DebtRepository>().execute(
        user.uid,
        DebtCommand(
          requestId: 'e2e_loan_create_001',
          fields: {
            'action': 'create',
            'name': 'Crédito de vehículo',
            'product': 'bankLoan',
            'currency': 'COP',
            'referenceAt': occurredAt,
            'principalMinor': 20000000,
            'chargesMinor': 0,
            'mode': 'existing',
            'paymentDueDay': 31,
          },
        ),
      );
      expect(debtResult.isRight(), isTrue);
      final loanId = debtResult.getRight().toNullable()!.accountId;
      expect((await root.collection('accounts').doc(loanId).get()).data()?['paymentDueDay'], 31);

      final commitmentResult = await getIt<CommitmentRepository>().execute(user.uid, {
        'action': 'create',
        'requestId': 'e2e_commitment_create_001',
        'debtAccountId': loanId,
        'currency': 'COP',
        'amountMinor': 2400000,
        'firstDueMonth': monthKey,
        'dueDay': 31,
        'lastDueMonth': null,
        'bankAccountId': 'bank',
        'remindersEnabled': false,
      });
      expect(commitmentResult.isRight(), isTrue);
      final commitmentId = commitmentResult.getRight().toNullable()!;

      final loanUpdate = await getIt<DebtRepository>().execute(
        user.uid,
        DebtCommand(
          requestId: 'e2e_loan_due_update_001',
          fields: {
            'action': 'update',
            'accountId': loanId,
            'paymentDueDay': 15,
          },
        ),
      );
      expect(loanUpdate.isRight(), isTrue);
      expect(
        (await root.collection('accounts').doc(loanId).get()).data()?['paymentDueDay'],
        15,
      );
      expect(
        (await root.collection('debtCommitments').doc(commitmentId).get()).data()?['dueDay'],
        31,
      );

      final paymentResult = await getIt<DebtRepository>().execute(
        user.uid,
        DebtCommand(
          requestId: 'e2e_unallocated_payment_001',
          fields: {
            'action': 'payUnallocated',
            'accountId': loanId,
            'amountMinor': 2400000,
            'occurredAt': occurredAt,
            'bankAccountId': 'bank',
            'commitmentId': commitmentId,
            'commitmentMonth': monthKey,
            'description': 'Pago mensual sintético',
          },
        ),
      );
      expect(paymentResult.isRight(), isTrue);
      final bankAfterPayment = (await root.collection('accounts').doc('bank').get()).data()!;
      final loanAfterPayment = (await root.collection('accounts').doc(loanId).get()).data()!;
      expect(bankAfterPayment['currentBalanceMinor'], 2600000);
      expect(loanAfterPayment['principalMinor'], 20000000);
      expect(
        (await root.collection('debtPayments').doc('e2e_unallocated_payment_001').get())
            .data()?['status'],
        'unallocated',
      );

      final allocationResult = await getIt<DebtRepository>().execute(
        user.uid,
        DebtCommand(
          requestId: 'e2e_allocate_payment_001',
          fields: {
            'action': 'allocatePayment',
            'accountId': loanId,
            'paymentId': 'e2e_unallocated_payment_001',
            'amountMinor': 2400000,
            'occurredAt': occurredAt,
            'principalMinor': 2000000,
            'previousChargesMinor': 0,
            'newChargesMinor': 400000,
            'categoryId': 'interest_fees',
          },
        ),
      );
      expect(allocationResult.isRight(), isTrue);

      final bankAfterAllocation = (await root.collection('accounts').doc('bank').get()).data()!;
      final loanAfterAllocation = (await root.collection('accounts').doc(loanId).get()).data()!;
      final payment =
          (await root.collection('debtPayments').doc('e2e_unallocated_payment_001').get()).data()!;
      expect(bankAfterAllocation['currentBalanceMinor'], 2600000);
      expect(loanAfterAllocation['principalMinor'], 18000000);
      expect(loanAfterAllocation['chargesMinor'], 0);
      expect(payment['status'], 'allocated');
      expect(payment['principalMinor'], 2000000);
      expect(payment['newChargesMinor'], 400000);
      final summary = (await root.collection('monthlySummaries').doc('${monthKey}_COP').get())
          .data()!;
      expect(summary['expenseMinor'], 400000);
      expect(summary['incomeMinor'], 0);
      final commitment = (await root.collection('debtCommitments').doc(commitmentId).get()).data()!;
      expect(commitment['amountMinor'], 2400000);
      final link =
          (await root.collection('debtPaymentLinks').doc('e2e_unallocated_payment_001').get())
              .data()!;
      expect(link['commitmentId'], commitmentId);
      expect(link['amountMinor'], 2400000);

      final cardResult = await getIt<DebtRepository>().execute(
        user.uid,
        DebtCommand(
          requestId: 'e2e_card_create_001',
          fields: {
            'action': 'create',
            'name': 'Tarjeta sintética',
            'product': 'creditCard',
            'currency': 'COP',
            'referenceAt': occurredAt,
            'debtMinor': 0,
            'mode': 'existing',
            'lastFour': '4321',
            'limitMinor': 5000000,
          },
        ),
      );
      expect(cardResult.isRight(), isTrue);
      final cardId = cardResult.getRight().toNullable()!.accountId;
      final cardCommitmentId = (await getIt<CommitmentRepository>().execute(user.uid, {
        'action': 'create',
        'requestId': 'e2e_card_plan_001',
        'debtAccountId': cardId,
        'currency': 'COP',
        'amountMinor': 300000,
        'firstDueMonth': monthKey,
        'dueDay': 5,
        'remindersEnabled': false,
      })).getRight().toNullable()!;
      final cardUpdate = await getIt<DebtRepository>().execute(
        user.uid,
        DebtCommand(
          requestId: 'e2e_card_update_001',
          fields: {
            'action': 'update',
            'accountId': cardId,
            'name': 'Tarjeta sintética',
            'statementClosingDay': 25,
            'paymentDueDay': 10,
          },
        ),
      );
      expect(cardUpdate.isRight(), isTrue);
      final card = (await root.collection('accounts').doc(cardId).get()).data()!;
      final cardPlan = (await root.collection('debtCommitments').doc(cardCommitmentId).get())
          .data()!;
      expect(card['statementClosingDay'], 25);
      expect(card['paymentDueDay'], 10);
      expect(card['lastFour'], '4321');
      expect(card['limitMinor'], 5000000);
      expect(cardPlan['dueDay'], 5);
    },
  );
}
