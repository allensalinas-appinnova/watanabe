import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_access_method.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_account_link_result.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/domain/repositories/auth_repository.dart';
import 'package:personal_finance/features/auth/domain/use_cases/link_registered_access_method.dart';

class _Repository extends Mock implements AuthRepository {}

void main() {
  const user = AuthUser(
    id: 'owner',
    isAnonymous: false,
    email: 'qa@example.test',
    providerIds: ['password'],
  );
  const command = LinkAccessMethodCommand(expectedUid: 'owner', method: AuthAccessMethod.google);
  late _Repository repo;
  setUpAll(() {
    registerFallbackValue(command);
  });
  setUp(() {
    repo = _Repository();
    when(() => repo.currentUser).thenReturn(user);
    when(
      () => repo.refreshAccessMethods(expectedUid: 'owner'),
    ).thenAnswer((_) async => const Right(user));
  });
  Future<Either<Failure, AuthAccountLinkResult>> run() => LinkRegisteredAccessMethod(repo)(
    expectedUser: user,
    reauthenticateWith: AuthAccessMethod.password,
    currentPassword: 'Synthetic123!',
    command: command,
  );
  test(
    'lost response recovery returns existing link without another authentication or mutation',
    () async {
      when(
        () => repo.refreshAccessMethods(expectedUid: 'owner'),
      ).thenAnswer((_) async => Right(user.copyWith(providerIds: ['password', 'google.com'])));
      expect((await run()).isRight(), true);
      verifyNever(
        () => repo.reauthenticateForLinking(
          expectedUid: 'owner',
          method: AuthAccessMethod.password,
          password: any(named: 'password'),
        ),
      );
      verifyNever(() => repo.addAccessMethod(any()));
    },
  );
  test('session switch during reauthentication stops linking', () async {
    when(
      () => repo.reauthenticateForLinking(
        expectedUid: 'owner',
        method: AuthAccessMethod.password,
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      when(() => repo.currentUser).thenReturn(user.copyWith(id: 'other'));
      return const Right(unit);
    });
    expect((await run()).getLeft().toNullable()?.technicalCode, 'user-mismatch');
    verifyNever(() => repo.addAccessMethod(any()));
  });
  test('session switch before request stops refresh', () async {
    when(() => repo.currentUser).thenReturn(null);
    expect((await run()).isLeft(), true);
    verifyNever(() => repo.refreshAccessMethods(expectedUid: 'owner'));
  });
  test('failed refresh does not start linking or reauthentication', () async {
    when(
      () => repo.refreshAccessMethods(expectedUid: 'owner'),
    ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
    expect((await run()).getLeft().toNullable(), isA<NetworkFailure>());
    verifyNever(() => repo.addAccessMethod(any()));
  });
  test('reauthentication failure preserves session and does not send a link', () async {
    when(
      () => repo.reauthenticateForLinking(
        expectedUid: 'owner',
        method: AuthAccessMethod.password,
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const Left(AuthFailure('cancelled', technicalCode: 'web-context-canceled')),
    );
    expect((await run()).getLeft().toNullable()?.technicalCode, 'web-context-canceled');
    verifyNever(() => repo.addAccessMethod(any()));
  });
  test('owner change after committed link is not reported as success to new session', () async {
    when(
      () => repo.reauthenticateForLinking(
        expectedUid: 'owner',
        method: AuthAccessMethod.password,
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Right(unit));
    when(() => repo.addAccessMethod(command)).thenAnswer((_) async {
      when(() => repo.currentUser).thenReturn(null);
      return const Right(AuthAccountLinkResult(user: user));
    });
    expect((await run()).getLeft().toNullable()?.technicalCode, 'user-mismatch');
  });
  test('email changed elsewhere requires showing refreshed email before adding password', () async {
    when(() => repo.refreshAccessMethods(expectedUid: 'owner')).thenAnswer(
      (_) async => Right(user.copyWith(email: 'new@example.test', providerIds: ['google.com'])),
    );
    final result = await LinkRegisteredAccessMethod(repo)(
      expectedUser: user,
      reauthenticateWith: AuthAccessMethod.google,
      command: const LinkAccessMethodCommand(
        expectedUid: 'owner',
        method: AuthAccessMethod.password,
        password: 'Synthetic123!',
      ),
    );
    expect(result.getLeft().toNullable()?.technicalCode, 'access-details-changed');
  });
}
