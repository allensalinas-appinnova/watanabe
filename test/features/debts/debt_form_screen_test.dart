import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/debts/domain/debt_command.dart';
import 'package:personal_finance/features/debts/domain/debt_repository.dart';
import 'package:personal_finance/features/debts/presentation/debt_form_screen.dart';
import 'package:personal_finance/features/debts/presentation/debt_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class FailingRepository implements DebtRepository {
  final commands = <DebtCommand>[];
  @override
  Future<Either<Failure, DebtCommandResult>> execute(String uid, DebtCommand command) async {
    commands.add(command);
    return const Left(NetworkFailure('debt-connection-required'));
  }
}

Widget subject(
  Locale locale,
  DebtRepository repository, {
  double scale = 1,
  List<FinanceAccount> accounts = const [],
  List<FinanceCategory>? categories,
  String action = 'create',
  String? accountId,
}) => ProviderScope(
  overrides: [
    authSessionProvider.overrideWith(
      (ref) => Stream.value(const AuthUser(id: 'test', isAnonymous: true)),
    ),
    canonicalAccountsProvider('test').overrideWith((ref) => Stream.value(accounts)),
    canonicalRecentOperationsProvider('test').overrideWith((ref) => Stream.value(const [])),
    canonicalCategoriesProvider('test').overrideWith(
      (ref) => Stream.value(
        categories ??
            const [
              FinanceCategory(
                id: 'food',
                type: CategoryType.expense,
                icon: 'category',
                sortOrder: 0,
                isSystem: false,
                isArchived: false,
                customName: 'Food',
              ),
            ],
      ),
    ),
    canonicalUserProfileProvider('test').overrideWith((ref) => Stream.value(null)),
    debtRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: DebtFormScreen(action: action, accountId: accountId),
  ),
);

void main() {
  testWidgets('loan payment refuses an incomplete split without sending or losing its draft', (
    tester,
  ) async {
    final repository = FailingRepository();
    await tester.pumpWidget(
      subject(
        const Locale('es'),
        repository,
        action: 'pay',
        accountId: 'loan',
        accounts: const [
          FinanceAccount(
            id: 'loan',
            name: 'Synthetic loan',
            type: 'bankLoan',
            nature: 'debt',
            currentBalanceMinor: -1100,
            principalMinor: 1000,
            chargesMinor: 100,
          ),
          FinanceAccount(id: 'bank', name: 'Bank', type: 'checking'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('debt_amountMinor')), '450');
    await tester.tap(find.byKey(const ValueKey('debt_bank_COP_tap')));
    await tester.pumpAndSettle();
    expect(find.text('Cuenta de dinero · Bank · COP'), findsOneWidget);
    expect(find.textContaining('Saldo · COP 0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('finance_popup_option_bank')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('debt_newChargesMinor')), '50');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('debt_category_selector_tap')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('debt_category_selector_tap')));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('finance_popup_option_food')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('debt_save')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    tester.testTextInput.hide();
    await tester.ensureVisible(find.byKey(const ValueKey('debt_save')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('debt_save')).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('debt_save')));
    await tester.pumpAndSettle();
    expect(repository.commands, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Completa el desglose'), findsOneWidget);
    // The field can be lazily offscreen; the draft is confirmed when revisited.
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('loan payment suggests interest category only for positive new charges', (
    tester,
  ) async {
    final repository = FailingRepository();
    await tester.pumpWidget(
      subject(
        const Locale('es'),
        repository,
        action: 'pay',
        accountId: 'loan',
        accounts: const [
          FinanceAccount(id: 'loan', name: 'Same name', type: 'bankLoan', nature: 'debt'),
          FinanceAccount(id: 'bank', name: 'Same name', type: 'checking'),
        ],
        categories: const [
          FinanceCategory(
            id: 'food',
            type: CategoryType.expense,
            icon: 'food',
            sortOrder: 0,
            isSystem: false,
            isArchived: false,
            customName: 'Food',
          ),
          FinanceCategory(
            id: 'interest_fees',
            type: CategoryType.expense,
            icon: 'percent',
            sortOrder: 1,
            isSystem: true,
            isArchived: false,
            customName: 'Intereses y comisiones',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('debt_category_selector_tap')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('debt_amountMinor')), '500');
    await tester.enterText(find.byKey(const ValueKey('debt_principalMinor')), '300');
    await tester.enterText(find.byKey(const ValueKey('debt_previousChargesMinor')), '100');
    await tester.enterText(find.byKey(const ValueKey('debt_newChargesMinor')), '100');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('debt_bank_COP_tap')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finance_popup_option_bank')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('debt_category_selector_tap')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Intereses y comisiones'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('debt_save')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    tester.testTextInput.hide();
    await tester.ensureVisible(find.byKey(const ValueKey('debt_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('debt_save')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(repository.commands.single.fields['categoryId'], 'interest_fees');
    expect(repository.commands.single.fields['newChargesMinor'], 100);
  });
  for (final language in ['es', 'en', 'pt']) {
    testWidgets('debt creation has localized controls and fits compact enlarged $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(subject(Locale(language), FailingRepository(), scale: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('debt_name')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('debt_save')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('review, recoverable failure and retry retain the draft and request ID', (
    tester,
  ) async {
    final repository = FailingRepository();
    await tester.pumpWidget(subject(const Locale('es'), repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('debt_name')), 'Synthetic');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('debt_save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('debt_save')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('debt_save')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(repository.commands.length, attempt + 1);
    }
    expect(repository.commands.length, 2);
    expect(repository.commands.first.requestId, repository.commands.last.requestId);
    expect(repository.commands.last.toMap()['name'], 'Synthetic');
    expect(tester.takeException(), isNull);
  });
}
