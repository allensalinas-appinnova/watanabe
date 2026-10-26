import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/theme/app_colors.dart';
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
    expect(FinanceCategoryIcons.canonicalId('movie'), 'entertainment');
    expect(FinanceCategoryIcons.canonicalId('shopping_bag'), 'shopping');
    expect(FinanceCategoryIcons.options, hasLength(30));
    expect(
      FinanceCategoryIcons.groups.values.expand((group) => group).toSet(),
      hasLength(FinanceCategoryIcons.options.length),
    );
    expect(FinanceCategoryIcons.canonicalId('custom-future-icon'), isNull);
    expect(FinanceCategoryIcons.canonicalId(null), isNull);
    expect(
      FinanceCategoryIcons.resolve('custom-future-icon'),
      FinanceCategoryIcons.resolve('other'),
    );
  });

  test('resolves expanded palette colors and falls back for invalid legacy values', () {
    expect(FinanceCategoryColors.resolve(0xFF147D55), const Color(0xFF147D55));
    expect(FinanceCategoryColors.resolve(0xFF174EA6), const Color(0xFF174EA6));
    expect(FinanceCategoryColors.resolve(-1), FinanceCategoryColors.resolve(null));
    expect(FinanceCategoryColors.resolve(0x100000000), FinanceCategoryColors.resolve(null));
    expect(FinanceCategoryColors.background(0x100000000), AppColors.blueSoft);
    expect(FinanceCategoryColors.options.length, 31);
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

  testWidgets('uses the selected color for the icon and its tinted background', (tester) async {
    const selectedColor = 0xFF147D55;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FinanceCategoryIcon(iconId: 'food', colorValue: selectedColor),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(FinanceCategoryIcon),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, FinanceCategoryColors.background(selectedColor));
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
