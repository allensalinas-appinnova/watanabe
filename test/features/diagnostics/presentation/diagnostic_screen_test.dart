import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/diagnostics/domain/diagnostic_engine.dart';
import 'package:personal_finance/features/diagnostics/domain/diagnostic_record.dart';
import 'package:personal_finance/features/diagnostics/domain/diagnostic_repository.dart';
import 'package:personal_finance/features/diagnostics/presentation/diagnostic_editor.dart';
import 'package:personal_finance/features/diagnostics/presentation/diagnostic_providers.dart';
import 'package:personal_finance/features/diagnostics/presentation/diagnostic_screen.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class MemoryDiagnostics implements DiagnosticRepository {
  DiagnosticRecord? saved;
  bool fail = false;
  @override
  Stream<DiagnosticSnapshot> watch(String uid, DateTime today, DateTime start) =>
      Stream.value(snapshot());
  @override
  Future<Either<Failure, int>> save(
    String uid,
    DiagnosticRecord record, {
    required int generation,
    required int revision,
    required String requestId,
    bool delete = false,
  }) async {
    if (fail) return const Left(NetworkFailure('offline'));
    saved = record;
    return const Right(1);
  }
}

DiagnosticSnapshot snapshot() => DiagnosticSnapshot(
  DiagnosticInput(
    today: DateTime(2026, 10, 29),
    accounts: const [
      FinanceAccount(id: 'bank', name: 'Bank', type: 'bank', currentBalanceMinor: 1000),
    ],
    operations: const [],
    entries: const [],
    plan: const [],
    records: const [],
  ),
  const {},
);
Future<void> pump(
  WidgetTester tester,
  Widget screen, {
  String language = 'es',
  MemoryDiagnostics? repository,
  bool failure = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'test', isAnonymous: false)),
        ),
        canonicalUserProfileProvider.overrideWith(
          (ref, uid) => Stream.value(
            UserProfile(
              id: uid,
              locale: language,
              countryCode: 'CO',
              timeZone: 'America/Bogota',
              defaultCurrency: 'COP',
              onboardingStatus: 'complete',
              categoryCatalogVersion: 3,
            ),
          ),
        ),
        canonicalCategoriesProvider.overrideWith((ref, uid) => Stream.value(const [])),
        diagnosticSnapshotProvider.overrideWith(
          (ref, uid) => failure ? Stream.error(StateError('offline')) : Stream.value(snapshot()),
        ),
        diagnosticRepositoryProvider.overrideWithValue(repository ?? MemoryDiagnostics()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['es', 'en', 'pt']) {
    testWidgets('diagnosis, missing data and privacy render in $language', (tester) async {
      await pump(tester, const DiagnosticScreen(), language: language);
      final t = AppLocalizations.of(tester.element(find.byType(Scaffold).first)).diagnosticText;
      expect(find.text(t('title')), findsOneWidget);
      expect(find.byKey(const ValueKey('diagnostic_setup')), findsOneWidget);
      await tester.scrollUntilVisible(find.text(t('emergencyCoverage')), 200);
      expect(find.textContaining(t('notCalculable')), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('error exposes retry instead of an empty healthy report', (tester) async {
    await pump(tester, const DiagnosticScreen(), failure: true);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byKey(const ValueKey('diagnostic_setup')), findsNothing);
  });
  testWidgets('context saves a section and preserves draft on network failure', (tester) async {
    final repository = MemoryDiagnostics()..fail = true;
    await pump(tester, const DiagnosticSetupScreen(), repository: repository);
    await tester.tap(find.byKey(const ValueKey('diagnostic_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('diagnostic_dependents')), '2');
    await tester.ensureVisible(find.byKey(const ValueKey('diagnostic_save')));
    await tester.tap(find.byKey(const ValueKey('diagnostic_save')));
    await tester.pumpAndSettle();
    expect(repository.saved, isNull);
    repository.fail = false;
    await tester.tap(find.byKey(const ValueKey('diagnostic_save')));
    await tester.pumpAndSettle();
    expect(repository.saved?.number('dependents'), 2);
    expect(find.byType(DiagnosticSetupScreen), findsOneWidget);
  });
  testWidgets('compact screen and enlarged Portuguese text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.7;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, const DiagnosticScreen(), language: 'pt');
    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
