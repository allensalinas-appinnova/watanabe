enum HomeDashboardWidget {
  totalBalance('totalBalance'),
  incomeSummary('incomeSummary'),
  expenseSummary('expenseSummary'),
  expenseBudgetRatio('expenseBudgetRatio'),
  incomeBudgetRatio('incomeBudgetRatio'),
  recentActivity('recentActivity'),
  coachNextStep('coachNextStep'),
  debtCommitments('debtCommitments'),
  categoryExpenses('categoryExpenses');

  const HomeDashboardWidget(this.id);
  final String id;
}

enum HomeDashboardSection {
  totalBalance('totalBalance'),
  coachAndPlanning('coachAndPlanning'),
  monthlySummary('monthlySummary'),
  categoryExpenses('categoryExpenses'),
  budgets('budgets'),
  recentActivity('recentActivity');

  const HomeDashboardSection(this.id);
  final String id;

  static const defaultOrder = [
    totalBalance,
    coachAndPlanning,
    monthlySummary,
    categoryExpenses,
    budgets,
    recentActivity,
  ];
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
      'debtCommitments',
      'categoryExpenses',
    },
    this.hiddenBudgetCategoryIds = const {},
    this.sectionOrder = HomeDashboardSection.defaultOrder,
  });

  factory HomeDashboardPreferences.fromMap(Object? value) {
    if (value is! Map) return const HomeDashboardPreferences();
    final storedWidgets = value['widgets'];
    final storedHiddenCategories = value['hiddenBudgetCategoryIds'];
    final storedOrder = value['sectionOrder'];
    final parsedOrder = storedOrder is List
        ? storedOrder
              .whereType<String>()
              .map(
                (id) =>
                    HomeDashboardSection.values.where((section) => section.id == id).firstOrNull,
              )
              .whereType<HomeDashboardSection>()
              .toSet()
        : <HomeDashboardSection>{};
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
      sectionOrder: [
        ...parsedOrder,
        ...HomeDashboardSection.defaultOrder.where((section) => !parsedOrder.contains(section)),
      ],
    );
  }

  final Set<String> visibleWidgets;
  final Set<String> hiddenBudgetCategoryIds;
  final List<HomeDashboardSection> sectionOrder;

  bool shows(HomeDashboardWidget widget) => widget == HomeDashboardWidget.coachNextStep
      ? visibleWidgets.contains(widget.id) ||
            visibleWidgets.contains(HomeDashboardWidget.debtCommitments.id)
      : visibleWidgets.contains(widget.id);
  bool showsBudget(String categoryId) => !hiddenBudgetCategoryIds.contains(categoryId);

  HomeDashboardPreferences copyWith({
    Set<String>? visibleWidgets,
    Set<String>? hiddenBudgetCategoryIds,
    List<HomeDashboardSection>? sectionOrder,
  }) => HomeDashboardPreferences(
    visibleWidgets: Set.unmodifiable(visibleWidgets ?? this.visibleWidgets),
    hiddenBudgetCategoryIds: Set.unmodifiable(
      hiddenBudgetCategoryIds ?? this.hiddenBudgetCategoryIds,
    ),
    sectionOrder: List.unmodifiable(sectionOrder ?? this.sectionOrder),
  );

  Map<String, Object> toMap() => {
    'widgets': {for (final widget in HomeDashboardWidget.values) widget.id: shows(widget)},
    'hiddenBudgetCategoryIds': hiddenBudgetCategoryIds.toList(growable: false),
    'sectionOrder': sectionOrder.map((section) => section.id).toList(growable: false),
  };
}
