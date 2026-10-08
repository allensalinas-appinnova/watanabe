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
  String get personalizeExperience => 'Set up your space';

  @override
  String get onboardingSubtitle => 'Choose your preferences. You can change them later.';

  @override
  String get language => 'Language';

  @override
  String get country => 'Country';

  @override
  String get baseCurrency => 'Base currency';

  @override
  String get firstAccountName => 'Name of your first account';

  @override
  String get continueAction => 'Continue';

  @override
  String get home => 'Home';

  @override
  String get activity => 'Activity';

  @override
  String get budget => 'Budget';

  @override
  String get accounts => 'Accounts';

  @override
  String get addMovement => 'Add transaction';

  @override
  String get genericError => 'Something went wrong. Please try again.';

  @override
  String get createFirstAccount => 'Create your first account to get started.';

  @override
  String get plannedAmountLabel => 'Planned total';

  @override
  String get timeZone => 'Time zone';

  @override
  String get timeZoneBogota => 'Bogotá (UTC−5)';

  @override
  String get timeZoneMexicoCity => 'Mexico City (UTC−6)';

  @override
  String get timeZoneSaoPaulo => 'São Paulo (UTC−3)';

  @override
  String get createCategory => 'Create category';

  @override
  String get newCategory => 'New category';

  @override
  String get archive => 'Archive';

  @override
  String get confirmArchiveCategory =>
      'This category will be archived and kept on your past transactions.';

  @override
  String get expenseCategories => 'Expenses';

  @override
  String get incomeCategories => 'Income';

  @override
  String get systemCategory => 'Default';

  @override
  String get customCategory => 'Custom';

  @override
  String get noCategories => 'You don\'t have categories for this type yet.';

  @override
  String get categoryType => 'Category type';

  @override
  String get newAccount => 'New account';

  @override
  String get accountName => 'Account name';

  @override
  String get initialBalance => 'Starting balance';

  @override
  String get editAccount => 'Edit account';

  @override
  String get confirmArchiveAccount =>
      'The account will be archived. Your history and balance will be kept.';

  @override
  String get deleteOperation => 'Delete transaction';

  @override
  String get confirmDeleteOperation =>
      'This transaction will be removed from your activity and the balance recalculated.';

  @override
  String get editOperation => 'Edit transaction';

  @override
  String get savedPending => 'Saved on this device. It will sync when your connection returns.';

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
  String get type => 'Type';

  @override
  String get date => 'Date';

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
  String get reviewTransfer => 'Review transfer';

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
