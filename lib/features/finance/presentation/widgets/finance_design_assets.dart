abstract final class FinanceDesignAssets {
  static const headerAction = 'assets/icons/clearbudget_header_action.svg';

  static String activity({required String category, required bool isIncome}) {
    if (isIncome) return 'assets/icons/activity_income.svg';
    return switch (category.toLowerCase()) {
      'housing' => 'assets/icons/activity_housing.svg',
      'transport' => 'assets/icons/activity_transport.svg',
      'food' => 'assets/icons/activity_coffee.svg',
      _ => 'assets/icons/activity_freelance.svg',
    };
  }

  static String dashboardActivity({required String category, required bool isIncome}) {
    if (isIncome) return 'assets/icons/dashboard_activity_income.svg';
    return switch (category.toLowerCase()) {
      'housing' => 'assets/icons/dashboard_activity_housing.svg',
      _ => 'assets/icons/dashboard_activity_coffee.svg',
    };
  }

  static String budget(String category) => switch (category.toLowerCase()) {
    'housing' => 'assets/icons/budget_housing.svg',
    'food' => 'assets/icons/budget_food.svg',
    'transport' => 'assets/icons/budget_transport.svg',
    'entertainment' => 'assets/icons/budget_entertainment.svg',
    _ => 'assets/icons/budget_other.svg',
  };

  static String account(String type) => switch (type.toLowerCase()) {
    'checking' => 'assets/icons/account_checking.svg',
    'savings' => 'assets/icons/account_savings.svg',
    'wallet' => 'assets/icons/account_wallet.svg',
    'credit card' => 'assets/icons/account_credit.svg',
    _ => 'assets/icons/account_other.svg',
  };

  static String glyph(String category, {required bool isIncome}) {
    if (isIncome) return '↗';
    return switch (category.toLowerCase()) {
      'housing' => '◇',
      'transport' => '▣',
      'food' => '☕',
      'entertainment' => '✦',
      _ => '•',
    };
  }
}
