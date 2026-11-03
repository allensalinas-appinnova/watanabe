import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/firebase/firebase_observability.dart';
import 'package:personal_finance/core/offline/pending_operation_queue.dart';
import 'package:personal_finance/core/offline/pending_operation_sync_service.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';

class Repository extends Mock implements CanonicalFinanceRepository {}

void main() {
  for (final transfer in [false, true]) {
    test(
      'offline ${transfer ? 'transfer' : 'expense'} retry preserves its generation after reset',
      () async {
        final repository = Repository();
        final database = PendingOperationDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        var generation = 1;
        when(() => repository.watchUserProfile('qa')).thenAnswer(
          (_) => Stream.value(
            UserProfile(
              id: 'qa',
              locale: 'es',
              countryCode: 'CO',
              timeZone: 'America/Bogota',
              defaultCurrency: 'COP',
              onboardingStatus: 'complete',
              categoryCatalogVersion: 1,
              dataGeneration: generation,
            ),
          ),
        );
        final sync = PendingOperationSyncService(
          database,
          Connectivity(),
          connectivityProbe: () async => false,
        )..setSession('qa');
        addTearDown(() => sync.setSession(null));
        final actions = CanonicalFinanceActions(
          repository,
          sync,
          database,
          FirebaseObservability(AppEnvironment.dev, useEmulators: true),
        );
        final date = DateTime.utc(2026, 11, 2);
        Future<void> save() async {
          if (transfer) {
            await actions.createTransfer(
              'qa',
              TransferDraft(
                amountMinor: 100,
                currency: 'COP',
                sourceAccountId: 'bank',
                destinationAccountId: 'cash',
                occurredAt: date,
                description: 'synthetic',
                idempotencyKey: 'original',
              ),
            );
          } else {
            await actions.createOperation(
              'qa',
              FinancialOperationDraft(
                type: OperationType.expense,
                amountMinor: 100,
                currency: 'COP',
                accountId: 'bank',
                occurredAt: date,
                description: 'synthetic',
                idempotencyKey: 'original',
              ),
            );
          }
        }

        await save();
        generation = 2;
        await save();
        final row = await database.findByIdempotencyKey('original', userId: 'qa');
        expect((jsonDecode(row!.payload) as Map<String, dynamic>)['dataGeneration'], 1);
        expect(row.status, 'pending');
        verify(() => repository.watchUserProfile('qa')).called(1);
      },
    );
  }
}
