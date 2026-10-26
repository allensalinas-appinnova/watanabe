import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/commitments/presentation/debt_commitments_screen.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'preselects debts and suggests their payment day without replacing manual choices',
    (
      tester,
    ) async {
      final now = DateTime.now();
      final accounts = [
        const FinanceAccount(
          id: 'card',
          name: 'Card',
          type: 'creditCard',
          nature: 'debt',
          paymentDueDay: 5,
          statementClosingDay: 20,
        ),
        const FinanceAccount(id: 'bank', name: 'Bank', type: 'checking'),
        const FinanceAccount(
          id: 'loan',
          name: 'Loan',
          type: 'bankLoan',
          nature: 'debt',
          paymentDueDay: 31,
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(const AuthUser(id: 'test', isAnonymous: true)),
            ),
            canonicalAccountsProvider('test').overrideWith((ref) => Stream.value(accounts)),
            canonicalUserProfileProvider('test').overrideWith(
              (ref) => Stream.value(
                const UserProfile(
                  id: 'test',
                  locale: 'es',
                  countryCode: 'CO',
                  timeZone: 'America/Bogota',
                  defaultCurrency: 'COP',
                  onboardingStatus: 'complete',
                  categoryCatalogVersion: 1,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DebtCommitmentFormScreen(initialDebtAccountId: 'card'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('commitment_debt_card')), findsOneWidget);
      expect(find.text('Día 5'), findsOneWidget);
      expect(find.byKey(const ValueKey('commitment_use_payment_day_suggestion')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('commitment_due_day')));
      await tester.tap(find.byKey(const ValueKey('commitment_due_day')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Día 12'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Día 12'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(
        find.byKey(const ValueKey('commitment_use_payment_day_suggestion')),
      );
      await tester.tap(find.byKey(const ValueKey('commitment_use_payment_day_suggestion')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byKey(const ValueKey('day_of_month_commitment_due_day_1_31_5')),
            )
            .initialValue,
        5,
      );
      expect(DateTime.now().year, now.year);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uses a bank loan usual payment day as a commitment suggestion', (tester) async {
    const loan = FinanceAccount(
      id: 'loan',
      name: 'Loan',
      type: 'bankLoan',
      nature: 'debt',
      paymentDueDay: 31,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'test', isAnonymous: true)),
          ),
          canonicalAccountsProvider('test').overrideWith((ref) => Stream.value(const [loan])),
          canonicalUserProfileProvider('test').overrideWith(
            (ref) => Stream.value(
              const UserProfile(
                id: 'test',
                locale: 'es',
                countryCode: 'CO',
                timeZone: 'America/Bogota',
                defaultCurrency: 'COP',
                onboardingStatus: 'complete',
                categoryCatalogVersion: 1,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DebtCommitmentFormScreen(initialDebtAccountId: 'loan'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Día 31'), findsOneWidget);
    expect(find.textContaining('Día de pago sugerido: 31'), findsOneWidget);
    expect(find.byKey(const ValueKey('commitment_use_payment_day_suggestion')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
