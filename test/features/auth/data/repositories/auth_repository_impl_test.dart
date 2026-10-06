import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:personal_finance/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:personal_finance/features/auth/data/models/auth_user_model.dart';
import 'package:personal_finance/features/auth/data/repositories/auth_repository_impl.dart';

class _MockRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class _MockLocalDataSource extends Mock implements AuthLocalDataSource {}

void main() {
  late _MockRemoteDataSource remoteDataSource;
  late _MockLocalDataSource localDataSource;
  late AuthRepositoryImpl repository;

  const user = AuthUserModel(
    id: 'user-123',
    email: 'person@example.test',
    displayName: 'Test User',
    isAnonymous: false,
  );

  setUp(() {
    remoteDataSource = _MockRemoteDataSource();
    localDataSource = _MockLocalDataSource();
    repository = AuthRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
    );
  });

  test('exposes the current Firebase session without using cached state', () {
    when(() => remoteDataSource.currentUser).thenReturn(user);

    expect(repository.currentUser?.id, user.id);
  });

  group('signIn', () {
    test('maps the remote model to a domain entity and caches it', () async {
      when(
        () => remoteDataSource.signIn(
          email: 'person@example.test',
          password: 'password123',
        ),
      ).thenAnswer((_) async => user);
      when(() => localDataSource.cacheUser(user)).thenAnswer((_) async {});

      final result = await repository.signIn(
        email: 'person@example.test',
        password: 'password123',
      );

      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()?.id, 'user-123');
      verify(() => localDataSource.cacheUser(user)).called(1);
    });

    test('maps remote errors to a domain failure', () async {
      when(
        () => remoteDataSource.signIn(
          email: 'person@example.test',
          password: 'wrong-password',
        ),
      ).thenThrow(StateError('offline'));

      final result = await repository.signIn(
        email: 'person@example.test',
        password: 'wrong-password',
      );

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<UnknownFailure>());
      verifyNever(() => localDataSource.cacheUser(user));
    });
  });

  group('signInWithGoogle', () {
    test('maps the remote model to a domain entity and caches it', () async {
      when(() => remoteDataSource.signInWithGoogle()).thenAnswer((_) async => user);
      when(() => localDataSource.cacheUser(user)).thenAnswer((_) async {});

      final result = await repository.signInWithGoogle();

      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()?.id, 'user-123');
      verify(() => localDataSource.cacheUser(user)).called(1);
    });

    test('maps remote errors to a domain failure', () async {
      when(() => remoteDataSource.signInWithGoogle()).thenThrow(
        StateError('Google provider is not configured'),
      );

      final result = await repository.signInWithGoogle();

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<UnknownFailure>());
      verifyNever(() => localDataSource.cacheUser(user));
    });
  });

  test('signOut clears the local cache after remote sign out', () async {
    when(() => remoteDataSource.signOut()).thenAnswer((_) async {});
    when(() => localDataSource.clearCachedUser()).thenAnswer((_) async {});

    final result = await repository.signOut();

    expect(result, const Right<Failure, Unit>(unit));
    verifyInOrder([
      () => remoteDataSource.signOut(),
      () => localDataSource.clearCachedUser(),
    ]);
  });

  test('does not emit a stale cached UID before the Firebase session', () async {
    const staleUser = AuthUserModel(
      id: 'stale-user',
      isAnonymous: true,
    );
    when(() => localDataSource.readCachedUser()).thenAnswer((_) async => staleUser);
    when(() => localDataSource.cacheUser(user)).thenAnswer((_) async {});
    when(() => remoteDataSource.observeSession()).thenAnswer((_) => Stream.value(user));

    final sessions = await repository.observeSession().toList();

    expect(sessions, hasLength(1));
    expect(sessions.single?.id, user.id);
    verifyNever(() => localDataSource.clearCachedUser());
  });

  test('sendPasswordResetEmail delegates to Firebase and returns success', () async {
    when(
      () => remoteDataSource.sendPasswordResetEmail(email: 'person@example.test'),
    ).thenAnswer((_) async {});

    final result = await repository.sendPasswordResetEmail(
      email: 'person@example.test',
    );

    expect(result, const Right<Failure, Unit>(unit));
    verify(
      () => remoteDataSource.sendPasswordResetEmail(email: 'person@example.test'),
    ).called(1);
  });
}
