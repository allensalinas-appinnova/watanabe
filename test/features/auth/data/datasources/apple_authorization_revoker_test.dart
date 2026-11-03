import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/features/auth/data/datasources/apple_authorization_revoker.dart';

class Auth extends Mock implements FirebaseAuth {}

class App extends Mock implements FirebaseApp {}

class Identity extends Mock implements User {}

class Credential extends Mock implements UserCredential {}

class Info extends Mock implements AdditionalUserInfo {}

void main() {
  late Auth auth;
  late Identity user;
  late Credential credential;
  setUp(() {
    auth = Auth();
    user = Identity();
    credential = Credential();
    final app = App();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('synthetic-owner');
    when(() => user.getIdToken(true)).thenAnswer((_) async => 'synthetic-id-token');
    when(() => auth.app).thenReturn(app);
    when(() => app.options).thenReturn(
      const FirebaseOptions(
        apiKey: 'synthetic-api-key',
        appId: 'synthetic',
        messagingSenderId: '0',
        projectId: 'demo-clearbudget',
      ),
    );
  });
  test('native Apple revokes the new authorization code through Firebase SDK', () async {
    final info = Info();
    when(() => credential.additionalUserInfo).thenReturn(info);
    when(() => info.authorizationCode).thenReturn('synthetic-code');
    when(() => auth.revokeTokenWithAuthorizationCode('synthetic-code')).thenAnswer((_) async {});
    await revokeAppleAuthorization(
      auth: auth,
      credential: credential,
      expectedUid: 'synthetic-owner',
      nativeApple: true,
    );
    verify(() => auth.revokeTokenWithAuthorizationCode('synthetic-code')).called(1);
  });
  test('Android and web revoke using the same v2 contract as Firebase web SDK', () async {
    when(
      () => credential.credential,
    ).thenReturn(OAuthProvider('apple.com').credential(accessToken: 'synthetic-access-token'));
    final client = MockClient((request) async {
      expect(request.url.host, 'identitytoolkit.googleapis.com');
      expect(request.url.path, '/v2/accounts:revokeToken');
      expect(request.headers['X-Firebase-AppCheck'], 'synthetic-attestation');
      expect(jsonDecode(request.body), {
        'providerId': 'apple.com',
        'tokenType': 'ACCESS_TOKEN',
        'token': 'synthetic-access-token',
        'idToken': 'synthetic-id-token',
      });
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    await revokeAppleAuthorization(
      auth: auth,
      credential: credential,
      expectedUid: 'synthetic-owner',
      nativeApple: false,
      client: client,
      appCheckToken: () async => 'synthetic-attestation',
    );
  });
  test('missing Apple access credential prevents deletion from proceeding', () async {
    when(() => credential.credential).thenReturn(null);
    await expectLater(
      revokeAppleAuthorization(
        auth: auth,
        credential: credential,
        expectedUid: 'synthetic-owner',
        nativeApple: false,
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
    verifyNever(() => user.getIdToken(true));
  });
  test('session changes cannot revoke a different owner authorization', () async {
    await expectLater(
      revokeAppleAuthorization(
        auth: auth,
        credential: credential,
        expectedUid: 'other-owner',
        nativeApple: false,
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
    verifyNever(() => user.getIdToken(true));
  });
  test('provider rejection is an error and is never reported as successful revocation', () async {
    when(
      () => credential.credential,
    ).thenReturn(OAuthProvider('apple.com').credential(accessToken: 'synthetic-access-token'));
    final client = MockClient((_) async => http.Response('{}', 400));
    addTearDown(client.close);
    await expectLater(
      revokeAppleAuthorization(
        auth: auth,
        credential: credential,
        expectedUid: 'synthetic-owner',
        nativeApple: false,
        client: client,
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
  });
}
