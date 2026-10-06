enum BudgetFlowType { expense, income }

extension BudgetFlowTypeValue on BudgetFlowType {
  String get value => switch (this) {
    BudgetFlowType.expense => 'expense',
    BudgetFlowType.income => 'income',
  };

  static BudgetFlowType fromValue(String? value) =>
      value == 'income' ? BudgetFlowType.income : BudgetFlowType.expense;
}
