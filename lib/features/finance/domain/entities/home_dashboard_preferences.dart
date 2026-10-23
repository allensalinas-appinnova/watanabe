enum HomeDashboardWidget {
  totalBalance('totalBalance'),
  incomeSummary('incomeSummary'),
  expenseSummary('expenseSummary'),
  expenseBudgetRatio('expenseBudgetRatio'),
  incomeBudgetRatio('incomeBudgetRatio'),
  recentActivity('recentActivity'),
  coachNextStep('coachNextStep');

  const HomeDashboardWidget(this.id);
  final String id;
}

class HomeDashboardPreferences {
  const HomeDashboardPreferences({
    this.visibleWidgets = const {
      'totalBalance',
      'incomeSummary',
      'expenseSummary',
      'expenseBudgetRatio',
      'incomeBudgetRatio',
      'recentActivity',
      'coachNextStep',
    },
    this.hiddenBudgetCategoryIds = const {},
  });

  factory HomeDashboardPreferences.fromMap(Object? value) {
    if (value is! Map) return const HomeDashboardPreferences();
    final storedWidgets = value['widgets'];
    final storedHiddenCategories = value['hiddenBudgetCategoryIds'];
    return HomeDashboardPreferences(
      visibleWidgets: storedWidgets is Map
          ? HomeDashboardWidget.values
                .where((widget) => storedWidgets[widget.id] != false)
                .map((widget) => widget.id)
                .toSet()
          : const HomeDashboardPreferences().visibleWidgets,
      hiddenBudgetCategoryIds: storedHiddenCategories is List
          ? storedHiddenCategories.whereType<String>().take(100).toSet()
          : const {},
    );
  }

  final Set<String> visibleWidgets;
  final Set<String> hiddenBudgetCategoryIds;

  bool shows(HomeDashboardWidget widget) => visibleWidgets.contains(widget.id);
  bool showsBudget(String categoryId) => !hiddenBudgetCategoryIds.contains(categoryId);

  HomeDashboardPreferences copyWith({
    Set<String>? visibleWidgets,
    Set<String>? hiddenBudgetCategoryIds,
  }) => HomeDashboardPreferences(
    visibleWidgets: Set.unmodifiable(visibleWidgets ?? this.visibleWidgets),
    hiddenBudgetCategoryIds: Set.unmodifiable(
      hiddenBudgetCategoryIds ?? this.hiddenBudgetCategoryIds,
    ),
  );

  Map<String, Object> toMap() => {
    'widgets': {for (final widget in HomeDashboardWidget.values) widget.id: shows(widget)},
    'hiddenBudgetCategoryIds': hiddenBudgetCategoryIds.toList(growable: false),
  };
}
