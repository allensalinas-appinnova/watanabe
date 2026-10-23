import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/money_account_detail_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('shows account balance and distinct expense, income and transfer actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
          ),
          canonicalAccountProvider.overrideWith(
            (ref, key) => Stream.value(
              const FinanceAccount(
                id: 'cash',
                name: 'Cash',
                type: 'cash',
                currency: 'COP',
                currentBalanceMinor: 125000,
              ),
            ),
          ),
          canonicalOperationsPageProvider.overrideWith(
            (ref, request) async => const OperationPage(items: []),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MoneyAccountDetailScreen(accountId: 'cash'),
        ),
      ),
    );
    await _pumpProviders(tester);

    expect(find.text('Detalle de cuenta'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.textContaining('125'), findsOneWidget);
    expect(find.text('Agregar gasto'), findsOneWidget);
    expect(find.text('Agregar ingreso'), findsOneWidget);
    expect(find.text('Mover dinero'), findsOneWidget);
    expect(find.text('Aún no tienes movimientos.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders recent movements with a localized date and signed amount', (tester) async {
    final operation = FinancialOperation(
      id: 'expense-1',
      type: OperationType.expense,
      amountMinor: 3500,
      currency: 'COP',
      monthKey: '2026-10',
      occurredAt: DateTime(2026, 10, 21, 12),
      status: OperationStatus.confirmed,
      idempotencyKey: 'expense-key',
      description: 'Lunch',
      accountId: 'cash',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
          ),
          canonicalAccountProvider.overrideWith(
            (ref, key) => Stream.value(
              const FinanceAccount(id: 'cash', name: 'Cash', type: 'cash', currency: 'COP'),
            ),
          ),
          canonicalOperationsPageProvider.overrideWith(
            (ref, request) async => OperationPage(items: [operation]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MoneyAccountDetailScreen(accountId: 'cash'),
        ),
      ),
    );
    await _pumpProviders(tester);

    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('−COP 3,500'), findsOneWidget);
    expect(find.textContaining('Oct 21, 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpProviders(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
