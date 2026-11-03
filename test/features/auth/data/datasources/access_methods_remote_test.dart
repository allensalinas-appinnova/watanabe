import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:personal_finance/features/auth/data/datasources/google_sign_in_data_source.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_access_method.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _User extends Mock implements User {}

class _Info extends Mock implements UserInfo {}

class _Metadata extends Mock implements UserMetadata {}

class _Credential extends Mock implements UserCredential {}

class _Google extends Mock implements GoogleSignInDataSource {}

class _AuthCredential extends Fake implements AuthCredential {}

class _Provider extends Fake implements AuthProvider {}

void main() {
  late _Auth auth;
  late _User user;
  late _Google google;
  late _Credential credential;
  late FirebaseAuthRemoteDataSource remote;
  late List<UserInfo> providers;
  UserInfo info(String id) {
    final p = _Info();
    when(() => p.providerId).thenReturn(id);
    return p;
  }

  setUpAll(() {
    registerFallbackValue(_AuthCredential());
    registerFallbackValue(_Provider());
  });
  setUp(() {
    auth = _Auth();
    user = _User();
    google = _Google();
    credential = _Credential();
    providers = [info('apple.com')];
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('owner');
    when(() => user.isAnonymous).thenReturn(false);
    when(() => user.email).thenReturn('owner@example.test');
    when(() => user.emailVerified).thenReturn(true);
    when(() => user.providerData).thenAnswer((_) => providers);
    final metadata = _Metadata();
    when(() => metadata.creationTime).thenReturn(DateTime.utc(2020));
    when(() => user.metadata).thenReturn(metadata);
    when(() => user.reload()).thenAnswer((_) async {});
    when(() => user.reauthenticateWithProvider(any())).thenAnswer((_) async => credential);
    when(() => user.reauthenticateWithCredential(any())).thenAnswer((_) async => credential);
    when(() => google.authenticate()).thenAnswer((_) async => 'synthetic-google-token');
    remote = FirebaseAuthRemoteDataSource(firebaseAuth: auth, googleSignInDataSource: google);
  });
  test('refresh maps confirmed provider identities and verification', () async {
    final result = await remote.refreshAccessMethods(expectedUid: 'owner');
    expect(result.providerIds, ['apple.com']);
    expect(result.emailVerified, true);
  });
  test('refresh rejects a different owner after reload', () async {
    when(() => user.reload()).thenAnswer((_) async {
      when(() => auth.currentUser).thenReturn(null);
    });
    await expectLater(
      remote.refreshAccessMethods(expectedUid: 'owner'),
      throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'user-mismatch')),
    );
  });
  test('Apple reauthentication for linking never revokes authorization', () async {
    await remote.reauthenticateForLinking(expectedUid: 'owner', method: AuthAccessMethod.apple);
    verify(() => user.reauthenticateWithProvider(any())).called(1);
    verifyNever(() => auth.revokeTokenWithAuthorizationCode(any()));
    verifyNever(() => auth.signInWithProvider(any()));
  });
  test('link requires reauthentication', () async {
    await expectLater(
      remote.addAccessMethod(
        const LinkAccessMethodCommand(expectedUid: 'owner', method: AuthAccessMethod.google),
      ),
      throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'requires-recent-login')),
    );
    verifyNever(() => google.authenticate());
  });
  test('Apple to Google links to the same owner without signing in', () async {
    await remote.reauthenticateForLinking(expectedUid: 'owner', method: AuthAccessMethod.apple);
    when(() => user.linkWithCredential(any())).thenAnswer((_) async {
      providers.add(info('google.com'));
      return credential;
    });
    final result = await remote.addAccessMethod(
      const LinkAccessMethodCommand(expectedUid: 'owner', method: AuthAccessMethod.google),
    );
    expect(result.id, 'owner');
    expect(result.providerIds, contains('google.com'));
    verifyNever(() => auth.signInWithCredential(any()));
    verifyNever(() => auth.signOut());
  });
  test('Google to Apple uses fresh authorization with explicit consent', () async {
    providers = [info('google.com')];
    await remote.reauthenticateForLinking(expectedUid: 'owner', method: AuthAccessMethod.google);
    when(() => user.linkWithProvider(any())).thenAnswer((_) async {
      providers.add(info('apple.com'));
      return credential;
    });
    final result = await remote.addAccessMethod(
      const LinkAccessMethodCommand(
        expectedUid: 'owner',
        method: AuthAccessMethod.apple,
        applePrivateEmailConsent: true,
      ),
    );
    expect(result.providerIds, contains('apple.com'));
    verifyNever(() => auth.signInWithProvider(any()));
  });
  test('lost response reloads committed provider and returns success', () async {
    await remote.reauthenticateForLinking(expectedUid: 'owner', method: AuthAccessMethod.apple);
    when(() => user.linkWithCredential(any())).thenAnswer((_) async {
      providers.add(info('google.com'));
      throw FirebaseAuthException(code: 'network-request-failed');
    });
    final result = await remote.addAccessMethod(
      const LinkAccessMethodCommand(expectedUid: 'owner', method: AuthAccessMethod.google),
    );
    expect(result.providerIds, contains('google.com'));
  });
  test('credential conflict leaves the current session intact', () async {
    await remote.reauthenticateForLinking(expectedUid: 'owner', method: AuthAccessMethod.apple);
    when(
      () => user.linkWithCredential(any()),
    ).thenThrow(FirebaseAuthException(code: 'credential-already-in-use'));
    await expectLater(
      remote.addAccessMethod(
        const LinkAccessMethodCommand(expectedUid: 'owner', method: AuthAccessMethod.google),
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(auth.currentUser, user);
    verifyNever(() => auth.signOut());
  });
  test('session switch while choosing Google never links to the new user', () async {
    await remote.reauthenticateForLinking(expectedUid: 'owner', method: AuthAccessMethod.apple);
    when(() => google.authenticate()).thenAnswer((_) async {
      when(() => auth.currentUser).thenReturn(null);
      return 'synthetic-token';
    });
    await expectLater(
      remote.addAccessMethod(
        const LinkAccessMethodCommand(expectedUid: 'owner', method: AuthAccessMethod.google),
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
    verifyNever(() => user.linkWithCredential(any()));
  });
  test('private Apple email requires consent for Google and rejects password', () async {
    when(() => user.email).thenReturn('hidden@privaterelay.appleid.com');
    await remote.reauthenticateForLinking(expectedUid: 'owner', method: AuthAccessMethod.apple);
    await expectLater(
      remote.addAccessMethod(
        const LinkAccessMethodCommand(expectedUid: 'owner', method: AuthAccessMethod.google),
      ),
      throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'apple-consent-required')),
    );
    await expectLater(
      remote.addAccessMethod(
        const LinkAccessMethodCommand(
          expectedUid: 'owner',
          method: AuthAccessMethod.password,
          password: 'Synthetic123!',
          applePrivateEmailConsent: true,
        ),
      ),
      throwsA(
        isA<FirebaseAuthException>().having((e) => e.code, 'code', 'password-email-unavailable'),
      ),
    );
  });
  for (final provider in ['apple.com', 'google.com']) {
    test('$provider to password preserves UID and current email', () async {
      providers = [info(provider)];
      await remote.reauthenticateForLinking(
        expectedUid: 'owner',
        method: provider == 'apple.com' ? AuthAccessMethod.apple : AuthAccessMethod.google,
      );
      when(() => user.updatePassword(any())).thenAnswer((_) async {
        providers.add(info('password'));
      });
      final result = await remote.addAccessMethod(
        const LinkAccessMethodCommand(
          expectedUid: 'owner',
          method: AuthAccessMethod.password,
          password: 'Synthetic123!',
        ),
      );
      expect(result.id, 'owner');
      expect(result.email, 'owner@example.test');
      expect(result.providerIds, contains('password'));
    });
  }
  test('retry never changes an existing password method', () async {
    providers = [info('password'), info('google.com')];
    final result = await remote.addAccessMethod(
      const LinkAccessMethodCommand(
        expectedUid: 'owner',
        method: AuthAccessMethod.password,
        password: 'DifferentSynthetic123!',
      ),
    );
    expect(result.providerIds, contains('password'));
    verifyNever(() => user.updatePassword(any()));
  });
  test('password to Google reauthenticates without replacing the account', () async {
    providers = [info('password')];
    await remote.reauthenticateForLinking(
      expectedUid: 'owner',
      method: AuthAccessMethod.password,
      password: 'Synthetic123!',
    );
    when(() => user.linkWithCredential(any())).thenAnswer((_) async {
      providers.add(info('google.com'));
      return credential;
    });
    expect(
      (await remote.addAccessMethod(
        const LinkAccessMethodCommand(expectedUid: 'owner', method: AuthAccessMethod.google),
      )).id,
      'owner',
    );
    verify(() => user.reauthenticateWithCredential(any())).called(1);
  });
}
