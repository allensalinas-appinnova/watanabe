import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Revokes only the freshly reauthenticated owner's Apple grant. Never persists tokens.
Future<void> revokeAppleAuthorization({
  required FirebaseAuth auth,
  required UserCredential credential,
  required String expectedUid,
  http.Client? client,
  bool? nativeApple,
  Future<String?> Function()? appCheckToken,
}) async {
  void assertOwner() {
    if (auth.currentUser?.uid != expectedUid) throw FirebaseAuthException(code: 'user-mismatch');
  }

  assertOwner();
  final native =
      nativeApple ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS));
  if (native) {
    final code = credential.additionalUserInfo?.authorizationCode;
    if (code == null || code.isEmpty) {
      throw FirebaseAuthException(code: 'apple-revocation-unavailable');
    }
    await auth.revokeTokenWithAuthorizationCode(code);
  } else {
    final oauth = credential.credential;
    final accessToken = oauth is OAuthCredential ? oauth.accessToken : null;
    if (accessToken == null || accessToken.isEmpty) {
      throw FirebaseAuthException(code: 'apple-revocation-unavailable');
    }
    final idToken = await auth.currentUser!.getIdToken(true);
    final attestation = await appCheckToken?.call();
    assertOwner();
    final transport = client ?? http.Client();
    try {
      final response = await transport
          .post(
            Uri.https('identitytoolkit.googleapis.com', '/v2/accounts:revokeToken', {
              'key': auth.app.options.apiKey,
            }),
            headers: {
              'Content-Type': 'application/json',
              'X-Firebase-AppCheck': ?attestation,
            },
            body: jsonEncode({
              'providerId': 'apple.com',
              'tokenType': 'ACCESS_TOKEN',
              'token': accessToken,
              'idToken': idToken,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw FirebaseAuthException(code: 'apple-revocation-failed');
    } finally {
      if (client == null) transport.close();
    }
  }
  assertOwner();
}
