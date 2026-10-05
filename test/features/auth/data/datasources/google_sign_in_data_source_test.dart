import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/features/auth/data/datasources/google_sign_in_data_source.dart';

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  late _MockGoogleSignIn googleSignIn;
  late _MockGoogleSignInAccount account;
  late NativeGoogleSignInDataSource dataSource;

  setUp(() {
    googleSignIn = _MockGoogleSignIn();
    account = _MockGoogleSignInAccount();
    dataSource = NativeGoogleSignInDataSource(googleSignIn: googleSignIn);

    when(
      () => googleSignIn.initialize(clientId: null, serverClientId: null),
    ).thenAnswer((_) async {});
    when(() => googleSignIn.authenticate()).thenAnswer((_) async => account);
    when(() => account.authentication).thenReturn(
      const GoogleSignInAuthentication(idToken: 'google-id-token'),
    );
  });

  test('initializes once and returns the Firebase credential ID token', () async {
    final firstToken = await dataSource.authenticate();
    final secondToken = await dataSource.authenticate();

    expect(firstToken, 'google-id-token');
    expect(secondToken, 'google-id-token');
    verify(
      () => googleSignIn.initialize(clientId: null, serverClientId: null),
    ).called(1);
    verify(() => googleSignIn.authenticate()).called(2);
  });

  test('rejects a Google response without an ID token', () async {
    when(() => account.authentication).thenReturn(
      const GoogleSignInAuthentication(idToken: null),
    );

    await expectLater(dataSource.authenticate(), throwsA(isA<StateError>()));
  });
}
