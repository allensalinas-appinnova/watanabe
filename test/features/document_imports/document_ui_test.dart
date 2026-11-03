import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_providers.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_screen.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/widgets/finance_popup_selector.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class ReceiptScreenController extends DocumentImportController {
  @override
  DocumentImportState build() => DocumentImportState(
    loaded: true,
    draft: DocumentDraft(
      file: DocumentFile(
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=',
        ),
        contentType: 'image/png',
      ),
      importId: 'ui-draft',
      generation: 1,
    ),
    session: const DocumentImport(
      id: 'ui-draft',
      generation: 1,
      version: 1,
      phase: DocumentPhase.prepared,
    ),
  );

  @override
  bool belongsTo(String uid, int generation) => uid == 'ui-user' && generation == 1;

  @override
  Future<void> initialize(String uid, int generation) async {}
}

void main() {
  testWidgets('a suggestion arriving after initial loading becomes the selected valid form value', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    final selection = ValueNotifier<String?>(null);
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ValueListenableBuilder<String?>(
            valueListenable: selection,
            builder: (c, value, _) => Form(
              key: form,
              child: FinancePopupSelector<String>(
                key: const ValueKey('selector'),
                title: 'Category',
                initialValue: value,
                options: value == null ? [] : ['food'],
                optionLabel: (s) => s,
                searchText: (s) => s,
                optionBuilder: (c, s) => Text(s),
                onSelected: (_) {},
                validator: (v) => v == null ? 'Choose category' : null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isFalse);
    selection.value = 'food';
    await tester.pumpAndSettle();
    expect(find.text('food'), findsOneWidget);
    expect(form.currentState!.validate(), isTrue);
    selection.value = null;
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isFalse);
  });
  for (final locale in ['es', 'en', 'pt']) {
    testWidgets(
      'document errors are localized and distinguish disk capacity from network loss ($locale)',
      (tester) async {
        String? disk, offline;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (c) {
                final l = AppLocalizations.of(c);
                disk = documentError(l, 'document-draft-unavailable');
                offline = l.documentOffline;
                return Scaffold(body: Text(disk!));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(disk, isNot(offline));
        expect(disk, isNotEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('receipt screen has a friendly primary action and safe replace controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentImportControllerProvider.overrideWith(ReceiptScreenController.new),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'ui-user', isAnonymous: false)),
          ),
          canonicalUserProfileProvider('ui-user').overrideWith(
            (ref) => Stream.value(
              const UserProfile(
                id: 'ui-user',
                locale: 'es',
                countryCode: 'CO',
                timeZone: 'America/Bogota',
                defaultCurrency: 'COP',
                onboardingStatus: 'completed',
                categoryCatalogVersion: 1,
                dataGeneration: 1,
              ),
            ),
          ),
          resourceUsageProvider.overrideWith(
            (ref) async => const UsageSummary(
              dailyUsed: 1,
              monthlyUsed: 3,
              dailyLimit: 5,
              monthlyLimit: 20,
              attachmentBytes: 0,
              attachmentLimit: 100000000,
              temporaryBytes: 0,
              enabled: true,
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DocumentImportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(DocumentImportScreen)));
    expect(find.text(l.documentImportTitle), findsOneWidget);
    expect(find.text(l.documentImportExplanation), findsOneWidget);
    expect(find.byKey(const ValueKey('document_prepare_expense')), findsOneWidget);
    expect(find.text(l.documentPrepareExpense), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('document_import_content')), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('document_change_receipt')), findsOneWidget);
    expect(find.text(l.documentUsageAvailable(4)), findsOneWidget);
    expect(find.textContaining('ui-draft'), findsNothing);
    expect(find.textContaining('Preparando con IA'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
