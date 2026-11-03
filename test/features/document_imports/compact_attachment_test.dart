import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_providers.dart';
import 'package:personal_finance/features/document_imports/presentation/resource_usage_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class AttachmentRepo extends Mock implements DocumentImportRepository {}

void main() {
  for (final language in ['es', 'en', 'pt']) {
    for (final width in [320.0, 430.0]) {
      testWidgets('compact receipt $language $width opens file and separates delete menu', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0, deleted = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
                child: CompactAttachmentRow(
                  contentType: 'application/pdf',
                  size: 200000,
                  onOpen: () => opened++,
                  onDelete: () => deleted++,
                ),
              ),
            ),
          ),
        );
        expect(find.textContaining('PDF'), findsOneWidget);
        expect(find.textContaining(language == 'en' ? '0.2 MB' : '0,2 MB'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(InkWell).first);
        expect(opened, 1);
        expect(deleted, 0);
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuItem<String>));
        await tester.pumpAndSettle();
        expect(deleted, 1);
        expect(opened, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('empty compact attachments reserve no row or empty label', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentAttachmentsProvider((
            uid: 'qa',
            operationId: 'op',
          )).overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AttachmentList(uid: 'qa', operationId: 'op', compact: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CompactAttachmentRow), findsNothing);
    expect(find.byType(Text), findsNothing);
  });
  testWidgets('failure to delete keeps compact receipt and reports an error', (tester) async {
    const attachment = DocumentAttachment(
      id: 'a',
      operationId: 'op',
      size: 1000,
      contentType: 'image/jpeg',
      generation: 1,
    );
    final repo = AttachmentRepo();
    when(
      () => repo.deleteAttachment(attachment),
    ).thenAnswer((_) async => const Left(NetworkFailure('document-network')));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentImportRepositoryProvider.overrideWithValue(repo),
          documentAttachmentsProvider((
            uid: 'qa',
            operationId: 'op',
          )).overrideWith((ref) => Stream.value([attachment])),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AttachmentList(uid: 'qa', operationId: 'op', compact: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuItem<String>));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(AttachmentList)));
    await tester.tap(find.widgetWithText(TextButton, l.documentDelete));
    await tester.pumpAndSettle();
    expect(find.byType(CompactAttachmentRow), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
