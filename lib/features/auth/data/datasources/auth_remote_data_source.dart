import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/auth_user_model.dart';
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

  Future<AuthUserModel> signInWithGoogle();

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

  @override
  AuthUserModel? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthUserModel?> observeSession() {
    return _firebaseAuth.userChanges().map(_mapUser);
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
