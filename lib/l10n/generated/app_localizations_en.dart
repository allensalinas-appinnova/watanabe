// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ClearBudget';

  @override
  String get loginTitle => 'Log in';

  @override
  String get createAccount => 'Create account';

  @override
  String get continueAsGuest => 'Continue as guest';

  @override
  String get dashboardTitle => 'Your money, clearly.';

  @override
  String get setupTitle => 'Set up ClearBudget';

  @override
  String get personalizeExperience => 'Personalize your experience';

  @override
  String get language => 'Language';

  @override
  String get country => 'Country';

  @override
  String get baseCurrency => 'Base currency';

  @override
  String get firstAccountName => 'Name of your first account';

  @override
  String get getStarted => 'Get started';

  @override
  String get home => 'Home';

  @override
  String get activity => 'Activity';

  @override
  String get budget => 'Budget';

  @override
  String get accounts => 'Accounts';

  @override
  String get categories => 'Categories';

  @override
  String get income => 'Income';

  @override
  String get expense => 'Expense';

  @override
  String get transfer => 'Transfer';

  @override
  String get addIncome => 'Add income';

  @override
  String get addExpense => 'Add expense';

  @override
  String get transferMoney => 'Transfer money';

  @override
  String get currentBalance => 'Current balance';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get noTransactions => 'You have no transactions yet.';

  @override
  String get amount => 'Amount';

  @override
  String get account => 'Account';

  @override
  String get category => 'Category';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get sourceAccount => 'Source account';

  @override
  String get destinationAccount => 'Destination account';

  @override
  String get optionalNote => 'Optional note';

  @override
  String get confirmTransfer => 'Confirm transfer';

  @override
  String get invalidTransfer =>
      'Choose different accounts with the same currency and a valid amount.';

  @override
  String get completeRequiredFields => 'Complete the amount, account and category.';

  @override
  String budgetTracking(Object month) {
    return 'Budget tracking · $month';
  }

  @override
  String get noBudgetsThisMonth => 'There are no budgets for this month.';

  @override
  String planned(Object amount) {
    return 'Planned $amount';
  }

  @override
  String actual(Object amount) {
    return 'Actual $amount';
  }

  @override
  String remaining(Object amount) {
    return 'Remaining $amount';
  }

  @override
  String exceeded(Object amount) {
    return 'Exceeded $amount';
  }

  @override
  String get createBudget => 'Create budget';

  @override
  String get newBudget => 'New budget';

  @override
  String get budgetItem => 'Item';

  @override
  String get budgetCategory => 'Category';

  @override
  String get budgetSaved => 'Budget saved';

  @override
  String get signOut => 'Sign out';

  @override
  String get sessionExpired => 'Session expired';

  @override
  String loadError(Object message) {
    return 'Could not load: $message';
  }

  @override
  String get retry => 'Retry';

  @override
  String get offlinePending => 'Pending synchronization';

  @override
  String get offlineRejected => 'Could not synchronize. You can retry.';

  @override
  String get syncing => 'Synchronizing...';

  @override
  String get synced => 'Synchronized';

  @override
  String get changeMonth => 'Change month';

  @override
  String get byCategory => 'By category';

  @override
  String get plannedSummary => 'Planned · actual · remaining';

  @override
  String plannedTotal(Object amount) {
    return '$amount planned';
  }

  @override
  String usedSummary(Object currency, Object percent, Object remaining) {
    return '$currency · $percent% used · $remaining remaining';
  }

  @override
  String get unbudgetedMovements => 'Unbudgeted movements';

  @override
  String get reviewCategories => 'Review categories';

  @override
  String get viewBudgetDetails => 'View budget details';
}
