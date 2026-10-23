// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get debtTitle => 'Cards and loans';

  @override
  String get debtAdd => 'Add card or loan';

  @override
  String get debtMoney => 'Available money';

  @override
  String get debtCards => 'Credit cards';

  @override
  String get debtLoans => 'Loans';

  @override
  String get debtProduct => 'Product';

  @override
  String get debtCreditCard => 'Credit card';

  @override
  String get debtBankLoan => 'Bank loan';

  @override
  String get debtPersonalLoan => 'Personal loan received';

  @override
  String get debtRegistered => 'Recorded debt';

  @override
  String get debtCreditBalance => 'Card credit balance';

  @override
  String get debtPosition => 'Net recorded position';

  @override
  String get debtPositionNote => 'Selected records only; not your complete net worth.';

  @override
  String get debtOpeningMode => 'Opening balance source';

  @override
  String get debtExisting => 'Existing debt (no money movement)';

  @override
  String get debtReceived => 'Loan received now';

  @override
  String get debtReferenceDate => 'Opening balance date';

  @override
  String get debtPrincipal => 'Outstanding principal';

  @override
  String get debtCharges => 'Accrued unpaid charges';

  @override
  String get debtLimit => 'Credit limit (optional)';

  @override
  String get debtCreditor => 'Creditor (optional)';

  @override
  String get debtLastFour => 'Last 4 digits (optional)';

  @override
  String get debtPay => 'Record payment';

  @override
  String get debtPayCard => 'Pay card';

  @override
  String get debtDisburse => 'Record disbursement';

  @override
  String get debtCharge => 'Record charge';

  @override
  String get debtRefund => 'Expense refund';

  @override
  String get debtAdjust => 'Adjust debt';

  @override
  String get debtPurchase => 'Card purchase';

  @override
  String get debtPreviousCharges => 'Previously recorded charges paid';

  @override
  String get debtNewCharges => 'New charges paid now';

  @override
  String get debtOriginalPurchase => 'Original purchase';

  @override
  String get debtBank => 'Money account';

  @override
  String get debtReview => 'Review before confirming';

  @override
  String get debtOnline => 'Connection required. Your draft is kept if saving fails.';

  @override
  String get debtDisabled => 'Debt commands are not enabled on the server yet.';

  @override
  String get debtErrorSplit =>
      'Complete the breakdown: principal, recorded and new charges must equal the payment.';

  @override
  String get debtErrorComponents =>
      'This would leave negative principal or charges. Review the breakdown and subsequent movements.';

  @override
  String get debtErrorRefund => 'Check the original purchase and remaining refundable amount.';

  @override
  String get debtErrorDate => 'The date cannot precede the opening balance.';

  @override
  String get debtErrorArchive => 'Only an obligation with a zero balance can be archived.';

  @override
  String get debtErrorReference => 'Review the selected account, currency, category and budget.';

  @override
  String get debtOverLimit => 'Debt exceeds the recorded limit. The movement was saved.';

  @override
  String get debtReverse => 'Void with reversal';

  @override
  String get debtComponents => 'Linked components';

  @override
  String get debtCommand => 'Command';

  @override
  String get debtReversal => 'Reversal';

  @override
  String get budgetConnectionRequired =>
      'A connection is required to save this budget. Your changes are still here; try again.';

  @override
  String get budgetCommandArchived => 'This budget or item has been archived. Refresh the list.';

  @override
  String get budgetCommandNotFound =>
      'This budget or item is no longer available. Refresh the list.';

  @override
  String get budgetCommandConflict =>
      'The request conflicts with an earlier change. Refresh the budget before trying again.';

  @override
  String get appTitle => 'LumioMoney';

  @override
  String get sessionCheckFailed =>
      'We couldn\'t verify your profile. Check your connection and try again, or sign in again.';

  @override
  String get sessionSignOut => 'Sign out and return to login';

  @override
  String get loginTitle => 'Log in';

  @override
  String get createAccount => 'Create account';

  @override
  String get continueAsGuest => 'Continue as guest';

  @override
  String get authLoginTab => 'Log in';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authEmailInvalid => 'Enter a valid email address.';

  @override
  String get authPasswordTooShort => 'Use at least 8 characters.';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authResetEmailInvalid => 'Enter a valid email address to reset your password.';

  @override
  String get authPasswordResetSent =>
      'If an account exists for this email, a reset link has been sent.';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authOrContinueWith => 'or continue with';

  @override
  String get authPrivacyNote => 'Your data is private and encrypted.';

  @override
  String get authActionFailed => 'We couldn\'t complete that. Check your details and try again.';

  @override
  String get authNetworkError => 'No connection. Check your internet and try again.';

  @override
  String get authTagline => 'Clarity for every peso.';

  @override
  String get hideBalances => 'Hide amounts';

  @override
  String get showBalances => 'Show amounts';

  @override
  String get hiddenAmount => 'Hidden amount';

  @override
  String get moreOptions => 'More options';

  @override
  String get dashboardTitle => 'Your money, clearly.';

  @override
  String get homeMenu => 'More options';

  @override
  String get homeTotalBalance => 'Total balance';

  @override
  String get homeBudgetTitle => 'Monthly budget';

  @override
  String get homeExpenseVsBudget => 'Expense vs. budget';

  @override
  String get homeIncomeVsBudget => 'Income vs. budget';

  @override
  String homeBudgetComparisonDetails(Object actual, Object planned) {
    return 'Actual · $actual / Plan · $planned';
  }

  @override
  String get homeNoBudgetForFlow => 'No budget this month';

  @override
  String homeMonthlySummary(Object month, Object currency) {
    return '$month summary · $currency';
  }

  @override
  String get seeAll => 'See all';

  @override
  String get setupTitle => 'Set up LumioMoney';

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
  String get activitySubtitle => 'Find and review your transactions';

  @override
  String get activityFilterAll => 'All';

  @override
  String get activityFilterTransfers => 'Transfers';

  @override
  String get activityBalanceAdjustmentsFilter => 'Adjustments';

  @override
  String get activityBalanceAdjustmentType => 'Balance adjustment';

  @override
  String activityBalanceAdjustmentEntry(Object previous, Object target, Object difference) {
    return 'Balance $previous → $target · difference $difference';
  }

  @override
  String get activityBalanceAdjustmentsHeader => 'Balance adjustments';

  @override
  String get activityBalanceAdjustmentsEmpty => 'There are no adjustments for these filters.';

  @override
  String activityFilterAction(Object account, Object period) {
    return 'Filters · $account · $period';
  }

  @override
  String get activityFilterTitle => 'Filter activity';

  @override
  String get activityFilterAccount => 'ACCOUNT';

  @override
  String get activityFilterAllAccounts => 'All accounts';

  @override
  String get activityFilterPeriod => 'PERIOD';

  @override
  String get activityFilterMonth => 'Month';

  @override
  String get activityFilterDateRange => 'Date range';

  @override
  String get activityFilterSelectAccount => 'Choose accounts';

  @override
  String get activityFilterMultiSelectHint =>
      'Choose up to 10 accounts. Transfers appear when either account is selected.';

  @override
  String get activityFilterDone => 'Done';

  @override
  String activityFilterSelectedAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '$count account',
    );
    return '$_temp0';
  }

  @override
  String get activityFilterSelectMonth => 'Choose month';

  @override
  String get activityFilterStartDate => 'FROM';

  @override
  String get activityFilterEndDate => 'TO';

  @override
  String get activityFilterTimezoneHint => 'The month follows your time zone.';

  @override
  String activityFilterRangeHint(Object month) {
    return 'Choose dates within $month.';
  }

  @override
  String get activityFilterApply => 'Apply filters';

  @override
  String get activityFilterReset => 'Reset';

  @override
  String activityFilterUseMonth(Object month) {
    return 'Use $month';
  }

  @override
  String get activityFilterUseDate => 'Use date';

  @override
  String get activityFilterAllDates => 'All dates';

  @override
  String activityFilterSelectedDetails(Object account, Object range) {
    return '$account · $range';
  }

  @override
  String get activityShare => 'Share';

  @override
  String get activityShareSubject => 'LumioMoney activity';

  @override
  String get activityShareFailed => 'Couldn\'t prepare or share the file. Please try again.';

  @override
  String get activityShareEmpty => 'There are no transactions to share.';

  @override
  String get activityMovements => 'Movements';

  @override
  String activityMovementCount(int count) {
    return 'Movements · $count';
  }

  @override
  String get activityExportAction => 'Export';

  @override
  String get activityExportTitle => 'Export CSV';

  @override
  String get activityExportSubtitle => 'Review your selection before continuing.';

  @override
  String get activityExportAccount => 'Account';

  @override
  String get activityExportPeriod => 'Period';

  @override
  String get activityExportType => 'Type';

  @override
  String get activityExportCurrencyFormat => 'Currency · Format';

  @override
  String activityExportConfirmedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count confirmed movements',
      one: '1 confirmed movement',
      zero: '0 confirmed movements',
    );
    return '$_temp0';
  }

  @override
  String activityExportIncludedCount(int count) {
    return '$count movements included';
  }

  @override
  String activityExportMoreCount(int count) {
    return 'and $count more';
  }

  @override
  String get activityExportIncludePending => 'Include pending';

  @override
  String activityExportPendingExcluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending movements excluded. Turn on to include them.',
      one: '1 pending movement excluded. Turn on to include it.',
    );
    return '$_temp0';
  }

  @override
  String activityExportPendingIncluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending movements will be included and marked as pending.',
      one: '1 pending movement will be included and marked as pending.',
    );
    return '$_temp0';
  }

  @override
  String get activityExportAllResults =>
      'All filtered results are exported, not only the loaded rows. Order, dates, and time zone are preserved.';

  @override
  String get activityExportNoNotes =>
      'Notes are not included. Saving and sharing use the same CSV.';

  @override
  String get activityExportSave => 'Save file';

  @override
  String get activityExportShare => 'Share file';

  @override
  String activityExportPreparing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movements',
      one: '1 movement',
    );
    return 'Preparing $_temp0…';
  }

  @override
  String get activityExportErrorTitle => 'We couldn\'t create the file';

  @override
  String get activityExportErrorMessage =>
      'A temporary problem occurred. Your selection is still here; please try again.';

  @override
  String get activityExportCloseHint => 'Your filters and selection are kept when you close.';

  @override
  String get activityTotalsTitle => 'Summary';

  @override
  String get activityTotalsIncome => 'Income';

  @override
  String get activityTotalsExpenses => 'Expenses';

  @override
  String get activityTotalsNet => 'Result';

  @override
  String get activityTotalsMethodNote => 'Income − expenses · Transfers excluded';

  @override
  String get activityTransfersTotalsNote =>
      'Transfers are not included in income, expenses, or net result.';

  @override
  String get activityTotalsEmpty => 'No confirmed income or expenses to calculate totals.';

  @override
  String get activityCsvDate => 'Date and time';

  @override
  String get activityCsvType => 'Type';

  @override
  String get activityCsvDescription => 'Description';

  @override
  String get activityCsvAccount => 'Account(s)';

  @override
  String get activityCsvCategory => 'Category';

  @override
  String get activityCsvAmount => 'Amount';

  @override
  String get activityCsvCurrency => 'Currency';

  @override
  String get activityCsvStatus => 'Status';

  @override
  String get activityCsvPending => 'Pending';

  @override
  String get activityCsvConfirmed => 'Confirmed';

  @override
  String get activityCsvRejected => 'Rejected';

  @override
  String get activityCsvUnknownAccount => 'Unknown account';

  @override
  String get activityCsvUnknownCategory => 'Unknown category';

  @override
  String get transferOperationLabel => 'Transfer';

  @override
  String get budget => 'Budget';

  @override
  String get accounts => 'Accounts';

  @override
  String get accountsTitle => 'Your accounts';

  @override
  String get accountsSubtitle => 'Balances organized by currency';

  @override
  String get addAccount => 'Add account';

  @override
  String get cashAccountType => 'Cash';

  @override
  String get checkingAccountType => 'Checking account';

  @override
  String get savingsAccountType => 'Savings account';

  @override
  String get addMovement => 'Add transaction';

  @override
  String get addMovementChoiceTitle => 'What would you like to add?';

  @override
  String get addMovementChoiceSubtitle => 'Choose an option to continue';

  @override
  String get moveMoney => 'Transfer money';

  @override
  String get close => 'Close';

  @override
  String get transferExplanation =>
      'Transfer money between your own accounts. It does not add to or subtract from your total balance.';

  @override
  String incomeRegistered(Object amount) {
    return 'Income recorded · $amount';
  }

  @override
  String expenseRegistered(Object amount) {
    return 'Expense recorded · $amount';
  }

  @override
  String get transferRegistered => 'Transfer recorded';

  @override
  String get viewMovement => 'View transaction';

  @override
  String get viewDetails => 'View details';

  @override
  String get viewPendingOperations => 'View pending';

  @override
  String get pendingBalanceNote =>
      'Some transactions are saved on this device. Confirmed balances may not include them yet.';

  @override
  String get notVisibleWithCurrentFilters => 'This transaction is hidden by your current filters';

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
  String get manageCategories => 'Manage categories';

  @override
  String get editCategory => 'Edit category';

  @override
  String get edit => 'Edit';

  @override
  String get categoriesSubtitle => 'Organize transactions with familiar names.';

  @override
  String get categorySavedDescription => 'This name will appear on your transactions and budgets.';

  @override
  String get confirmArchiveCategoryTitle => 'Archive this category?';

  @override
  String get categoryName => 'Name';

  @override
  String get categoryTypeReadOnly => 'Type · cannot be changed';

  @override
  String get saveCategoryChanges => 'Save changes';

  @override
  String get archiveCategoryDetails =>
      'It will no longer appear in new transactions. Existing records will keep this category.';

  @override
  String get categoryNameRequired => 'Enter a name for this category.';

  @override
  String get categorySaved => 'Category updated';

  @override
  String get newCategory => 'New category';

  @override
  String get archive => 'Archive';

  @override
  String get adjustAccountBalance => 'Adjust balance';

  @override
  String get balanceAdjustmentTitle => 'Adjust balances';

  @override
  String get balanceAdjustmentSubtitle => 'Your opening balance and transactions will not change.';

  @override
  String get balanceAdjustmentTarget => 'Actual balance';

  @override
  String balanceAdjustmentCurrent(Object balance) {
    return 'Current balance: $balance';
  }

  @override
  String get balanceAdjustmentPrevious => 'Previous balance';

  @override
  String get balanceAdjustmentDifferenceLabel => 'Difference';

  @override
  String balanceAdjustmentDifference(Object amount) {
    return 'Difference: $amount';
  }

  @override
  String get balanceAdjustmentReason => 'Reason (optional)';

  @override
  String get balanceAdjustmentOtherDevicesHint =>
      'Sync pending transactions on your other devices first; they could change these balances afterward.';

  @override
  String get balanceAdjustmentPendingHint =>
      'Resolve pending, syncing, or rejected transactions for the selected accounts before adjusting.';

  @override
  String get balanceAdjustmentSave => 'Save adjustments';

  @override
  String get balanceAdjustmentNoop => 'The target balance already matches the current balance.';

  @override
  String get balanceAdjustmentInvalidAmount => 'Enter a valid balance within the allowed limit.';

  @override
  String get balanceAdjustmentSuccess => 'Balances updated.';

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
  String get amountInvalid => 'Enter a valid amount greater than zero.';

  @override
  String get amountTooLarge => 'Amount cannot exceed 1,000,000,000 in this currency.';

  @override
  String get operationAccountRequired => 'Choose an account.';

  @override
  String get operationCategoryRequired => 'Choose a category.';

  @override
  String get transferSourceRequired => 'Choose a source account.';

  @override
  String get transferDestinationRequired => 'Choose a destination account.';

  @override
  String get transferAccountsDifferent => 'Choose two different accounts with the same currency.';

  @override
  String get budgetDayInvalidForMonth => 'Choose a day that exists in the selected month.';

  @override
  String get onboardingAccountRequired => 'Enter a name for your first account.';

  @override
  String get type => 'Type';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

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
  String get syncIssueNetwork =>
      'The server is unreachable. This movement is still saved on this device; try again when the connection returns.';

  @override
  String get syncIssuePermissionDenied =>
      'Firebase rejected this movement. Check your session; if it continues, share the diagnostic code with support.';

  @override
  String get syncIssueInvalidOperation =>
      'This movement no longer matches the current data. Check the account, category, or budget before retrying.';

  @override
  String get syncIssueUnexpected =>
      'We could not identify the cause. Share the diagnostic code with support.';

  @override
  String syncDiagnosticCode(Object code) {
    return 'Diagnostic code: $code';
  }

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

  @override
  String get accountFormCreateSubtitle => 'Choose how you want to organize this money.';

  @override
  String get accountFormEditSubtitle =>
      'You can change the name; balance and account type stay tied to your history.';

  @override
  String get accountNameHint => 'For example, Everyday spending';

  @override
  String get accountType => 'Account type';

  @override
  String get accountCurrency => 'Currency';

  @override
  String get openingBalanceHelper =>
      'Enter 0 or more. You can update the balance with transactions.';

  @override
  String profileCurrencyHint(Object currency) {
    return 'Your profile currency is $currency.';
  }

  @override
  String get accountBalanceReadOnlyHelper =>
      'The balance changes when you add income, expenses, or transfers.';

  @override
  String get accountNameRequired => 'Enter an account name.';

  @override
  String get invalidInitialBalance => 'Enter a valid balance of 0 or more.';

  @override
  String get accountSaveFailed =>
      'We couldn\'t save this account. Your information is still here; try again.';

  @override
  String get budgetCreateTitle => 'Plan by category';

  @override
  String get budgetCreateSubtitle => 'Plan each item for your month.';

  @override
  String get budgetTrackingTitle => 'Budget tracking';

  @override
  String get viewBudgetTracking => 'View tracking';

  @override
  String get budgetTrackingEmptyTitle => 'No budgets yet';

  @override
  String get budgetTrackingEmptyMessage =>
      'Create a budget to compare your plan with this month\'s activity.';

  @override
  String budgetUsedPercent(Object percent) {
    return '$percent% used';
  }

  @override
  String budgetReceivedPercent(Object percent) {
    return '$percent% received';
  }

  @override
  String unbudgetedCategoryCount(Object count) {
    return '$count categories have activity without a budget';
  }

  @override
  String unbudgetedActualAmount(Object amount) {
    return 'Unbudgeted total · $amount';
  }

  @override
  String get budgetMonth => 'Month';

  @override
  String get budgetSelectMonth => 'Choose a month';

  @override
  String get budgetPlannedItems => 'Planned items';

  @override
  String get budgetAddItem => 'Add item';

  @override
  String get budgetRemoveItem => 'Remove';

  @override
  String get budgetItemDescription => 'Item description';

  @override
  String get budgetDescriptionRequired => 'Enter a description.';

  @override
  String get budgetAmountPositive => 'Enter an amount greater than zero.';

  @override
  String get budgetSelectCategory => 'Choose a category.';

  @override
  String get budgetNoCategories =>
      'There are no categories for this type. Create a category to continue.';

  @override
  String get budgetValidateItems => 'Check the description, amount, and day for each item.';

  @override
  String get budgetAlreadyExists => 'A budget already exists for this category and month.';

  @override
  String get budgetSaveFailed =>
      'We couldn\'t save the budget. Your details are still here; try again.';

  @override
  String get budgetSave => 'Save budget';

  @override
  String get budgetsTitle => 'Your budgets';

  @override
  String get budgetsSubtitle => 'Plan and review your month';

  @override
  String get budgetsForMonth => 'Budgets this month';

  @override
  String get budgetFilterAll => 'All';

  @override
  String get budgetFilterExpenses => 'Expenses';

  @override
  String get budgetFilterIncome => 'Income';

  @override
  String get budgetEmptyTitle => 'You don\'t have any budgets yet';

  @override
  String get budgetEmptyMessage =>
      'Create a budget by category to see how much you plan to spend and what you have left this month.';

  @override
  String get budgetFilteredEmptyTitle => 'No budgets match this filter';

  @override
  String get budgetFilteredEmptyMessage => 'Try another filter to see your budgets.';

  @override
  String get budgetFilterReset => 'View all';

  @override
  String get budgetSpent => 'Spent';

  @override
  String get budgetReceived => 'Received';

  @override
  String get day => 'Day';

  @override
  String get budgetDetailTitle => 'Budget details';

  @override
  String get budgetBackToBudgets => 'Budgets';

  @override
  String budgetItemsHeading(Object count) {
    return 'Planned items · $count';
  }

  @override
  String get budgetEditItemTitle => 'Edit item';

  @override
  String get budgetAddItemSubtitle => 'Add another item to this budget.';

  @override
  String get budgetEditItemSubtitle => 'Update the details, amount, or expected day.';

  @override
  String get budgetDescription => 'Description';

  @override
  String budgetPlannedAmount(Object currency) {
    return 'Planned amount · $currency';
  }

  @override
  String get budgetExpectedDay => 'Expected day';

  @override
  String get budgetDayRange => 'Choose a day between 1 and 31.';

  @override
  String get budgetTotalUpdatesHint => 'The planned total will update automatically when you save.';

  @override
  String get budgetSaveChanges => 'Save changes';

  @override
  String get budgetEditFailed =>
      'We couldn\'t save your changes. Your details are still here; try again.';

  @override
  String get budgetAddItemFailed =>
      'We couldn\'t add the item. Your details are still here; try again.';

  @override
  String get budgetDeleteItemTitle => 'Remove this item?';

  @override
  String budgetDeleteItemMessage(Object amount) {
    return 'The planned total will decrease by $amount. Recorded transactions will not change.';
  }

  @override
  String get budgetLastItemTitle => 'Keep at least one item';

  @override
  String get budgetLastItemMessage =>
      'A budget needs at least one item. To remove it, delete the entire budget.';

  @override
  String get budgetDeleteBudgetAction => 'Delete budget';

  @override
  String get budgetDeleteBudgetTitle => 'Delete this budget?';

  @override
  String get budgetDeleteBudgetMessage =>
      'It will be removed from your active budgets. Your transactions and balances will remain.';

  @override
  String get budgetArchiveSuccess => 'Budget removed from the active list.';

  @override
  String get budgetDeleteFailed => 'We couldn\'t delete the budget. Please try again.';

  @override
  String get budgetItemDeleteFailed => 'We couldn\'t remove the item. Please try again.';

  @override
  String get budgetItemSaved => 'Changes saved.';

  @override
  String get budgetItemAdded => 'Item added.';

  @override
  String get budgetEditAction => 'Edit';

  @override
  String get categoryIcon => 'Category icon';

  @override
  String get categoryColor => 'Category color';

  @override
  String get categoryColorDefault => 'Default';

  @override
  String get categoryColorBlue => 'Blue';

  @override
  String get categoryColorGreen => 'Green';

  @override
  String get categoryColorOrange => 'Orange';

  @override
  String get categoryColorPurple => 'Purple';

  @override
  String get categoryColorRed => 'Red';

  @override
  String get categoryColorTeal => 'Teal';

  @override
  String categoryColorOption(Object color, Object hex) {
    return '$color · $hex';
  }

  @override
  String get changeColor => 'Change';

  @override
  String get useColor => 'Use color';

  @override
  String get categoryIconLabel => 'Icon';

  @override
  String get categoryIconUtensils => 'Utensils';

  @override
  String get categoryIconHouse => 'House';

  @override
  String get categoryIconCar => 'Car';

  @override
  String get categoryIconHeart => 'Heart';

  @override
  String get categoryIconBook => 'Book';

  @override
  String get categoryIconBriefcase => 'Briefcase';

  @override
  String get categoryIconTag => 'Tag';

  @override
  String get changeIcon => 'Change';

  @override
  String get useIcon => 'Use icon';

  @override
  String get budgetConfirmMonth => 'Confirm month';

  @override
  String get categoryIconFood => 'Food';

  @override
  String get categoryIconHousing => 'Housing';

  @override
  String get categoryIconTransport => 'Transport';

  @override
  String get categoryIconHealth => 'Health';

  @override
  String get categoryIconEducation => 'Education';

  @override
  String get categoryIconSalary => 'Salary';

  @override
  String get categoryIconOther => 'Other';

  @override
  String budgetItemActual(Object amount) {
    return 'Recorded: $amount';
  }

  @override
  String get budgetRecordExpense => 'Record expense';

  @override
  String get budgetRecordIncome => 'Record income';

  @override
  String budgetItemNoCompatibleAccount(Object currency) {
    return 'You need an active $currency account to record this movement.';
  }

  @override
  String budgetItemMovementContext(Object description) {
    return 'Movement for item: $description';
  }

  @override
  String get budgetArchivedItems => 'Archived items';

  @override
  String get budgetItemArchived => 'Archived · movements retained';

  @override
  String get budgetItemLinkedMovements => 'Linked movements';

  @override
  String get budgetItemNoLinkedMovements => 'There are no linked movements yet.';

  @override
  String get budgetLinkedMovementConfirmed => 'Confirmed';

  @override
  String get budgetLinkedMovementPending => 'Pending sync';

  @override
  String get budgetLinkedMovementRejected => 'Rejected · excluded from total';

  @override
  String budgetArchiveNetworkFailure(Object code) {
    return 'We couldn\'t connect. The budget is still active; check your connection and try again. Code: $code';
  }

  @override
  String budgetArchivePermissionFailure(Object code) {
    return 'Firebase didn\'t authorize this change. The budget is still active; check your session and share this code with support: $code';
  }

  @override
  String budgetArchiveConflictFailure(Object code) {
    return 'We couldn\'t validate the budget. It is still active; share this code with support: $code';
  }

  @override
  String budgetArchiveUnexpectedFailure(Object code) {
    return 'We couldn\'t delete the budget. It is still active; try again. Code: $code';
  }

  @override
  String get more => 'More';

  @override
  String get back => 'Back';

  @override
  String get moreSubtitle => 'Manage your categories and account session.';

  @override
  String get moreManagement => 'Management';

  @override
  String get moreSession => 'Session';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmMessage => 'You will need to sign in again to access your data.';

  @override
  String signOutPendingWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# movements waiting to sync',
      one: '# movement waiting to sync',
    );
    return 'You have $_temp0. Signing out will not delete them, but you may need to sign in again to sync.';
  }

  @override
  String get discardChangesTitle => 'Discard your changes?';

  @override
  String get discardChangesMessage => 'Your changes have not been saved yet.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discardChanges => 'Discard';

  @override
  String get accountIncludeInHomeBalance => 'Include in Home balance';

  @override
  String get accountIncludeInHomeBalanceHint =>
      'This account will be included in the combined Home balance.';

  @override
  String get homeNoAccountsIncluded => 'No active accounts are included in the Home balance.';

  @override
  String get homeCustomizeTitle => 'Customize Home';

  @override
  String get homeCustomizeSubtitle =>
      'Choose what you want to see on Home. Sync notices will always remain visible.';

  @override
  String get homeWidgetsSection => 'Home cards';

  @override
  String get homeBudgetCardsSection => 'Budgets by category';

  @override
  String get homeWidgetTotalBalance => 'Total balance';

  @override
  String get homeWidgetIncome => 'Income summary';

  @override
  String get homeWidgetExpense => 'Expense summary';

  @override
  String get homeWidgetExpenseBudget => 'Expense vs. budget';

  @override
  String get homeWidgetIncomeBudget => 'Income vs. budget';

  @override
  String get homeWidgetRecentActivity => 'Recent activity';

  @override
  String get homeNoBudgetCards => 'There are no active budgets to customize.';

  @override
  String get homePreferencesSaving => 'Saving preference…';

  @override
  String get homePreferencesSaveFailed => 'Could not save. Your selection is preserved; try again.';

  @override
  String get coachTitle => 'Coach and reminders';

  @override
  String get coachSettingsIntro => 'Set your routine and choose when to review your finances.';

  @override
  String get coachDailyTitle => 'Daily check-in';

  @override
  String get coachWeeklyTitle => 'Weekly review';

  @override
  String get coachNextStepTitle => 'Your next step';

  @override
  String get coachDailyReminder => 'Daily check-in reminder';

  @override
  String get coachWeeklyReminder => 'Weekly review reminder';

  @override
  String get coachReminderTime => 'Reminder time';

  @override
  String get coachReminderDays => 'Days of the week';

  @override
  String get coachDevice => 'On this device';

  @override
  String get coachEnableDevice => 'Receive reminders on this device';

  @override
  String get coachDevicePrivacy => 'Notifications never show amounts or account details.';

  @override
  String get coachWindowNotice =>
      'Open the app at least once every 28 days to renew reminders. Changes from other devices apply after syncing.';

  @override
  String get coachPause => 'Pause for seven days';

  @override
  String get coachResume => 'Resume reminders';

  @override
  String get coachPaused => 'Reminders paused';

  @override
  String get coachPermissionGranted => 'Notifications allowed';

  @override
  String get coachPermissionDenied => 'Notifications are blocked in device settings.';

  @override
  String get coachPermissionUnknown => 'Enable reminders to request permission.';

  @override
  String get coachUnsupported =>
      'You can review your routine on the web. Reminders are available on Android and iOS.';

  @override
  String get coachOpenSettings => 'Open device settings';

  @override
  String get coachReviewed => 'Reviewed';

  @override
  String get coachFinishDaily => 'I reviewed my transactions';

  @override
  String get coachNoMovements => 'I had no transactions today';

  @override
  String get coachFinishWeekly => 'Mark week as reviewed';

  @override
  String get coachNoRecords => 'No transactions recorded for this period.';

  @override
  String get coachAllCurrent => 'Your routine is up to date.';

  @override
  String get coachDailyAction => 'Review my transactions';

  @override
  String get coachWeeklyAction => 'Review my week';

  @override
  String get coachReviewIntro =>
      'Review your records before completing your check-in. Recording a transaction does not complete the review.';

  @override
  String get coachWeeklyIntro =>
      'Income, expenses and Result from confirmed transactions. Transfers and balance adjustments are excluded.';

  @override
  String get coachConfirmedCount => 'Confirmed transactions';

  @override
  String get coachPendingCount => 'Pending synchronization';

  @override
  String get coachRejectedCount => 'Rejected transactions';

  @override
  String get coachCached =>
      'Data saved on this device; the period may be incomplete. Connect and refresh to verify it.';

  @override
  String get coachSavePending => 'Review saved on this device; awaiting synchronization.';

  @override
  String get coachSaveFailed => 'Could not save. Your selection is preserved; try again.';

  @override
  String get coachSaveConfirmed => 'Review saved';

  @override
  String get coachTopCategories => 'Top spending categories';

  @override
  String get coachConfigure => 'Configure my routine';

  @override
  String get coachReadFailure => 'We could not load your review. Try again.';

  @override
  String get coachNotificationTitle => 'A moment for your finances';

  @override
  String get coachNotificationBody => 'Your review is ready. Open LumioMoney to continue.';

  @override
  String get coachHomeWidget => 'Coach next step';

  @override
  String get coachReminderTiming => 'Delivery may be delayed by device settings or battery saving.';

  @override
  String get coachPreferencesPending => 'Changes saved on this device; awaiting synchronization.';

  @override
  String get coachScheduleFailed => 'We could not schedule reminders. Retry scheduling.';

  @override
  String get coachViewMovements => 'View transactions for this period';

  @override
  String get coachNoMovementsUnavailable =>
      'Transactions are now recorded or current data is unavailable. Review this day before confirming.';
}
