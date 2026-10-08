import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/presentation/widgets/finance_components.dart';

void main() {
  testWidgets('operation type selector exposes both centered choices and reports selection', (
    tester,
  ) async {
    var selectedIncome = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FinanceOperationTypeSelector(
              expenseLabel: 'Gastos',
              incomeLabel: 'Ingresos',
              isIncomeSelected: selectedIncome,
              onChanged: (value) => setState(() => selectedIncome = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text('Ingresos'), findsOneWidget);
    final incomeBounds = tester.getRect(find.text('Ingresos'));
    final selectedBounds = tester.getRect(
      find.ancestor(of: find.text('Ingresos'), matching: find.byType(Semantics)).first,
    );
    expect(incomeBounds.center.dx, closeTo(selectedBounds.center.dx, 1));

    await tester.tap(find.text('Gastos'));
    await tester.pump();
    expect(selectedIncome, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('labeled field renders a persistent visible label above its control', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: FinanceLabeledField(
              label: 'Cuenta',
              child: TextField(decoration: InputDecoration()),
            ),
          ),
        ),
      ),
    );

    expect(find.text('CUENTA'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('CUENTA')).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
