import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/entities/auth_access_method.dart';
import '../models/auth_user_model.dart';
import 'apple_authorization_revoker.dart';
import 'google_sign_in_data_source.dart';

abstract interface class AuthRemoteDataSource {
  AuthUserModel? get currentUser;

  Stream<AuthUserModel?> observeSession();

  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  });

  Future<AuthUserModel> createAccount({
    required String email,
    required String password,
  });

  Future<AuthUserModel> refreshAccessMethods({required String expectedUid});
  Future<void> reauthenticateForLinking({
    required String expectedUid,
    required AuthAccessMethod method,
    String? password,
  });
  Future<AuthUserModel> addAccessMethod(LinkAccessMethodCommand command);

  Future<AuthUserModel> signInWithGoogle();
  Future<AuthUserModel> signInWithApple();
  Future<AuthUserModel> linkApple();
  Future<void> reauthenticateForDeletion({String? password});

  Future<AuthUserModel> linkEmailPassword({required String email, required String password});

  Future<AuthUserModel> linkGoogle();

  Future<void> sendEmailVerification();

  Future<void> sendPasswordResetEmail({required String email});

  Future<AuthUserModel> signInAnonymously();

  Future<void> signOut();
}

class FirebaseAuthRemoteDataSource implements AuthRemoteDataSource {
  FirebaseAuthRemoteDataSource({
    required FirebaseAuth firebaseAuth,
    GoogleSignInDataSource? googleSignInDataSource,
  }) : _firebaseAuth = firebaseAuth,
       _googleSignInDataSource = googleSignInDataSource ?? NativeGoogleSignInDataSource();

  final FirebaseAuth _firebaseAuth;
  final GoogleSignInDataSource _googleSignInDataSource;
  String? _linkingUid;
  DateTime? _linkingAuthenticatedAt;

