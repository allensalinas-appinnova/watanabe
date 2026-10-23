import '../../../../core/error/failure.dart';
import '../../../finance/domain/entities/activity_report.dart';
import '../../../finance/domain/entities/financial_operation.dart';

export '../../../finance/domain/entities/activity_report.dart' show ActivityCurrencyTotals;

class CoachPreferences {
  const CoachPreferences({
    this.dailyEnabled = false,
    this.weeklyEnabled = false,
    this.dailyHour = 20,
    this.dailyMinute = 30,
    this.dailyWeekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.weeklyWeekday = 1,
    this.weeklyHour = 9,
    this.weeklyMinute = 0,
    this.hasPendingWrites = false,
  });

  factory CoachPreferences.fromMap(Object? value, {bool hasPendingWrites = false}) {
    if (value is! Map) return CoachPreferences(hasPendingWrites: hasPendingWrites);
    int bounded(String key, int fallback, int min, int max) {
      final v = value[key];
      return v is int && v >= min && v <= max ? v : fallback;
    }

    final days = value['dailyWeekdays'];
    return CoachPreferences(
      hasPendingWrites: hasPendingWrites,
      dailyEnabled: value['dailyEnabled'] == true,
      weeklyEnabled: value['weeklyEnabled'] == true,
      dailyHour: bounded('dailyHour', 20, 0, 23),
      dailyMinute: bounded('dailyMinute', 30, 0, 59),
      dailyWeekdays: days is List
          ? Set.unmodifiable(days.whereType<int>().where((day) => day >= 1 && day <= 7))
          : const {1, 2, 3, 4, 5, 6, 7},
      weeklyWeekday: bounded('weeklyWeekday', 1, 1, 7),
      weeklyHour: bounded('weeklyHour', 9, 0, 23),
      weeklyMinute: bounded('weeklyMinute', 0, 0, 59),
    );
  }

  final bool dailyEnabled;
  final bool weeklyEnabled;
  final int dailyHour;
  final int dailyMinute;
  final Set<int> dailyWeekdays;
  final int weeklyWeekday;
  final int weeklyHour;
  final int weeklyMinute;

  /// Snapshot metadata only; never persisted with the preference fields.
  final bool hasPendingWrites;

  Map<String, Object?> toMap() => {
    'dailyEnabled': dailyEnabled,
    'weeklyEnabled': weeklyEnabled,
    'dailyHour': dailyHour,
    'dailyMinute': dailyMinute,
    'dailyWeekdays': dailyWeekdays.toList()..sort(),
    'weeklyWeekday': weeklyWeekday,
    'weeklyHour': weeklyHour,
    'weeklyMinute': weeklyMinute,
  };

  CoachPreferences copyWith({
    bool? dailyEnabled,
    bool? weeklyEnabled,
    int? dailyHour,
    int? dailyMinute,
    Set<int>? dailyWeekdays,
    int? weeklyWeekday,
    int? weeklyHour,
    int? weeklyMinute,
  }) => CoachPreferences(
    dailyEnabled: dailyEnabled ?? this.dailyEnabled,
    weeklyEnabled: weeklyEnabled ?? this.weeklyEnabled,
    dailyHour: dailyHour ?? this.dailyHour,
    dailyMinute: dailyMinute ?? this.dailyMinute,
    dailyWeekdays: Set.unmodifiable(dailyWeekdays ?? this.dailyWeekdays),
    weeklyWeekday: weeklyWeekday ?? this.weeklyWeekday,
    weeklyHour: weeklyHour ?? this.weeklyHour,
    weeklyMinute: weeklyMinute ?? this.weeklyMinute,
    hasPendingWrites: hasPendingWrites,
  );
}

enum CoachReviewKind { daily, weekly }

enum CoachWriteState { confirmed, pending }

class CoachWriteFailure {
  const CoachWriteFailure({required this.failure, required this.commandKey});

  final Failure failure;
  final String commandKey;
}

class CoachCompletion {
  const CoachCompletion({
    required this.periodKey,
    required this.kind,
    this.noMovements = false,
    this.reviewedAt,
    this.pending = false,
  });

  final String periodKey;
  final CoachReviewKind kind;
  final bool noMovements;
  final DateTime? reviewedAt;
  final bool pending;
}

enum CoachFreshness { fresh, cached }

class CoachCategoryTotal {
  const CoachCategoryTotal({
    required this.categoryId,
    required this.amountMinor,
    required this.currency,
  });

  final String categoryId;
  final int amountMinor;
  final String currency;
}

class CoachPeriodReport {
  CoachPeriodReport({
    required this.startAt,
    required this.endAtExclusive,
    required List<FinancialOperation> operations,
    required this.freshness,
  }) : operations = List.unmodifiable(operations);

  final DateTime startAt;
  final DateTime endAtExclusive;
  final List<FinancialOperation> operations;
  final CoachFreshness freshness;

  Map<String, ActivityCurrencyTotals> get totalsByCurrency =>
      Map.unmodifiable(ActivityReport.fromOperations(operations).totalsByCurrency);

  /// Confirmed spending categories, descending by amount with stable ties.
  Map<String, List<CoachCategoryTotal>> get topCategoriesByCurrency {
    final amounts = <String, Map<String, int>>{};
    for (final operation in operations) {
      if (operation.status != OperationStatus.confirmed ||
          (operation.type != OperationType.expense &&
              operation.type != OperationType.expenseRefund) ||
          operation.categoryId == null) {
        continue;
      }
      amounts
          .putIfAbsent(operation.currency, () => {})
          .update(
            operation.categoryId!,
            (v) => v + operation.recognizedExpenseMinor,
            ifAbsent: () => operation.recognizedExpenseMinor,
          );
    }
    return Map.unmodifiable({
      for (final entry in amounts.entries)
        entry.key: List<CoachCategoryTotal>.unmodifiable(
          entry.value.entries
              .where((category) => category.value > 0)
              .map(
                (category) => CoachCategoryTotal(
                  categoryId: category.key,
                  amountMinor: category.value,
                  currency: entry.key,
                ),
              )
              .toList()
            ..sort((a, b) {
              final amount = b.amountMinor.compareTo(a.amountMinor);
              return amount == 0 ? a.categoryId.compareTo(b.categoryId) : amount;
            }),
        ),
    });
  }

  int get confirmedCount => _count(OperationStatus.confirmed);
  int get pendingCount => _count(OperationStatus.pending);
  int get rejectedCount => _count(OperationStatus.rejected);
  int _count(OperationStatus status) =>
      ActivityReport.groupOperations(operations.where((v) => v.status == status)).length;
}
