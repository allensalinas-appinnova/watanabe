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
  String get debtPaymentCard => 'Credit card payment';

  @override
  String get debtPaymentLoan => 'Loan payment';

  @override
  String get activityFilterDebtPayments => 'Debt payments';

  @override
  String get activityCsvPaymentType => 'Payment type';

  @override
  String get categoryCatalogSyncMessage => 'Default categories could not be updated.';

  @override
  String get categoryIconInterest => 'Interest and fees';

  @override
  String get debtNewChargesCategory => 'Category for new charges';

  @override
  String get debtNewChargesExpenseNote =>
      'Only new charges in this payment are recorded as an expense.';

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
  String get continueAsGuest => 'Try without creating an account';

  @override
  String get guestAccountHint =>
      'Your data is tied to this session. Save your account to recover it on other devices.';

  @override
  String get guestSaveAccount => 'Save my account';

  @override
  String get guestUpgradeTitle => 'Save my account';

  @override
  String get guestUpgradeSubtitle =>
      'Link an email or Google to this session to protect your data. Your profile and movements will stay here.';

  @override
  String get guestUpgradeEmailTitle => 'Create email sign-in';

  @override
  String get guestUpgradeGoogleButton => 'Link with Google';

  @override
  String get guestUpgradeConfirmPassword => 'Confirm password';

  @override
  String get guestUpgradePasswordMismatch => 'The passwords do not match.';

  @override
  String get guestUpgradeSuccess => 'Your account is protected. Your data remains in this session.';

  @override
  String get guestUpgradeEmailSent =>
      'Account protected. We sent an email to verify your address; you can keep using the app.';

  @override
  String get guestUpgradeEmailNotSent =>
      'Your account is protected, but we couldn\'t send the verification email. You can retry.';

  @override
  String get guestUpgradeResendVerification => 'Resend verification';

  @override
  String get guestUpgradeAlreadyProtected => 'This session already has a sign-in method linked.';

  @override
  String get guestUpgradeConflict =>
      'This email or account already belongs to another account. Your guest session and data are unchanged. Try another credential.';

  @override
  String get guestUpgradeProviderLinked => 'This sign-in method is already linked to this session.';

  @override
  String get guestUpgradeCancelled => 'Linking was cancelled. Your guest session is still active.';

  @override
  String get guestUpgradeUnavailable =>
      'This sign-in method is unavailable right now. Your session is still active.';

  @override
  String get guestUpgradeWeakPassword => 'Choose a stronger password.';

  @override
  String get guestSignOutWarning =>
      'This guest session has no recovery method. If you sign out, you may lose access to this data. Save your account first to recover it on another device.';

  @override
  String get guestUpgradeBackToApp => 'Back to app';

  @override
  String get authLoginTab => 'Log in';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'you@example.com';

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
  String get authProviderUnavailable =>
      'This sign-in option is currently unavailable. Choose another option or contact support.';

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
  String get onboardingPreferencesSection => 'Preferences';

  @override
  String get onboardingAccountSection => 'Your first account';

  @override
  String get onboardingAccountExplanation =>
      'An account is where you keep or use money: cash, checking, or savings. You can add more later.';

  @override
  String get onboardingAccountNameLabel => 'Name to identify it';

  @override
  String get onboardingAccountNameHelper =>
      'This name helps you recognize it. You can change it later.';

  @override
  String get onboardingWalletAccountName => 'My wallet';

  @override
  String get onboardingCheckingAccountName => 'My checking account';

  @override
  String get onboardingSavingsAccountName => 'My savings';

  @override
  String get onboardingCurrentBalance => 'Current balance (optional)';

  @override
  String get onboardingCurrentBalanceHelper =>
      'This is what you have in this account today; it is not income.';

  @override
  String get onboardingCreateAccount => 'Create my account';

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
  String get activityTotalsMethodAction => 'How the result is calculated';

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
  String get accountsTitle => 'Accounts and debt';

  @override
  String get accountsSubtitle => 'Cash, cards, and loans in one place';

  @override
  String get addAccount => 'Add account';

  @override
  String get addCreditCard => 'Add credit card';

  @override
  String get accountsAddEntry => 'Add account or debt';

  @override
  String get addLoan => 'Add loan';

  @override
  String get registerMovement => 'Register';

  @override
  String get showAccountBalances => 'Show balances by account';

  @override
  String get hideAccountBalances => 'Hide balances by account';

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
  String get openExistingBudget => 'Open';

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
  String get budgetMovementsTab => 'Movements';

  @override
  String get budgetMovementsExplanation =>
      'Progress includes all confirmed movements in this category and period, whether or not they are linked to an item.';

  @override
  String get budgetMovementFilterAll => 'All';

  @override
  String get budgetMovementFilterLinked => 'With item';

  @override
  String get budgetMovementFilterUnlinked => 'Without item';

  @override
  String get budgetMovementsEmpty =>
      'There are no confirmed movements for this category in this period.';

  @override
  String get budgetMovementUnassociated => 'No item linked';

  @override
  String budgetMovementLinkedTo(String item) {
    return 'Linked to: $item';
  }

  @override
  String budgetMovementArchivedLink(String item) {
    return 'Linked to archived item: $item';
  }

  @override
  String get budgetMovementAssociation => 'Change linked item';

  @override
  String get budgetMovementClearAssociation => 'Remove link';

  @override
  String get budgetMovementReversal => 'Reversal; cannot be linked';

  @override
  String get budgetMovementAssociationSaved =>
      'The link was updated. Account balance and total spending are unchanged.';

  @override
  String get budgetMovementAssociationFailed =>
      'Couldn\'t change the link. Balances were not changed; try again.';

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
  String get moreSubtitle => 'Personalize LumioMoney and manage your preferences.';

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
  String get coachAllCurrent => 'There is no priority step right now.';

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

  @override
  String get plan => 'Plan';

  @override
  String get coachTab => 'Coach';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get accountsSectionOverview => 'Overview';

  @override
  String get accountsSectionMoney => 'Money';

  @override
  String get accountsSectionCards => 'Cards';

  @override
  String get accountsSectionLoans => 'Loans';

  @override
  String get accountsSectionEmpty => 'There are no accounts in this section yet.';

  @override
  String get coachHubTitle => 'Your financial coach';

  @override
  String get coachHubSubtitle => 'Review your transactions and build a clear financial routine.';

  @override
  String get coachHistoryTitle => 'Recent reviews';

  @override
  String get coachHistoryEmpty => 'You have not completed any reviews yet.';

  @override
  String get coachSettingsShortcut => 'Set reminders';

  @override
  String get debtSelectForPayment =>
      'Choose the card or loan you already paid. Recording a payment does not move money for you.';

  @override
  String get accountDetailTitle => 'Account details';

  @override
  String get operationEditTitle => 'Edit transaction';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceSubtitle => 'Personalize LumioMoney colors across your devices.';

  @override
  String get appearanceMode => 'Theme';

  @override
  String get appearanceSystem => 'System';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearancePalette => 'Color palette';

  @override
  String get paletteLumio => 'Lumio';

  @override
  String get paletteClassicBlue => 'Classic blue';

  @override
  String get paletteOcean => 'Ocean';

  @override
  String get palettePlum => 'Plum';

  @override
  String get appearanceSaving => 'Saving preference…';

  @override
  String get appearanceSaved => 'Appearance synced';

  @override
  String get appearanceSaveFailed => 'Appearance could not sync. Your selection is still applied.';

  @override
  String get appearanceRetry => 'Retry';

  @override
  String get accountKindMoney => 'Money account';

  @override
  String get accountKindCreditCard => 'Credit card';

  @override
  String get accountKindBankLoan => 'Bank loan';

  @override
  String get accountKindPersonalLoan => 'Personal loan received';

  @override
  String get selectionChoosePrompt => 'Select';

  @override
  String get selectionSearchHint => 'Search by name or type';

  @override
  String get selectionClearSearch => 'Clear search';

  @override
  String get selectionNoResults => 'No results';

  @override
  String get accountOptionBalance => 'Balance';

  @override
  String get accountOptionDebt => 'Debt';

  @override
  String get accountOptionCreditBalance => 'Credit balance';

  @override
  String get selectionFrequent => 'Frequent';

  @override
  String get selectionAll => 'All options';

  @override
  String get resetSectionTitle => 'Destructive actions';

  @override
  String get resetTitle => 'Reset my data';

  @override
  String get resetDescription =>
      'Your movements, accounts and debts, budgets, custom categories, preferences, Coach reviews, and import data will be deleted. This cannot be undone.';

  @override
  String get resetPreserveAccess =>
      'Your LumioMoney sign-in will remain. You will return to the initial setup afterward.';

  @override
  String get resetConfirmTitle => 'Confirm reset';

  @override
  String get resetConfirmMessage => 'To continue, type the word shown below.';

  @override
  String get resetTypePrompt => 'Type RESET';

  @override
  String get resetConfirmWord => 'RESET';

  @override
  String get resetFinalTitle => 'Delete all your data?';

  @override
  String get resetFinalMessage =>
      'Other devices will be blocked while your LumioMoney data is deleted. You will remain signed in.';

  @override
  String get resetAction => 'Reset data';

  @override
  String get resetProgressTitle => 'Reset in progress';

  @override
  String get resetProgressMessage =>
      'We are securely deleting your data. Keep this screen open, or return here to continue if interrupted.';

  @override
  String get resetWorking => 'Resetting…';

  @override
  String get resetResume => 'Continue reset';

  @override
  String get resetFailure =>
      'We couldn\'t finish the reset. Your data remains blocked; you can safely retry.';

  @override
  String resetPendingWarning(Object count) {
    return 'First resolve the $count pending, syncing, or rejected operations. No data was deleted.';
  }

  @override
  String get resetPendingCheckFailure =>
      'We couldn\'t verify pending operations. Try again before resetting.';

  @override
  String get unallocatedPaymentStatus => 'Recorded · allocation needed';

  @override
  String get unallocatedPaymentExplanation =>
      'The cash outflow is already recorded. The loan balance and expenses will update after you complete the allocation.';

  @override
  String get debtPayUnallocated => 'I\'ll complete the split later';

  @override
  String get debtAllocatePayment => 'Complete allocation';

  @override
  String get debtCommitmentsTitle => 'Debt payments';

  @override
  String get debtCommitmentsTab => 'Debt payments';

  @override
  String get budgetsTab => 'Budgets';

  @override
  String get debtCommitmentReminders => 'Local reminders';

  @override
  String get debtCommitmentsEmpty => 'You haven\'t planned any debt payments yet.';

  @override
  String get debtCommitmentCreate => 'Plan a payment';

  @override
  String get debtCommitmentAmount => 'Expected monthly amount';

  @override
  String get debtCommitmentDueDay => 'Due day';

  @override
  String get debtCommitmentFirstMonth => 'First due month';

  @override
  String get debtCommitmentLastMonth => 'Last month (optional)';

  @override
  String get debtCommitmentMonthlyPlanned => 'Planned this month';

  @override
  String get debtCommitmentPaid => 'Payments recorded';

  @override
  String get debtCommitmentRemaining => 'Remaining';

  @override
  String get debtCommitmentStatusUpcoming => 'Upcoming';

  @override
  String get debtCommitmentStatusDue => 'Due';

  @override
  String get debtCommitmentStatusPartial => 'Partially paid';

  @override
  String get debtCommitmentStatusPaid => 'Paid';

  @override
  String get debtCommitmentStatusMissed => 'Overdue';

  @override
  String get debtCommitmentStatusSkipped => 'Skipped';

  @override
  String get debtCommitmentStatusPaused => 'Paused';

  @override
  String get debtPaymentAllocationChoice => 'Do you know how the payment is split?';

  @override
  String get debtPaymentKnownSplit => 'Yes, I\'ll enter the allocation';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get debtCommitmentHomeWidget => 'Debt payments';

  @override
  String get debtCommitmentNextDue => 'Next due date';

  @override
  String get debtPaymentsToReview => 'Payments to review';

  @override
  String get unallocatedDebtPayment => 'Loan payment without breakdown';

  @override
  String get debtCommitmentSkip => 'Skip this installment';

  @override
  String get debtCommitmentSkipConfirm =>
      'This installment will be marked as skipped and will not change payments in other months.';

  @override
  String get debtCommitmentPause => 'Pause future payments';

  @override
  String get debtCommitmentResume => 'Resume future payments';

  @override
  String get debtCommitmentConfirmSkip => 'Skip installment';

  @override
  String get categoryIconGroceries => 'Groceries';

  @override
  String get categoryIconCarMaintenance => 'Vehicle maintenance';

  @override
  String get categoryIconPhone => 'Phone';

  @override
  String get categoryIconUtilities => 'Utilities';

  @override
  String get categoryIconInsurance => 'Insurance';

  @override
  String get categoryIconFamily => 'Family';

  @override
  String get categoryIconChildren => 'Children';

  @override
  String get categoryIconParents => 'Parents';

  @override
  String get categoryIconPets => 'Pets';

  @override
  String get categoryIconSports => 'Sports';

  @override
  String get categoryIconHobbies => 'Hobbies';

  @override
  String get categoryIconSubscriptions => 'Subscriptions';

  @override
  String get categoryIconEntertainment => 'Entertainment';

  @override
  String get categoryIconTravel => 'Travel';

  @override
  String get categoryIconShopping => 'Shopping';

  @override
  String get categoryIconClothing => 'Clothing';

  @override
  String get categoryIconPersonalCare => 'Personal care';

  @override
  String get categoryIconGift => 'Gifts';

  @override
  String get categoryIconFreelance => 'Freelance';

  @override
  String get categoryIconBusiness => 'Business';

  @override
  String get categoryIconInvestment => 'Investments';

  @override
  String get categoryIconSavings => 'Savings';

  @override
  String get categoryIconGroupDaily => 'Everyday';

  @override
  String get categoryIconGroupWellbeing => 'Wellbeing and family';

  @override
  String get categoryIconGroupLifestyle => 'Lifestyle';

  @override
  String get categoryIconGroupMoney => 'Money';

  @override
  String get categoryIconSearchHint => 'Search icons';

  @override
  String get categoryIconNoResults => 'No matching icons.';

  @override
  String get categoryTemplatePrompt => 'Optional ideas';

  @override
  String get categoryTemplateFamily => 'Family';

  @override
  String get categoryTemplateChildren => 'Children';

  @override
  String get categoryTemplateParents => 'Parents';

  @override
  String get cardBillingCycle => 'Billing cycle';

  @override
  String get cardBillingCycleExplanation =>
      'The closing day ends the statement period. The payment day helps with planning; confirm the exact date on your statement.';

  @override
  String get cardStatementClosingDay => 'Statement closing day';

  @override
  String get cardPaymentDueDay => 'Usual payment day';

  @override
  String get notConfigured => 'Not set';

  @override
  String get cardPlanPayment => 'Plan payment';

  @override
  String cardUpcomingDueSuggestion(Object day) {
    return 'Suggested payment day: $day. Check your statement.';
  }

  @override
  String get cardUseSuggestedDueDay => 'Use card suggestion';

  @override
  String get debtPaymentPlanning => 'Payment planning';

  @override
  String get debtPaymentDueDay => 'Usual payment day';

  @override
  String get debtPaymentDayExplanation =>
      'This is a planning reference. Confirm the due date in your loan agreement or statement.';

  @override
  String debtUpcomingPaymentSuggestion(Object day) {
    return 'Suggested payment day: $day. Confirm the date with your lender.';
  }

  @override
  String get debtUseSuggestedPaymentDay => 'Use usual payment day';

  @override
  String get myDevicesTitle => 'My devices';

  @override
  String get myDevicesRegisteredOnly => 'Device registration is available for registered accounts.';

  @override
  String get myDevicesDescription =>
      'These are app installations recently used with your account. An installation is not necessarily a separate physical device.';

  @override
  String get myDevicesRetention =>
      'Installations are removed after 90 days without activity. Removing one here does not sign it out; it may appear again when the app is used.';

  @override
  String myDevicesActiveCount(int count) {
    return 'Active installations: $count';
  }

  @override
  String get myDevicesEmpty => 'No active installations are registered yet.';

  @override
  String myDevicesLastSeen(String date) {
    return 'Last activity: $date';
  }

  @override
  String get myDevicesAndroid => 'Android';

  @override
  String get myDevicesIos => 'iPhone or iPad';

  @override
  String get myDevicesWeb => 'Web browser';

  @override
  String get myDevicesUnknown => 'Unknown platform';

  @override
  String get myDevicesRemove => 'Remove';

  @override
  String get myDevicesRemoveTitle => 'Remove this installation?';

  @override
  String get myDevicesRemoveWarning =>
      'This only removes its entry from this list. It does not remotely sign out the app. If it is used again, it may be registered again.';

  @override
  String get myDevicesRemoved => 'Installation removed from the list.';

  @override
  String get myDevicesLoadError => 'We couldn\'t load your installations.';

  @override
  String get coachScreenSubtitle => 'One step at a time to understand your money.';

  @override
  String get coachDataCached => 'Some data is from this device and may be incomplete.';

  @override
  String get coachDataFresh => 'Data is up to date';

  @override
  String get coachWhyThis => 'Why am I seeing this?';

  @override
  String get coachActionSyncTitle => 'Review a rejected transaction';

  @override
  String get coachActionSyncBody => 'A transaction could not sync. Review it before trying again.';

  @override
  String coachActionDueTitle(String account) {
    return 'Your $account payment needs attention';
  }

  @override
  String get coachActionDueBody =>
      'There is an amount left to record for this planned payment. This does not confirm that your lender considers it overdue.';

  @override
  String coachActionUpcomingTitle(String account) {
    return 'Your $account payment is coming up';
  }

  @override
  String get coachActionUnallocatedTitle => 'Complete a payment\'s details';

  @override
  String get coachActionUnallocatedBody =>
      'The money leaving your account is already recorded. Allocate the payment to update the loan and expenses.';

  @override
  String get coachActionBudgetTitle => 'An expense budget has reached its limit';

  @override
  String get coachActionBudgetBody =>
      'Transactions linked to this budget have reached the planned amount.';

  @override
  String coachActionBudgetProgress(String actual, String planned) {
    return 'Transactions linked to this budget total $actual against $planned planned.';
  }

  @override
  String get coachReviewBudget => 'Review budget';

  @override
  String get coachActionWeeklyTitle => 'Review the week that just ended';

  @override
  String get coachActionDailyTitle => 'Complete today\'s check-in';

  @override
  String get coachActionConfigureTitle => 'Choose a routine that works for you';

  @override
  String get coachActionCurrentBody =>
      'You can review your transactions or week whenever you like.';

  @override
  String get coachActionExplain =>
      'This suggestion is based on your confirmed records and the routine you chose. It does not make payments or change your data.';

  @override
  String get coachPaymentsSection => 'Payments to review';

  @override
  String get coachSeeMore => 'See all';

  @override
  String coachPaymentDue(String date) {
    return 'Due $date';
  }

  @override
  String coachPaymentRecordedDate(String date) {
    return 'Payment recorded $date';
  }

  @override
  String coachCommitmentProgress(String paid, String planned) {
    return 'You have recorded $paid of the $planned planned for this payment.';
  }

  @override
  String coachPaymentRemaining(String amount) {
    return '$amount left to record';
  }

  @override
  String get coachReviewPayment => 'Review payment';

  @override
  String coachActionDueBudgetTitle(String item) {
    return 'Review: $item';
  }

  @override
  String coachActionUpcomingBudgetTitle(String item) {
    return 'Upcoming expense: $item';
  }

  @override
  String get coachBudgetExpenseDueBody =>
      'This planned expense does not have enough linked movements. Its planned date does not confirm it is still due outside the app.';

  @override
  String get coachBudgetExpenseUpcomingBody =>
      'Review this planned expense and its linked movements. It will not be recorded automatically.';

  @override
  String get coachReviewPlannedExpense => 'Review planned expense';

  @override
  String get coachUpcomingPlan => 'Coming up in your plan';

  @override
  String get coachNoUpcomingPlan =>
      'No expenses or installments need attention in the next seven days.';

  @override
  String planningDueDate(String date) {
    return 'Planned date: $date';
  }

  @override
  String planningDebtTotal(String amount) {
    return 'Debt installments planned: $amount';
  }

  @override
  String get coachCompleteAllocation => 'Complete allocation';

  @override
  String get coachWeeklyUnderstanding => 'Understand your week';

  @override
  String coachWeeklyCategoryInsight(String category, String amount) {
    return 'Your highest net spending category was $category: $amount.';
  }

  @override
  String get coachIncompleteInfo =>
      'Some transactions are still syncing or payments need allocation; totals may be incomplete.';

  @override
  String get coachSourcesIncomplete =>
      'Some information is not available yet. This recommendation is provisional; a higher-priority action may appear.';

  @override
  String get coachProvisionalRecommendation =>
      'This recommendation is provisional. A more urgent action may appear when loading finishes.';

  @override
  String get coachNoReliableRecommendation =>
      'We do not have enough information to recommend a next step yet. You can try again.';

  @override
  String get coachPaymentsIncomplete =>
      'We could not load all payments; this list may be incomplete.';

  @override
  String get coachReviewFullWeek => 'Review full week';

  @override
  String get coachRoutineTitle => 'Your routine';

  @override
  String get coachRoutineInvite =>
      'Turn on one or both routines to track them here. You can complete reviews without enabling notifications.';

  @override
  String get coachRoutineDaily => 'I want to review my transactions every day';

  @override
  String get coachRoutineWeekly => 'I want to review my finances every week';

  @override
  String get coachRoutineStart => 'Turn on tracking';

  @override
  String get coachRoutineLater => 'Not now';

  @override
  String get coachRoutineOff => 'No routines are active; you can review whenever you like.';

  @override
  String get coachRoutineOn => 'Tracking is on. Notifications are configured separately.';

  @override
  String get coachRoutineNotDue => 'Not due yet; you can still review manually.';

  @override
  String get coachRoutineNotConfigured => 'Routine not set up; you can review whenever you like.';

  @override
  String get coachOpenDaily => 'Open daily check-in';

  @override
  String get coachOpenWeekly => 'Open weekly review';

  @override
  String get coachRoutineSaveError =>
      'Could not save your routine. Your selection is preserved; try again.';

  @override
  String get coachNoPaymentsToReview => 'No upcoming payments or allocations need review.';

  @override
  String get coachReportIncomplete =>
      'The week may be incomplete because some data is cached or still syncing.';

  @override
  String get coachToggleAmounts => 'Show or hide amounts';

  @override
  String get coachAmountsHidden => 'Amounts are hidden';

  @override
  String get planningAgenda => 'Agenda';

  @override
  String get planningPlan => 'Plan';

  @override
  String get planningPendingOnly => 'To address';

  @override
  String get planningAll => 'All';

  @override
  String get planningAllTypes => 'All types';

  @override
  String get planningAllCurrencies => 'All currencies';

  @override
  String get planningNoEntries => 'Nothing is planned for this month yet.';

  @override
  String get planningNoPendingEntries => 'Every planned item has associated activity.';

  @override
  String get planningSourceExplanation =>
      'Associated transactions appear against each planned item. Debt installments never make payments automatically.';

  @override
  String get planningRecorded => 'Recorded';

  @override
  String get planningPendingAmount => 'Pending';

  @override
  String get debtLinkExistingPayment => 'Link an existing payment';

  @override
  String get debtNoExistingPayments => 'There are no compatible unlinked payments.';

  @override
  String get planningTotalsUnavailable => 'Could not load this month’s totals.';

  @override
  String planningDebtCount(int count, int pending) {
    return '$count payments planned · $pending pending';
  }

  @override
  String get debtCommitmentsExcluded => 'Skipped or paused';

  @override
  String get thisMonth => 'This month';

  @override
  String get showLess => 'Show less';

  @override
  String diagnosticText(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'title': 'Financial diagnosis',
        'intro': 'Review liquidity, debt and goals. Complete your information in stages.',
        'configure': 'Complete information',
        'report': 'Diagnosis',
        'scenario': '90-day stress test',
        'incomeReduction': 'Income reduction (%)',
        'expenseIncrease': 'Expense increase (%)',
        'history': 'Complete-month history',
        'assumptions':
            'Projection from today for 90 days; payments precede receipts on the same day. Uses recorded plans only. The scenario does not change your data. Currencies are not converted.',
        'unknown': 'Unconfirmed',
        'sufficient': 'Sufficient information',
        'partial': 'Partial information',
        'notCalculable': 'Not calculable',
        'sources': 'Sources',
        'methodology': 'Methodology',
        'missing': 'Missing information',
        'projection': 'Projected cash timeline',
        'findings': 'Findings and next steps',
        'empty': 'Not enough information yet. Complete your information to begin.',
        'save': 'Save',
        'delete': 'Delete',
        'edit': 'Edit',
        'cancel': 'Cancel',
        'add': 'Add',
        'retry': 'Retry',
        'saveError':
            'Could not save. Check fields, references and available balance. If another device changed the data, reopen the form.',
        'readError': 'Could not load diagnosis. Retry with a connection.',
        'invalid': 'Check the value',
        'formHint':
            'Save each section to continue later. Amounts represent your personal share. Dates: YYYY-MM-DD; months: YYYY-MM separated by commas.',
        'context': 'Context and data quality',
        'account': 'Account availability and scope',
        'classification': 'Financial classification',
        'plan': 'Plan cash effect',
        'reserve': 'Reserves',
        'goal': 'Goals',
        'debt': 'Debt terms',
        'asset': 'Wealth and investments',
        'coverage': 'Protection',
        'dependents': 'Dependents',
        'incomeStability': 'Income stability',
        'sharedExpensePercent': 'Your share of shared expenses (%)',
        'accountsComplete': 'All my accounts are included',
        'debtsComplete': 'All my debts are included',
        'verifiedOn': 'Balance verification date',
        'completeMonths': 'Complete transaction months',
        'confirmedPlanMonths': 'Confirmed planning months',
        'emergencyMonths': 'Emergency target in months (reference: 3)',
        'currency': 'ISO currency: COP, USD…',
        'grossIncomeMinor': 'Gross monthly income',
        'riskCapacity': 'Capacity to absorb losses',
        'riskTolerance': 'Risk tolerance',
        'accountId': 'Account',
        'availability': 'Availability',
        'excluded': 'Exclude from diagnosis',
        'reason': 'Reason for exclusion',
        'categoryId': 'Category',
        'budgetId': 'Budget identifier (override only)',
        'itemId': 'Item identifier (override only)',
        'essential': 'Essential expense',
        'fixed': 'Fixed',
        'recurring': 'Recurring income',
        'entryId': 'Plan item',
        'effect': 'Cash effect',
        'name': 'Name',
        'amountMinor': 'Target, reserved amount or total value',
        'purpose': 'Single purpose',
        'goalId': 'Funded goal',
        'kind': 'Type',
        'dueDate': 'Target or expiration date',
        'priority': 'Priority (1 is highest)',
        'monthlyContributionMinor': 'Planned monthly contribution',
        'referenceDate': 'Reference or valuation date',
        'rateBps': 'Effective rate (%)',
        'ratePeriod': 'Effective rate period',
        'rateMode': 'Rate type',
        'remainingMonths': 'Remaining months',
        'installmentMinor': 'Contractual monthly installment',
        'statementMonth': 'Statement month',
        'minimumPaymentMinor': 'Statement minimum payment',
        'interestFreePaymentMinor': 'Payment to avoid interest',
        'prepaymentTerms': 'Prepayment terms',
        'prepaymentCostMinor': 'Prepayment cost',
        'ownershipPercent': 'Ownership percentage (value above is total)',
        'assetClass': 'Asset class',
        'obligation': 'Liability',
        'deductibleMinor': 'Deductible',
        'needMinor': 'Declared coverage need',
        'beneficiaries': 'Beneficiaries',
        'yes': 'Yes',
        'no': 'No',
        'stable': 'Stable',
        'variable': 'Variable',
        'low': 'Low',
        'medium': 'Medium',
        'high': 'High',
        'immediate': 'Immediate',
        'restricted': 'Restricted',
        'cash': 'Cash receipt or payment',
        'card': 'Card purchase; no bank outflow',
        'none': 'No cash effect',
        'emergency': 'Emergency',
        'provision': 'Provision',
        'retirement': 'Retirement',
        'tax': 'Taxes',
        'monthlyEffective': 'Monthly effective',
        'annualEffective': 'Annual effective',
        'property': 'Property',
        'vehicle': 'Vehicle',
        'equity': 'Equity',
        'fixedIncome': 'Fixed income',
        'receivable': 'Receivable',
        'result': 'Monthly result',
        'cashFlow': 'Monthly cash flow',
        'freeMoney': 'Free money today',
        'emergencyCoverage': 'Emergency coverage (months)',
        'emergencyTarget': 'Target reserve',
        'debtPressure': 'Debt payments / recurring net income',
        'grossDti': 'DTI on declared gross income',
        'creditUtilization': 'Credit card utilization',
        'debtPrincipal': 'Recorded loan principal',
        'debtCharges': 'Recorded outstanding charges',
        'averageCashFlow': 'Confirmed average monthly cash flow',
        'goalProgress': 'Goal progress',
        'requiredContribution': 'Required monthly contribution, no returns',
        'recordedWealth': 'Recorded net wealth',
        'investmentConcentration': 'Investment share of inventory',
        'coverageGap': 'Declared coverage gap',
        'minimumCash': 'Projected minimum cash by account',
        'cashShortfall': 'Cash shortfall: review payments from this account and their dates.',
        'reservedMoneyNeeded':
            'The plan would use reserved money: adjust expenses, dates or reserves.',
        'reservesExceedBalance': 'Reserves exceed current balance: review their funding.',
        'positiveResultNegativeCash':
            'Positive result with net cash outflow: review principal payments and financing.',
        'unconfirmedPastPayment':
            'Unconfirmed past payment: verify payment and link the transaction.',
        'unallocatedPayment': 'Unallocated payment: complete the allocation to assess debt.',
        'unlinkedMovement': 'Transaction not linked to a plan: review and link if appropriate.',
        'goalContributionGap': 'Planned contributions fall short: review the target or date.',
        'coverageExpired': 'Coverage expired: check renewal.',
        'accountsIncomplete': 'Confirm all accounts are included.',
        'debtsIncomplete': 'Confirm all debts are included.',
        'cached': 'Cached data may be out of date.',
        'pending': 'Changes await confirmation.',
        'staleBalances': 'Verify balances; confirmation is missing or older than 30 days.',
        'historyIncomplete':
            'At least three confirmed complete months are needed for a stable baseline.',
        'classificationIncomplete':
            'Classify essential expenses and recurring income to calculate baselines.',
        'availabilityUnknown': 'Identify accounts with immediate availability.',
        'essentialBaselineMissing': 'A positive essential-expense baseline is missing.',
        'debtTermsMissing':
            'Contractual installments or current minimums are missing; plans are only an estimate.',
        'creditLimitMissing': 'Credit limit is missing.',
        'recurringIncomeMissing': 'Positive confirmed recurring income is missing.',
        'goalOverdue': 'The target date has passed; review the outstanding amount.',
        'wealthInventoryUnconfirmed':
            'Wealth includes recorded items only; check for missing assets or liabilities.',
        'investmentInventoryUnconfirmed': 'Concentration uses inventoried investments only.',
        'coverageNeedMissing': 'Declare coverage needs before assessing adequacy.',
        'pastPaymentsUnconfirmed': 'Past payments require confirmation; they were not rescheduled.',
        'planAccountMissing': 'Assign an account and cash effect to every pending commitment.',
        'planIncomplete': 'The horizon includes months without confirmed planning.',
        'valuations': 'Recorded valuations; not returns',
        'scope':
            'Scope: all active accounts except explicit exclusions. Home visibility does not change diagnosis.',
        'formulaResult': 'Recognized income − recognized net expenses for the month.',
        'formulaCash': 'Sum of cash inflows and outflows; excludes balance adjustments.',
        'formulaFree': 'Immediately available balances − reserves backed by those accounts.',
        'formulaEmergency':
            'Liquid emergency reserve ÷ confirmed average monthly essential expenses.',
        'formulaDebt': 'Mandatory monthly payments ÷ average recurring monthly income × 100.',
        'formulaGoal':
            'Assigned resources and linked provision payments ÷ target; contribution = shortfall ÷ available months, no returns.',
        'formulaWealth':
            'Money and debt balances + attributable external assets − external liabilities; linked accounts count once.',
        'formulaProjection':
            'Current balance + pending receipts − pending payments; releases only the reserve linked to the payment.',
        'formulaOther': 'Calculated from the listed records and references.',
        'linkMovement': 'Link transaction',
        'effectiveAnnualRate': 'Comparable effective annual rate; partial comparison',
        'netProjected': 'Projected free cash',
        'confirmDelete': 'Delete this supplemental record?',
        'itemOverride': 'Override for a plan item (optional)',
        'formulaGross': 'Mandatory monthly payments ÷ declared gross monthly income × 100.',
        'formulaCredit': 'Card debt balance ÷ recorded credit limit × 100.',
        'formulaCoverage':
            'Declared need − active coverage, minimum zero; deductible is reported separately.',
        'formulaConcentration':
            'Attributable investment value ÷ attributable inventoried investment value × 100.',
        'minimumCashTotal': 'Projected minimum cash by currency',
        'minimumFreeTotal': 'Projected minimum free money by currency',
        'recurringSurplus': 'Monthly recurring margin before principal and goals',
        'fixedExpenseShare': 'Fixed expense share',
        'formulaSurplus':
            'Average recurring monthly income − average net monthly expenses; before principal payments and goal contributions.',
        'formulaFixed': 'Net expenses classified as fixed ÷ historical net expenses × 100.',
        'staleValuation': 'Some assets have no valuation within the last 12 months.',
        'allocationIncomplete':
            'Unallocated payments exist: the debt position is incomplete until principal and charges are allocated.',
        'reserveAccountUnavailable':
            'Some reserves refer to archived accounts; review their funding.',
        'other': 'Other',
      },
    );
    return '$_temp0';
  }

  @override
  String get budgetedIncomeActual => 'Received in budgeted categories';

  @override
  String get budgetedExpenseActual => 'Spent in budgeted categories';

  @override
  String get accountsSearch => 'Search accounts';

  @override
  String get accountsSearchClear => 'Clear search';

  @override
  String get accountsSearchEmpty => 'No accounts match your search.';

  @override
  String planningFollowUpText(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'complete': 'Mark as finished',
        'dismiss': 'Stop reminding me this month',
        'snooze': 'Remind me later',
        'resume': 'Resume follow-up',
        'edit': 'Edit plan',
        'menu': 'Follow-up',
        'completed': 'Finished by you',
        'dismissed': 'Removed from follow-up',
        'snoozed': 'Snoozed',
        'reopened': 'The transaction changed. Review this expense.',
        'open': 'To address',
        'saved': 'Follow-up updated',
        'error': 'Could not save the follow-up. Retry with a connection.',
        'conflict': 'The data changed. Refresh this item before trying again.',
        'sourceUnavailable':
            'We couldn\'t confirm that this item is still available. Refresh the plan and reopen it.',
        'generationChanged': 'This screen is out of date. Refresh the item before continuing.',
        'refresh': 'Refresh item',
        'needsRecord': 'Link a confirmed transaction to finish this expense.',
        'dismissInfo':
            'Removes reminders while preserving planned amounts and records. This does not record a payment or reduce debt.',
        'finishInfo':
            'Finish following up on this expense with the transactions already recorded. The planned amount is preserved.',
        'paid': 'Paid',
        'view': 'View agenda',
        'empty': 'No items to address in this period.',
        'partial': 'Information is incomplete. More items may need review.',
        'countPartial': 'Loaded items; the count is provisional.',
        'why': 'Why am I seeing this?',
        'explanation':
            'Shown based on its planned date and linked records. You can finish following up on an expense, remove it or snooze it. Check your statement for final installment amounts.',
        'returnDate': 'Show again on',
        'finishAfterSave': 'Finish follow-up',
        'thisOnly': 'Only this installment',
        'future': 'This and following installments',
        'other': 'Follow-up',
      },
    );
    return '$_temp0';
  }

  @override
  String planningAttentionCount(int count) {
    return '$count items to review';
  }

  @override
  String planningOpenDetail(String item) {
    return 'View details for $item';
  }

  @override
  String planningFollowUpOptions(String item) {
    return 'Follow-up options for $item';
  }

  @override
  String planningFollowUpFor(String item) {
    return 'Follow-up for $item';
  }

  @override
  String get homeWidgetCategoryExpenses => 'Expenses by category';

  @override
  String get homeCategoryExpensesEmpty => 'There are no confirmed expenses this month yet.';

  @override
  String get homeCategoryExpensesIncomplete =>
      'Some transactions are waiting to sync; this summary may change.';

  @override
  String get homeCategoryExpensesOther => 'Other';

  @override
  String get homeCategoryExpensesUncategorized => 'Uncategorized';

  @override
  String get homeWidgetOrder => 'Card order';

  @override
  String get homeSectionTotalBalance => 'Total balance';

  @override
  String get homeSectionCoachPlanning => 'Coach and To address';

  @override
  String get homeSectionMonthlySummary => 'Monthly summary';

  @override
  String get homeSectionCategoryExpenses => 'Expenses by category';

  @override
  String get homeSectionBudgets => 'Budgets';

  @override
  String get homeSectionRecentActivity => 'Recent activity';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get accountIdentityTitle => 'Identification and payment methods';

  @override
  String get accountIdentityOptional => 'Optional. Helps recognize your account on receipts.';

  @override
  String get accountInstitution => 'Institution';

  @override
  String get accountInstitutionCountry => 'Institution country (two-letter code)';

  @override
  String get accountNumberEnding => 'Last four digits of the account';

  @override
  String get identityInvalid => 'Check this value.';

  @override
  String get paymentInstruments => 'Payment methods';

  @override
  String get instrumentName => 'Name to identify it';

  @override
  String get instrumentAdd => 'Add debit card';

  @override
  String get instrumentExplanation =>
      'Linked debit cards use this account’s balance; they do not create an additional balance.';

  @override
  String get instrumentEmpty => 'No payment methods linked yet.';

  @override
  String get instrumentLastFour => 'Last four digits of the card';

  @override
  String get instrumentSaveFailed =>
      'Could not save. Your selection is preserved; check your connection and retry.';

  @override
  String get instrumentRemove => 'Remove payment method';

  @override
  String get instrumentRemoveExplanation =>
      'It will no longer be suggested for receipts. The account and transactions are preserved.';

  @override
  String get documentImportTitle => 'Add an expense from a receipt';

  @override
  String get documentImportExplanation =>
      'We’ll help fill in the expense details. You’ll review them before saving.';

  @override
  String get documentRegisteredOnly => 'Save your account to analyze receipts and view your usage.';

  @override
  String get documentCamera => 'Take photo';

  @override
  String get documentGallery => 'Choose image';

  @override
  String get documentFile => 'Choose PDF';

  @override
  String get documentPreview => 'View receipt';

  @override
  String get documentOffline =>
      'You need an internet connection to analyze this document. Your draft is preserved; you can retry when you are connected.';

  @override
  String get documentAnalyzing => 'Reading your receipt…';

  @override
  String get documentAnalyze => 'Prepare expense';

  @override
  String get documentPrepareExpense => 'Prepare expense';

  @override
  String get documentPreparingExpense => 'Preparing your expense…';

  @override
  String get documentChangingReceiptProgress => 'Changing receipt…';

  @override
  String get documentChangeReceipt => 'Change receipt';

  @override
  String get documentMoreOptions => 'More options';

  @override
  String get documentMoreDetails => 'More details';

  @override
  String get documentSeeUsage => 'View my usage';

  @override
  String get documentTypeImage => 'Image';

  @override
  String get documentTypePdf => 'PDF';

  @override
  String documentFileSize(String size) {
    return '$size';
  }

  @override
  String get documentReplacementTitle => 'Use this receipt instead?';

  @override
  String get documentReplacementBody =>
      'Your current receipt stays safe until the new one is saved. If you cancel or something goes wrong, you can keep using the current one.';

  @override
  String get documentKeepCurrent => 'Keep current';

  @override
  String get documentUseNew => 'Use new receipt';

  @override
  String documentUsageAvailable(int available) {
    return '$available analyses remaining';
  }

  @override
  String get documentUsageUnavailable => 'We couldn’t check your usage right now.';

  @override
  String documentQuotaRenewalAt(String date) {
    return 'Your allowance renews on $date.';
  }

  @override
  String get documentCloudSummary =>
      'We’ll use cloud AI to read the receipt. Review the details before saving; the analysis counts toward your allowance.';

  @override
  String get documentCloudDetails =>
      'When saved, the receipt is attached to the expense. Unconfirmed drafts expire after 24 hours and are removed during periodic cleanup.';

  @override
  String get documentManualDraftNote =>
      'The receipt will remain in this draft and won’t be attached to the manual entry.';

  @override
  String get documentCloudTitle => 'Cloud analysis';

  @override
  String get documentCloudConsent =>
      'We will send this document to our cloud AI service to extract its details. Always review suggestions. Each completed analysis, including an unsupported document, counts toward your limit. Saving the expense keeps the receipt as an attachment. Unconfirmed files expire after 24 hours and are removed by periodic cleanup.';

  @override
  String get documentUnsupported =>
      'This document cannot prepare a single expense. You can enter it manually.';

  @override
  String get documentAlreadyImported => 'This receipt is already linked to a transaction.';

  @override
  String get documentOpenExisting => 'Open existing transaction';

  @override
  String get documentReview => 'Review expense';

  @override
  String get documentDiscard => 'Discard document';

  @override
  String get documentDiscardExplanation =>
      'The draft will be deleted and the temporary file queued for deletion. No transaction will be created.';

  @override
  String get documentManual => 'Enter manually';

  @override
  String get documentRetryError =>
      'We could not complete the action. Your draft is preserved; try again.';

  @override
  String get documentFileInvalid =>
      'Unsupported file. Use an image up to 5 MB or a password-free PDF up to 10 MB and three pages.';

  @override
  String get documentQuotaExceeded =>
      'You reached your analysis limit. Check the next renewal under Usage and storage.';

  @override
  String get documentStorageFull =>
      'There is not enough space to keep this receipt. Manage your attachments or enter the expense manually.';

  @override
  String get documentServiceDisabled =>
      'Document analysis is currently unavailable. You can enter the expense manually.';

  @override
  String get documentExpired =>
      'This draft expired or belongs to data from before a reset. Upload the document again.';

  @override
  String get documentDeviceVerification =>
      'We could not verify this installation. Update the app and try again.';

  @override
  String get documentSuggested =>
      'Suggested details. Review amount, currency, date, category and account before saving.';

  @override
  String get documentPerformed => 'I confirm I already made this expense';

  @override
  String get documentNotPaid =>
      'If you have not paid yet, you can plan it without recording money out.';

  @override
  String get documentPlanInstead => 'Go to Plan';

  @override
  String get documentDuplicateTitle => 'Possible duplicate';

  @override
  String get documentDuplicateBody =>
      'A transaction has similar details. Review Activity before continuing.';

  @override
  String get documentSaveAnyway => 'Save anyway';

  @override
  String get resourceUsageTitle => 'Usage and storage';

  @override
  String documentQuotaUsage(int dailyUsed, int dailyLimit, int monthlyUsed, int monthlyLimit) {
    return 'Analyses today: $dailyUsed of $dailyLimit · This month: $monthlyUsed of $monthlyLimit';
  }

  @override
  String documentQuotaRenews(String date) {
    return 'Daily limit renews: $date';
  }

  @override
  String documentMonthlyRenews(String date) {
    return 'Monthly limit renews: $date';
  }

  @override
  String documentStorageUsage(String used, String limit) {
    return 'Attachments: $used of $limit';
  }

  @override
  String documentTemporaryUsage(String used) {
    return 'Temporary files: $used';
  }

  @override
  String get documentAttachments => 'Saved receipts';

  @override
  String get documentAttachmentsEmpty => 'No saved receipts.';

  @override
  String get documentReceipt => 'Attached receipt';

  @override
  String get documentDelete => 'Delete';

  @override
  String get documentDeleteAttachment => 'Delete attachment';

  @override
  String get documentDeleteExplanation =>
      'Only the file will be deleted. The transaction, amounts and financial effect are preserved. Space is freed when deletion is confirmed.';

  @override
  String get documentReadError => 'Could not open the receipt. Check your connection and retry.';

  @override
  String get documentDraftUnavailable =>
      'We could not save the draft on this device. Check available storage and try again before sending the document.';

  @override
  String get documentDateRequired =>
      'The receipt has no clear date. Choose the expense date before saving.';

  @override
  String get documentStartAnother => 'Analyze another document';

  @override
  String get documentViewReceipt => 'View receipt';

  @override
  String get documentReceiptOptions => 'Receipt options';

  @override
  String get sharedReceiptTitle => 'Shared file';

  @override
  String get sharedReceiptOneFile => 'Share one image or PDF at a time.';

  @override
  String get sharedReceiptBusy =>
      'Finish or discard the current shared file before sending another.';

  @override
  String get sharedReceiptSignIn =>
      'To analyze this receipt, sign in or save your guest account. The file stays on this device.';

  @override
  String sharedReceiptConfirmAccount(String account) {
    return 'Prepare this expense in account $account?';
  }

  @override
  String get sharedReceiptContinue => 'Continue';

  @override
  String get sharedReceiptConflictTitle => 'You already have a receipt in progress';

  @override
  String get sharedReceiptConflictBody =>
      'Keep the current draft or discard it to use the new file. No transaction will be created.';

  @override
  String get sharedReceiptKeep => 'Keep current';

  @override
  String get sharedReceiptReplace => 'Use new file';

  @override
  String get sharedReceiptRetry =>
      'We could not open the new file. The shared file and available draft are preserved; you can retry.';

  @override
  String get documentFieldSuggested => 'Suggested from the receipt';

  @override
  String get documentFieldNeedsReview => 'Review';

  @override
  String get documentFieldUserProvided => 'Your choice';

  @override
  String documentCurrencyMismatch(String accountCurrency, String receiptCurrency) {
    return 'The account uses $accountCurrency; the receipt suggests $receiptCurrency. Check the amount and currency.';
  }

  @override
  String get documentServiceBusy =>
      'The analysis service is busy. Your receipt is preserved; try again in a few minutes.';

  @override
  String get documentAnalysisTimedOut =>
      'The analysis took too long. Your receipt is preserved; you can try again.';

  @override
  String get documentAnalysisFailed =>
      'We could not analyze the receipt. Your draft is preserved; try again.';

  @override
  String get documentResponseTimedOut =>
      'We could not confirm the result. Your draft is preserved. Retrying will check whether the analysis has already finished.';

  @override
  String get documentAnalysisTakingLonger =>
      'This is taking longer than usual. Your receipt is saved. Wait for the result; you do not need to send it again.';

  @override
  String get settingsYourAccount => 'Your account';

  @override
  String get settingsGuestSession => 'You are using a guest session';

  @override
  String get settingsEmailUnavailable => 'Email unavailable';

  @override
  String settingsMemberSince(String date) {
    return 'With LumioMoney since $date';
  }

  @override
  String settingsSignOutAccount(String email) {
    return 'You are signing out of $email.';
  }

  @override
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String get deletionTitle => 'Delete my account';

  @override
  String get deletionExplanation =>
      'Permanently delete your account, financial data, attachments and identifiable usage history. This is different from resetting your data. Pending local records will be discarded after your request is accepted.';

  @override
  String get deletionConfirmation => 'I understand that this cannot be undone.';

  @override
  String get deletionSubmit => 'Request permanent deletion';

  @override
  String get deletionAccepted =>
      'Your deletion request was accepted. Your account is blocked while deletion finishes.';

  @override
  String get deletionFailed =>
      'We could not confirm your request. Your data has not been cleared on this device. Try again.';

  @override
  String get deletionPassword => 'Confirm your password';

  @override
  String get quarantineMessage =>
      'Some older local records have no verifiable owner. They are blocked and will not be sent.';

  @override
  String get quarantineDiscard => 'Discard blocked local records';

  @override
  String get quarantineConfirm =>
      'Discard these unverified local records? This does not change any confirmed movements.';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get supportTitle => 'Support';

  @override
  String get deletionChanged =>
      'The account data changed. Reload it before requesting deletion again.';

  @override
  String get deletionReload => 'Reload account data';

  @override
  String get accessMethodsTitle => 'Sign-in methods';

  @override
  String get accessMethodsIntro =>
      'These are the ways to sign in to this account. Your data belongs to your account, not the sign-in method.';

  @override
  String get accessPassword => 'Email and password';

  @override
  String get accessLinked => 'Linked';

  @override
  String get accessEmailUnverified => 'Email verification pending';

  @override
  String get accessEmailUnknown => 'Verification status needs refreshing';

  @override
  String get accessAdd => 'Add sign-in method';

  @override
  String get accessRefreshError =>
      'We could not refresh your methods. The displayed information may have changed. Retry before adding another.';

  @override
  String get accessRetry => 'Retry';

  @override
  String get accessUnknown => 'Refresh to view your sign-in methods.';

  @override
  String get accessReauth => 'Confirm your identity';

  @override
  String get accessReauthMethod => 'Current method to confirm';

  @override
  String get accessCurrentPassword => 'Current password';

  @override
  String get accessNewPassword => 'New password';

  @override
  String get accessRepeatPassword => 'Confirm new password';

  @override
  String get accessPasswordInvalid => 'Use at least 8 characters and repeat the same password.';

  @override
  String get accessCurrentRequired => 'Enter your current password.';

  @override
  String get accessConfirm => 'Confirm and link';

  @override
  String get accessCancel => 'Cancel';

  @override
  String get accessConsent =>
      'I agree to associate my Apple account with this other sign-in method, which may share my real email.';

  @override
  String get accessConsentRequired => 'Confirm that you agree to this association.';

  @override
  String get accessPrivateEmail =>
      'A password requires a personal email. For now, continue with Apple or add Google; changing email will be available later.';

  @override
  String get accessSuccess => 'Method added. You can now use it to sign in to this account.';

  @override
  String get accessVerificationFailed =>
      'The method is linked, but we could not send email verification. You can retry sending it.';

  @override
  String get accessVerificationSent => 'We sent a verification email. You can keep using the app.';

  @override
  String get accessSendVerification => 'Send verification';

  @override
  String get accessConflict =>
      'This credential belongs to another account. Try another or cancel; your current session is preserved.';

  @override
  String get accessSessionChanged =>
      'Your session changed. Close this window and view the current account’s methods again.';

  @override
  String get accessNetworkError => 'We could not connect. Your entries are preserved; try again.';

  @override
  String get accessCredentialError =>
      'We could not confirm your identity with that method. Check your details or choose another linked method.';

  @override
  String get accessGenericError =>
      'We could not confirm the link. Retry to check its status before submitting again.';

  @override
  String get accessLinkIntro =>
      'You will add another way to sign in to this account. First, confirm your identity with an already linked method.';

  @override
  String get accessUnverifiedPasswordWarning =>
      'If your email is not verified, Firebase may replace password access when confirming Google or Apple. You can add a new password afterwards.';

  @override
  String get accessPasswordReplaced =>
      'Your previous password is no longer listed as a sign-in method. You can add a new one from this screen.';

  @override
  String get documentUploadRequired =>
      'The file was not fully uploaded. Your draft is preserved; retry the upload.';

  @override
  String get documentSourceUnavailable =>
      'We could not access the uploaded file. Your draft is preserved; try again.';
}
