import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/presentation/widgets/finance_category_icon.dart';

void main() {
  test('resolves stable identifiers and catalog aliases', () {
    expect(FinanceCategoryIcons.canonicalId('food'), 'food');
    expect(FinanceCategoryIcons.canonicalId('restaurant'), 'food');
    expect(FinanceCategoryIcons.canonicalId('home'), 'housing');
    expect(FinanceCategoryIcons.canonicalId('directions_car'), 'transport');
    expect(FinanceCategoryIcons.canonicalId('medical_services'), 'health');
    expect(FinanceCategoryIcons.canonicalId('school'), 'education');
    expect(FinanceCategoryIcons.canonicalId('payments'), 'salary');
    expect(FinanceCategoryIcons.canonicalId('more_horiz'), 'other');
    expect(FinanceCategoryIcons.canonicalId('custom-future-icon'), isNull);
    expect(FinanceCategoryIcons.canonicalId(null), isNull);
    expect(
      FinanceCategoryIcons.resolve('custom-future-icon'),
      FinanceCategoryIcons.resolve('other'),
    );
  });

  testWidgets('shows a category icon in its soft-blue container and keeps label semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              FinanceCategoryIcon(iconId: 'restaurant', semanticLabel: 'Comida'),
              Text('Comida'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Comida'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.getSemantics(find.byType(FinanceCategoryIcon)).label, 'Comida');
    expect(tester.takeException(), isNull);
  });
}
