import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/coach/domain/entities/coach_models.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';

void main() {
  test('routine preferences preserve explicit choice and infer legacy reminder choice', () {
    final legacy = CoachRoutinePreferences.fromProfile(
      null,
      legacy: const CoachPreferences(dailyEnabled: true),
    );
    expect(legacy.configured, isTrue);
    expect(legacy.dailyEnabled, isTrue);
    expect(legacy.weeklyEnabled, isFalse);

    final explicit = CoachRoutinePreferences.fromProfile(
      const {'configured': true, 'dailyEnabled': false, 'weeklyEnabled': true},
      legacy: const CoachPreferences(dailyEnabled: true),
    );
    expect(explicit.configured, isTrue);
    expect(explicit.dailyEnabled, isFalse);
    expect(explicit.weeklyEnabled, isTrue);
    expect(CoachRoutinePreferences.fromProfile(null).configured, isFalse);
    expect(CoachRoutinePreferences.fromProfile(explicit.toMap()).toMap(), explicit.toMap());
  });

  test('pending metadata is transient, preserved by copyWith, and never deserialized as data', () {
    const defaults = CoachPreferences();
    expect(defaults.hasPendingWrites, false);
    final pending = CoachPreferences.fromMap(defaults.toMap(), hasPendingWrites: true);
    expect(pending.hasPendingWrites, true);
    expect(pending.copyWith(dailyEnabled: true).hasPendingWrites, true);
    expect(pending.toMap(), defaults.toMap());
    expect(pending.toMap().containsKey('hasPendingWrites'), false);
    expect(CoachPreferences.fromMap(null, hasPendingWrites: true).hasPendingWrites, true);
    expect(CoachPreferences.fromMap({'hasPendingWrites': true}).hasPendingWrites, false);
  });

  test('preferences default disabled and round trip exact rules map', () {
    const defaults = CoachPreferences();
    expect(defaults.toMap(), {
      'dailyEnabled': false,
      'weeklyEnabled': false,
      'dailyHour': 20,
      'dailyMinute': 30,
      'dailyWeekdays': [1, 2, 3, 4, 5, 6, 7],
      'weeklyWeekday': 1,
      'weeklyHour': 9,
      'weeklyMinute': 0,
    });
    expect(CoachPreferences.fromMap(null).toMap(), defaults.toMap());
    final changed = defaults.copyWith(
      dailyEnabled: true,
      dailyWeekdays: {5, 1},
      weeklyEnabled: true,
      dailyHour: 18,
      dailyMinute: 15,
      weeklyWeekday: 7,
      weeklyHour: 10,
      weeklyMinute: 45,
    );
    expect(CoachPreferences.fromMap(changed.toMap()).toMap(), changed.toMap());
    expect(changed.toMap()['dailyWeekdays'], [1, 5]);
    expect(defaults.dailyEnabled, false);
  });

  test('invalid preference values use bounded defaults; empty weekdays survives', () {
    final prefs = CoachPreferences.fromMap({
      'dailyHour': 24,
      'dailyMinute': -1,
      'weeklyWeekday': 8,
      'weeklyHour': '9',
      'weeklyMinute': 60,
      'dailyWeekdays': [0, 8, '1'],
    });
    expect(prefs.dailyHour, 20);
    expect(prefs.dailyMinute, 30);
    expect(prefs.weeklyWeekday, 1);
    expect(prefs.weeklyHour, 9);
    expect(prefs.weeklyMinute, 0);
    expect(prefs.dailyWeekdays, isEmpty);
    expect(CoachPreferences.fromMap(prefs.toMap()).dailyWeekdays, isEmpty);
  });

  test('report separates currencies, excludes transfers and unconfirmed money', () {
    FinancialOperation op(
      String id,
      OperationType type,
      int amount, {
      String currency = 'COP',
      OperationStatus status = OperationStatus.confirmed,
      String? category = 'food',
    }) => FinancialOperation(
      id: id,
      type: type,
      amountMinor: amount,
      currency: currency,
      monthKey: '2026-10',
      occurredAt: DateTime(2026, 10, 22),
      status: status,
      idempotencyKey: id,
      categoryId: category,
    );
    final source = [
      op('income', OperationType.income, 1000),
      op('food', OperationType.expense, 100),
      op('food2', OperationType.expense, 50),
      op('rent', OperationType.expense, 150, category: 'rent'),
      op('usd', OperationType.expense, 20, currency: 'USD'),
      op('transfer', OperationType.transfer, 900),
      op('pending', OperationType.expense, 800, status: OperationStatus.pending),
      op('rejected', OperationType.income, 700, status: OperationStatus.rejected),
    ];
    final report = CoachPeriodReport(
      startAt: DateTime(2026, 10, 19),
      endAtExclusive: DateTime(2026, 10, 26),
      operations: source,
      freshness: CoachFreshness.cached,
    );
    source.clear();
    expect(report.operations, hasLength(8));
    expect(report.confirmedCount, 6);
    expect(report.pendingCount, 1);
    expect(report.rejectedCount, 1);
    expect(report.totalsByCurrency['COP']!.incomeMinor, 1000);
    expect(report.totalsByCurrency['COP']!.expenseMinor, 300);
    expect(report.totalsByCurrency['COP']!.netMinor, 700);
    expect(report.totalsByCurrency['USD']!.netMinor, -20);
    expect(report.topCategoriesByCurrency['COP']!.map((v) => v.categoryId), ['food', 'rent']);
    expect(report.topCategoriesByCurrency['COP']!.first.amountMinor, 150);
    expect(report.topCategoriesByCurrency['USD']!.single.currency, 'USD');
  });
}
