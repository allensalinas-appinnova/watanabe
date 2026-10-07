import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/firebase/firebase_observability.dart';

void main() {
  test('product analytics event names are allowlisted without payloads', () {
    expect(
      FirebaseObservability.allowedEventNames,
      {
        'onboarding_completed',
        'account_created',
        'income_created',
        'expense_created',
        'budget_created',
        'transfer_created',
        'sync_rejected',
      },
    );
  });

  test('Crashlytics technical errors serialize only an allowlisted code', () {
    const error = SafeTechnicalFailure(TechnicalErrorCode.sync);

    expect(error.toString(), 'technical_failure:sync');
    expect(error.toString(), isNot(contains('COP')));
    expect(error.toString(), isNot(contains('amount')));
  });
}
