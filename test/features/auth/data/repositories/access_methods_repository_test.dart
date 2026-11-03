import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:personal_finance/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:personal_finance/features/auth/data/models/auth_user_model.dart';
import 'package:personal_finance/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_access_method.dart';

class _Remote extends Mock implements AuthRemoteDataSource {}

class _Local extends Mock implements AuthLocalDataSource {}

void main() {
  const user = AuthUserModel(
    id: 'owner',
    isAnonymous: false,
    email: 'owner@example.test',
    providerIds: ['apple.com', 'password'],
    emailVerified: false,
  );
  const command = LinkAccessMethodCommand(
    expectedUid: 'owner',
    method: AuthAccessMethod.password,
    password: 'Synthetic123!',
  );
  late _Remote remote;
  late _Local local;
  late AuthRepositoryImpl repo;
  setUpAll(() {
    registerFallbackValue(command);
    registerFallbackValue(user);
  });
  setUp(() {
    remote = _Remote();
    local = _Local();
    repo = AuthRepositoryImpl(remoteDataSource: remote, localDataSource: local);
    when(() => remote.currentUser).thenReturn(user);
    when(() => local.cacheUser(any())).thenAnswer((_) async {});
  });
  test('refresh returns verified provider data and caches only the owner', () async {
    when(() => remote.refreshAccessMethods(expectedUid: 'owner')).thenAnswer((_) async => user);
    final result = await repo.refreshAccessMethods(expectedUid: 'owner');
    expect(result.getRight().toNullable()?.providerIds, ['apple.com', 'password']);
    verify(() => local.cacheUser(user)).called(1);
  });
  test('changed owner rejects refresh and does not cache stale identity', () async {
    when(
      () => remote.refreshAccessMethods(expectedUid: 'owner'),
    ).thenAnswer((_) async => user.copyWith(id: 'other'));
    expect(
      (await repo.refreshAccessMethods(expectedUid: 'owner')).getLeft().toNullable()?.technicalCode,
      'user-mismatch',
    );
    verifyNever(() => local.cacheUser(any()));
  });
  test('verification delivery failure does not undo an already linked password', () async {
    when(() => remote.addAccessMethod(command)).thenAnswer((_) async => user);
    when(
      () => remote.sendEmailVerification(),
    ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));
    final result = (await repo.addAccessMethod(command)).getRight().toNullable()!;
    expect(result.user.id, 'owner');
    expect(result.emailVerificationSent, false);
    verifyNever(() => remote.signOut());
  });
  test('verified email does not send another verification', () async {
    when(
      () => remote.addAccessMethod(command),
    ).thenAnswer((_) async => user.copyWith(emailVerified: true));
    expect((await repo.addAccessMethod(command)).isRight(), true);
    verifyNever(() => remote.sendEmailVerification());
  });
  test('conflict preserves code and does not change auth or cache', () async {
    when(
      () => remote.addAccessMethod(command),
    ).thenThrow(FirebaseAuthException(code: 'credential-already-in-use'));
    expect(
      (await repo.addAccessMethod(command)).getLeft().toNullable()?.technicalCode,
      'credential-already-in-use',
    );
    verifyNever(() => remote.signOut());
    verifyNever(() => local.cacheUser(any()));
  });
  test('link reauthentication never calls deletion or guest linking contracts', () async {
    when(
      () => remote.reauthenticateForLinking(expectedUid: 'owner', method: AuthAccessMethod.apple),
    ).thenAnswer((_) async {});
    expect(
      (await repo.reauthenticateForLinking(
        expectedUid: 'owner',
        method: AuthAccessMethod.apple,
      )).isRight(),
      true,
    );
    verifyNever(() => remote.reauthenticateForDeletion(password: any(named: 'password')));
    verifyNever(() => remote.linkApple());
  });
}