  User _registeredOwner(String uid) {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.uid != uid || user.isAnonymous) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    return user;
  }

  @override
  Future<AuthUserModel> refreshAccessMethods({required String expectedUid}) async {
    final user = _registeredOwner(expectedUid);
    await user.reload().timeout(const Duration(seconds: 10));
    return _mapRequiredUser(_registeredOwner(expectedUid));
  }

  @override
  Future<void> reauthenticateForLinking({
    required String expectedUid,
    required AuthAccessMethod method,
    String? password,
  }) async {
    _linkingUid = null;
    _linkingAuthenticatedAt = null;
    final user = _registeredOwner(expectedUid);
    if (!user.providerData.any((p) => p.providerId == method.providerId)) {
      throw FirebaseAuthException(code: 'provider-not-linked');
    }
    switch (method) {
      case AuthAccessMethod.password:
        if (password == null || user.email == null) {
          throw FirebaseAuthException(code: 'invalid-credential');
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
      case AuthAccessMethod.google:
        if (kIsWeb) {
          await user.reauthenticateWithPopup(GoogleAuthProvider());
        } else {
          final token = await _googleToken();
          _registeredOwner(expectedUid);
          await user.reauthenticateWithCredential(GoogleAuthProvider.credential(idToken: token));
        }
      case AuthAccessMethod.apple:
        if (kIsWeb) {
          await user.reauthenticateWithPopup(AppleAuthProvider());
        } else {
          await user.reauthenticateWithProvider(AppleAuthProvider());
        }
    }
    // Unlike account deletion, adding a method never revokes the Apple grant.
    _registeredOwner(expectedUid);
    _linkingUid = expectedUid;
    _linkingAuthenticatedAt = DateTime.now();
  }

  Future<String> _googleToken() async {
    try {
      return await _googleSignInDataSource.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseAuthException(code: 'web-context-canceled');
      }
      rethrow;
    }
  }

  @override
  Future<AuthUserModel> addAccessMethod(LinkAccessMethodCommand command) async {
    final uid = command.expectedUid;
    await refreshAccessMethods(expectedUid: uid);
    final user = _registeredOwner(uid);
    if (user.providerData.any((p) => p.providerId == command.method.providerId)) {
      return _mapRequiredUser(user);
    }
    if (_linkingUid != uid ||
        _linkingAuthenticatedAt == null ||
        DateTime.now().difference(_linkingAuthenticatedAt!) > const Duration(minutes: 5)) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    if ((isApplePrivateEmail(user.email) || command.method == AuthAccessMethod.apple) &&
        !command.applePrivateEmailConsent) {
      throw FirebaseAuthException(code: 'apple-consent-required');
    }
    try {
      switch (command.method) {
        case AuthAccessMethod.password:
          if (user.email == null || user.email!.trim().isEmpty || isApplePrivateEmail(user.email)) {
            throw FirebaseAuthException(code: 'password-email-unavailable');
          }
          if (command.password == null) throw FirebaseAuthException(code: 'invalid-credential');
          // The existing verified owner already has this email. Set its first
          // password through the authenticated-user API, never a sign-up request.
          // Also avoids Auth Emulator's signUp EMAIL_EXISTS check before idToken resolution.
          await user.updatePassword(command.password!);
        case AuthAccessMethod.google:
          if (kIsWeb) {
            await user.linkWithPopup(GoogleAuthProvider());
          } else {
            final token = await _googleToken();
            _registeredOwner(uid);
            await user.linkWithCredential(GoogleAuthProvider.credential(idToken: token));
          }
        case AuthAccessMethod.apple:
          final provider = AppleAuthProvider()
            ..addScope('email')
            ..addScope('name');
          if (kIsWeb) {
            await user.linkWithPopup(provider);
          } else {
            await user.linkWithProvider(provider);
          }
      }
    } catch (error) {
      // A lost response can follow a committed link. Reload before reporting failure.
      try {
        final refreshed = await refreshAccessMethods(expectedUid: uid);
        if (refreshed.providerIds?.contains(command.method.providerId) == true) return refreshed;
      } on Object {
        /* Retain the original failure; never switch identities. */
      }
      rethrow;
    }
    final refreshed = await refreshAccessMethods(expectedUid: uid);
    if (refreshed.providerIds?.contains(command.method.providerId) != true) {
      throw FirebaseAuthException(code: 'link-verification-required');
    }
    return refreshed;
  }

  @override
  AuthUserModel? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthUserModel?> observeSession() {
    return _firebaseAuth.userChanges().map((user) {
      if (user?.uid != _linkingUid) {
        _linkingUid = null;
        _linkingAuthenticatedAt = null;
      }
      return _mapUser(user);
    });
  }

  @override
  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _mapRequiredUser(credential.user);
  }

  @override
  Future<AuthUserModel> signInWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    final result = kIsWeb
        ? await _firebaseAuth.signInWithPopup(provider)
        : await _firebaseAuth.signInWithProvider(provider);
    return _mapRequiredUser(result.user);
  }

  @override
  Future<AuthUserModel> linkApple() async {
    final user = _firebaseAuth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw FirebaseAuthException(code: 'operation-not-allowed');
    }
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    final result = kIsWeb
        ? await user.linkWithPopup(provider)
        : await user.linkWithProvider(provider);
    if (result.user?.uid != user.uid) throw FirebaseAuthException(code: 'user-mismatch');
    return _mapRequiredUser(result.user);
  }

  @override
  Future<void> reauthenticateForDeletion({String? password}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'user-not-found');
    if (user.isAnonymous) return;
    final providers = user.providerData.map((p) => p.providerId).toSet();
    if (!providers.contains('apple.com') && providers.contains('password') && password != null) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } else {
      final AuthProvider provider = providers.contains('apple.com')
          ? AppleAuthProvider()
          : GoogleAuthProvider();
      final credential = kIsWeb
          ? await user.reauthenticateWithPopup(provider)
          : await user.reauthenticateWithProvider(provider);
      if (providers.contains('apple.com')) {
        await revokeAppleAuthorization(
          auth: _firebaseAuth,
          credential: credential,
          expectedUid: user.uid,
          appCheckToken: () => FirebaseAppCheck.instanceFor(app: _firebaseAuth.app).getToken(),
        );
      }
    }
    if (_firebaseAuth.currentUser?.uid != user.uid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    await user.getIdToken(true);
  }

  @override
  Future<AuthUserModel> signInAnonymously() async {
    final credential = await _firebaseAuth.signInAnonymously();
    return _mapRequiredUser(credential.user);
  }

  @override
  Future<AuthUserModel> createAccount({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _mapRequiredUser(credential.user);
  }

  @override
  Future<AuthUserModel> signInWithGoogle() async {
    final UserCredential credential;
    if (kIsWeb) {
      credential = await _firebaseAuth.signInWithPopup(GoogleAuthProvider());
    } else {
      try {
        final idToken = await _googleSignInDataSource.authenticate();
        credential = await _firebaseAuth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      } on GoogleSignInException catch (error) {
        if (error.code == GoogleSignInExceptionCode.canceled) {
          throw FirebaseAuthException(code: 'web-context-canceled');
        }
        rethrow;
      }
    }
    return _mapRequiredUser(credential.user);
  }

  @override
  Future<AuthUserModel> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    final user = _requireAnonymousUser();
    final credential = EmailAuthProvider.credential(email: email, password: password);
    final linked = await user.linkWithCredential(credential);
    return _mapRequiredUser(linked.user);
  }

  @override
  Future<AuthUserModel> linkGoogle() async {
    final user = _requireAnonymousUser();
    final UserCredential linked;
    if (kIsWeb) {
      linked = await user.linkWithPopup(GoogleAuthProvider());
    } else {
      try {
        final idToken = await _googleSignInDataSource.authenticate();
        linked = await user.linkWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      } on GoogleSignInException catch (error) {
        if (error.code == GoogleSignInExceptionCode.canceled) {
          throw FirebaseAuthException(code: 'web-context-canceled');
        }
        rethrow;
      }
    }
    return _mapRequiredUser(linked.user);
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.isAnonymous || user.email == null) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    await user.sendEmailVerification();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() async {
    _linkingUid = null;
    _linkingAuthenticatedAt = null;
    await _googleSignInDataSource.signOut();
    await _firebaseAuth.signOut();
  }

  AuthUserModel? _mapUser(User? user) {
    if (user == null) return null;
    return AuthUserModel(
      id: user.uid,
      isAnonymous: user.isAnonymous,
      email: user.email,
      displayName: user.displayName,
      createdAt: user.metadata.creationTime,
      providerIds: user.providerData.map((p) => p.providerId).toList(),
      emailVerified: user.emailVerified,
    );
  }

  AuthUserModel _mapRequiredUser(User? user) {
    final mapped = _mapUser(user);
    if (mapped == null) {
      throw StateError('Firebase returned no authenticated user.');
    }
    return mapped;
  }

  User _requireAnonymousUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    return user;
  }
}
