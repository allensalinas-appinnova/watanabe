import 'package:google_sign_in/google_sign_in.dart';

const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
const _googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
);

abstract interface class GoogleSignInDataSource {
  Future<String> authenticate();

  Future<void> signOut();
}

class NativeGoogleSignInDataSource implements GoogleSignInDataSource {
  NativeGoogleSignInDataSource({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  Future<void>? _initialization;
  bool _isInitialized = false;

  Future<void> _initialize() => _initialization ??= _initializeOnce();

  Future<void> _initializeOnce() async {
    await _googleSignIn.initialize(
      clientId: _googleClientId.isEmpty ? null : _googleClientId,
      serverClientId: _googleServerClientId.isEmpty ? null : _googleServerClientId,
    );
    _isInitialized = true;
  }

  @override
  Future<String> authenticate() async {
    await _initialize();
    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google Sign-In returned no ID token.');
    }
    return idToken;
  }

  @override
  Future<void> signOut() async {
    if (_isInitialized) await _googleSignIn.signOut();
  }
}
