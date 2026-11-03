import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_providers.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_screen.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/models/movement_save_result.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class NavigationController extends DocumentImportController {
  DocumentImportState initial = readyState();
  int reloads = 0;
  String? get draftId => state.draft?.importId;
  @override
  DocumentImportState build() => initial;
  @override
  bool belongsTo(String uid, int generation) => uid == 'qa' && generation == 0;
  @override
  Future<void> initialize(String uid, int generation) async {}
  @override
  Future<void> reload(String uid, int generation) async {
    reloads++;
    state = const DocumentImportState(loaded: true);
  }

  void ready() => state = readyState();
}

DocumentImportState readyState() => DocumentImportState(
  loaded: true,
  draft: DocumentDraft(
    file: DocumentFile(
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=',
      ),
      contentType: 'image/png',
    ),
    importId: 'synthetic',
    generation: 0,
  ),
  session: const DocumentImport(
    id: 'synthetic',
    generation: 0,
    version: 1,
    phase: DocumentPhase.ready,
  ),
);

final saved = MovementSaveResult(
  type: OperationType.expense,
  status: MovementSaveStatus.confirmed,
  amountMinor: 25000,
  currency: 'COP',
  idempotencyKey: 'doc_synthetic',
  occurredAt: DateTime(2026, 11, 2),
);

void main() {
  for (final origin in ['/home', '/activity?type=expense', '/accounts/bank']) {
    testWidgets('successful review returns directly to $origin and propagates receipt', (
      tester,
    ) async {
      final controller = NavigationController();
      final router = await pumpFlow(tester, controller, origin: origin);
      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();
      expect(find.text('Review form'), findsOneWidget);
      expect(find.byKey(const ValueKey('document_review')), findsNothing);
      await tester.tap(find.text('Save confirmed'));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.toString(), origin);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(DocumentImportScreen), findsNothing);
      expect(controller.reloads, 1);
    });
  }
  testWidgets('back preserves the draft without an automatic review loop; reopen is explicit', (
    tester,
  ) async {
    final controller = NavigationController();
    await pumpFlow(tester, controller);
    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to receipt'));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentImportScreen), findsOneWidget);
    expect(controller.draftId, 'synthetic');
    final review = find.byKey(const ValueKey('document_review'));
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(find.text('Review form'), findsOneWidget);
    expect(controller.reloads, 0);
  });
  testWidgets('analysis completion opens review once; waiting does not navigate', (tester) async {
    final controller = NavigationController()..initial = const DocumentImportState(loaded: true);
    await pumpFlow(tester, controller);
    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();
    expect(find.text('Review form'), findsNothing);
    controller.ready();
    await tester.pumpAndSettle();
    expect(find.text('Review form'), findsOneWidget);
  });
  for (final direct in [false, true]) {
    testWidgets('shared or direct entry finishes at Home (direct=$direct)', (tester) async {
      final controller = NavigationController();
      final router = await pumpFlow(
        tester,
        controller,
        origin: '/activity?type=income',
        returnHome: !direct,
        direct: direct,
      );
      if (!direct) await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save confirmed'));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
      expect(find.byType(DocumentImportScreen), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(router.canPop(), false);
    });
  }
}

Future<GoRouter> pumpFlow(
  WidgetTester tester,
  NavigationController controller, {
  String origin = '/home',
  bool returnHome = false,
  bool direct = false,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  MovementSaveResult? receipt;
  final router = GoRouter(
    initialLocation: direct ? '/document-imports/new' : origin,
    routes: [
      for (final path in ['/home', '/activity', '/accounts/bank'])
        GoRoute(
          path: path,
          builder: (c, _) => Scaffold(
            body: StatefulBuilder(
              builder: (c, update) => Column(
                children: [
                  Text(path),
                  if (receipt != null) const Text('Saved receipt'),
                  TextButton(
                    onPressed: () async {
                      final result = await c.push<MovementSaveResult>('/document-imports/new');
                      if (c.mounted) update(() => receipt = result);
                    },
                    child: const Text('Launch'),
                  ),
                ],
              ),
            ),
          ),
        ),
      GoRoute(
        path: '/document-imports/new',
        builder: (_, _) =>
            DocumentImportScreen(returnHome: returnHome, returnLocation: direct ? null : origin),
      ),
      GoRoute(
        path: '/document-imports/:id/review',
        builder: (c, route) => Scaffold(
          body: Column(
            children: [
              const Text('Review form'),
              TextButton(
                onPressed: () {
                  final navigation = route.extra as DocumentReviewNavigation?;
                  if (navigation != null) {
                    unawaited(navigation.onSaved(saved));
                  } else {
                    c.pop(saved);
                  }
                },
                child: const Text('Save confirmed'),
              ),
              TextButton(onPressed: () => c.pop(), child: const Text('Back to receipt')),
            ],
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        documentImportControllerProvider.overrideWith(() => controller),
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'qa', isAnonymous: false)),
        ),
        canonicalUserProfileProvider('qa').overrideWith(
          (ref) => Stream.value(
            const UserProfile(
              id: 'qa',
              locale: 'en',
              countryCode: 'CO',
              timeZone: 'America/Bogota',
              defaultCurrency: 'COP',
              onboardingStatus: 'completed',
              categoryCatalogVersion: 1,
            ),
          ),
        ),
        resourceUsageProvider.overrideWith(
          (ref) async => const UsageSummary(
            dailyUsed: 0,
            monthlyUsed: 0,
            dailyLimit: 5,
            monthlyLimit: 20,
            attachmentBytes: 0,
            attachmentLimit: 100000000,
            temporaryBytes: 0,
            enabled: true,
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
