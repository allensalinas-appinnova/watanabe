import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/finance/data/datasources/finance_remote_data_source.dart';
import 'package:personal_finance/features/finance/data/repositories/finance_repository_impl.dart';

class _MockFinanceRemoteDataSource extends Mock implements FinanceRemoteDataSource {}

void main() {
  late _MockFinanceRemoteDataSource remoteDataSource;
  late FinanceRepositoryImpl repository;

  setUp(() {
    remoteDataSource = _MockFinanceRemoteDataSource();
    repository = FinanceRepositoryImpl(remoteDataSource: remoteDataSource);
  });

  group('updateBudgetLimits', () {
    const userId = 'user-123';
    const limits = {'food': 650000.0, 'housing': 1450000.0};

    test('writes all limits and returns success', () async {
      when(
        () => remoteDataSource.updateBudgetLimits(userId, limits),
      ).thenAnswer((_) async {});

      final result = await repository.updateBudgetLimits(userId, limits);

      expect(result, const Right<Failure, Unit>(unit));
      verify(
        () => remoteDataSource.updateBudgetLimits(userId, limits),
      ).called(1);
    });

    test('maps remote errors to a domain failure', () async {
      when(
        () => remoteDataSource.updateBudgetLimits(userId, limits),
      ).thenThrow(StateError('offline'));

      final result = await repository.updateBudgetLimits(userId, limits);

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<UnknownFailure>());
    });
  });
}
