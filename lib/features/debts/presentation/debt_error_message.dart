import '../../../core/error/failure.dart';
import '../../../l10n/generated/app_localizations.dart';

String debtErrorMessage(AppLocalizations l, Failure failure) => switch (failure.message) {
  'debt-feature-disabled' => l.debtDisabled,
  'debt-connection-required' => l.debtOnline,
  'debt-session-expired' => l.sessionExpired,
  'debt-payment-split-required' || 'debt-invalid-amount' => l.debtErrorSplit,
  'debt-inconsistent-components' => l.debtErrorComponents,
  'debt-refund-exceeds-purchase' ||
  'debt-purchase-required' ||
  'debt-purchase-reversed' ||
  'debt-purchase-has-refunds' => l.debtErrorRefund,
  'debt-before-opening' || 'debt-invalid-date' || 'debt-invalid-refund-date' => l.debtErrorDate,
  'debt-balance-not-zero' => l.debtErrorArchive,
  'debt-bank-incompatible' ||
  'debt-category-incompatible' ||
  'debt-budget-incompatible' ||
  'debt-account-inactive' => l.debtErrorReference,
  _ => l.genericError,
};
