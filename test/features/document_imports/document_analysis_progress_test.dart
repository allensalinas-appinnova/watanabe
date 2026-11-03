import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/document_imports/data/document_import_mapper.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';
import 'package:personal_finance/features/document_imports/presentation/document_analysis_progress.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  test('stored reasons are typed, old and unknown values remain safe', () {
    for (final entry in {
      'document-service-busy': DocumentAnalysisIssue.serviceBusy,
      'document-analysis-timeout': DocumentAnalysisIssue.timedOut,
      'document-analysis-failed': DocumentAnalysisIssue.failed,
    }.entries) {
      expect(
        mapDocumentImport('id', {'status': 'failed', 'issue': entry.key}).analysisIssue,
        entry.value,
      );
      expect(
        mapDocumentImport('id', {'status': 'ready', 'issue': entry.key}).analysisIssue,
        isNull,
      );
    }
    expect(mapDocumentImport('id', {'status': 'failed', 'issue': 'unknown'}).analysisIssue, isNull);
  });
  for (final locale in ['es', 'en', 'pt']) {
    for (final brightness in Brightness.values) {
      testWidgets('long wait and safe error labels $locale $brightness', (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late AppLocalizations l;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(brightness: brightness),
            home: Builder(
              builder: (context) {
                l = AppLocalizations.of(context);
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
                  child: const Scaffold(
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: DocumentAnalysisProgress(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        expect(find.text(l.documentAnalyzing), findsOneWidget);
        await tester.pump(const Duration(seconds: 14));
        expect(find.text(l.documentAnalysisTakingLonger), findsNothing);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(l.documentAnalysisTakingLonger), findsOneWidget);
        expect(documentError(l, 'document-service-busy'), l.documentServiceBusy);
        expect(documentError(l, 'document-analysis-timeout'), l.documentAnalysisTimedOut);
        expect(documentError(l, 'document-analysis-failed'), l.documentAnalysisFailed);
        expect(documentError(l, 'document-response-timeout'), l.documentResponseTimedOut);
        expect(documentError(l, 'document-upload-required'), l.documentUploadRequired);
        expect(documentError(l, 'document-source-unavailable'), l.documentSourceUnavailable);
        expect(documentError(l, 'private provider error'), l.documentRetryError);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 30));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
