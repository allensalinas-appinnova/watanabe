import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/finance/domain/entities/activity_report.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/presentation/widgets/activity_export_review_sheet.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  final report = ActivityReport.fromOperations([
    _operation(id: 'expense', description: 'Mercado', status: OperationStatus.confirmed),
    _operation(id: 'pending', description: 'Taxi pendiente', status: OperationStatus.pending),
    _operation(
      id: 'transfer',
      description: 'Mover dinero',
      type: OperationType.transfer,
      status: OperationStatus.confirmed,
    ),
  ]);

  testWidgets('excludes pending by default and allows explicit inclusion', (tester) async {
    final exported = <({ActivityExportAction action, List<FinancialOperation> operations})>[];
    await tester.pumpWidget(
      _subject(
        report: report,
        onExport: ({required operations, required action}) async {
          exported.add((action: action, operations: operations));
          return false; // Save dialog cancellation keeps the review open.
        },
      ),
    );

    expect(find.text('2 movimientos confirmados'), findsOneWidget);
    expect(find.textContaining('1 movimiento pendiente excluido'), findsOneWidget);
    expect(find.text('Taxi pendiente'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('activity_export_save')));
    await tester.tap(find.byKey(const ValueKey('activity_export_save')));
    await tester.pumpAndSettle();
    expect(exported.single.operations.map((operation) => operation.id), ['expense', 'transfer']);
    expect(exported.single.action, ActivityExportAction.save);
    expect(find.text('Exportar CSV'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('activity_export_include_pending')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Taxi pendiente'), findsOneWidget);
    expect(find.textContaining('se incluirá e identificará como pendiente'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('activity_export_share')));
    await tester.tap(find.byKey(const ValueKey('activity_export_share')));
    await tester.pumpAndSettle();
    expect(exported.last.operations.map((operation) => operation.id), [
      'expense',
      'pending',
      'transfer',
    ]);
    expect(exported.last.action, ActivityExportAction.share);
  });

  testWidgets('shows recoverable error and preserves pending selection for retry', (tester) async {
    var attempts = 0;
    var retryIds = <String>[];
    await tester.pumpWidget(
      _subject(
        report: report,
        onExport: ({required operations, required action}) async {
          attempts++;
          retryIds = operations.map((operation) => operation.id).toList();
          if (attempts == 1) throw StateError('private implementation detail');
          return true;
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('activity_export_include_pending')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('activity_export_save')));
    await tester.tap(find.byKey(const ValueKey('activity_export_save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity_export_error')), findsOneWidget);
    expect(find.text('private implementation detail'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('activity_export_retry')));
    await tester.tap(find.byKey(const ValueKey('activity_export_retry')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(retryIds, ['expense', 'pending', 'transfer']);
    expect(find.text('Exportar CSV'), findsNothing);
  });

  testWidgets('disables export actions for an empty filtered result', (tester) async {
    await tester.pumpWidget(
      _subject(
        report: ActivityReport.fromOperations(const []),
        onExport: ({required operations, required action}) async => true,
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const ValueKey('activity_export_save'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(const ValueKey('activity_export_share'))).onPressed,
      isNull,
    );
  });

  testWidgets('fits compact width and enlarged text in all supported locales', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final locale in const [Locale('es'), Locale('pt'), Locale('en')]) {
      await tester.pumpWidget(
        _subject(
          report: report,
          locale: locale,
          onExport: ({required operations, required action}) async => false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity_export_details')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

Widget _subject({
  required ActivityReport report,
  required ActivityExportCallback onExport,
  Locale locale = const Locale('es'),
}) => MaterialApp(
  theme: AppTheme.light,
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: ActivityExportReviewSheet(
      report: report,
      accountLabel: 'Todas las cuentas',
      periodLabel: '1–31 oct 2026',
      typeLabel: 'Todos',
      accounts: const [],
      categories: const [],
      locale: locale.toString(),
      onExport: onExport,
    ),
  ),
);

FinancialOperation _operation({
  required String id,
  required String description,
  OperationType type = OperationType.expense,
  required OperationStatus status,
}) => FinancialOperation(
  id: id,
  type: type,
  amountMinor: 12345,
  currency: 'COP',
  monthKey: '2026-10',
  occurredAt: DateTime(2026, 10, 20, 18, 45),
  status: status,
  idempotencyKey: id,
  description: description,
);
