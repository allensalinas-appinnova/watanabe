import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/domain/entities/home_dashboard_preferences.dart';

void main() {
  test('legacy and malformed profile preferences default widgets and budgets to visible', () {
    for (final value in [null, 'invalid', <String, Object>{}]) {
      final preferences = HomeDashboardPreferences.fromMap(value);
      expect(preferences.visibleWidgets, HomeDashboardWidget.values.map((widget) => widget.id));
      expect(preferences.showsBudget('new-category'), isTrue);
    }
  });

  test('persists individual widget and category choices and ignores unknown widgets', () {
    const preferences = HomeDashboardPreferences(
      visibleWidgets: {'totalBalance', 'recentActivity'},
      hiddenBudgetCategoryIds: {'food'},
    );
    final restored = HomeDashboardPreferences.fromMap(preferences.toMap());

    expect(restored.shows(HomeDashboardWidget.totalBalance), isTrue);
    expect(restored.shows(HomeDashboardWidget.incomeSummary), isFalse);
    expect(restored.shows(HomeDashboardWidget.recentActivity), isTrue);
    expect(restored.showsBudget('food'), isFalse);
    expect(restored.showsBudget('new-category'), isTrue);

    final forwardCompatible = HomeDashboardPreferences.fromMap({
      'widgets': {'totalBalance': false, 'futureWidget': false},
    });
    expect(forwardCompatible.shows(HomeDashboardWidget.totalBalance), isFalse);
    expect(forwardCompatible.shows(HomeDashboardWidget.incomeSummary), isTrue);
  });
}
