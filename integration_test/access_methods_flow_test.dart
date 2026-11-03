import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/app.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/core/routing/app_router.dart';
import 'package:personal_finance/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:personal_finance/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:personal_finance/features/auth/data/datasources/google_sign_in_data_source.dart';
import 'package:personal_finance/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_access_method.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_account_link_result.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _ObservedRepository extends AuthRepositoryImpl {
  const _ObservedRepository({required super.remoteDataSource, required super.localDataSource});
  @override
  Future<Either<Failure, Unit>> reauthenticateForLinking({
    required String expectedUid,
    required AuthAccessMethod method,
    String? password,
  }) async {
    final result = await super.reauthenticateForLinking(
      expectedUid: expectedUid,
      method: method,
      password: password,
    );
    result.match(
      (failure) => debugPrint('ACCESS_REAUTH_FAILURE code=${failure.technicalCode}'),
      (_) => null,
    );
    return result;
  }

  @override
  Future<Either<Failure, AuthAccountLinkResult>> addAccessMethod(
    LinkAccessMethodCommand command,
  ) async {
    final result = await super.addAccessMethod(command);
    result.match(
      (failure) => debugPrint('ACCESS_LINK_FAILURE code=${failure.technicalCode}'),
      (_) => null,
    );
    return result;
  }
}

class _EmulatorGoogle implements GoogleSignInDataSource {
  _EmulatorGoogle(this.token);
  final String token;
  @override
  Future<String> authenticate() async => token;
  @override
  Future<void> signOut() async {}
}

String _googleToken(String email, String subject) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'iss': 'https://accounts.google.com', 'aud': 'demo-clearbudget', 'sub': subject, 'email': email, 'email_verified': true, 'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) throw StateError('Emulator only');
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '127.0.0.1');
    await FirebaseBootstrap.initialize(AppEnvironment.dev, useEmulators: true, emulatorHost: host);
    if (FirebaseBootstrap.app.options.projectId != 'demo-clearbudget') {
      throw StateError('demo project required');
    }
    await configureDependencies(useEmulators: true);
  });
  tearDownAll(() async {
    await disposeAppRouter();
    await GetIt.I.reset();
  });
  for (final scenario in [
    (google: false, conflict: false),
    (google: true, conflict: false),
    (google: false, conflict: true),
  ]) {
    final initialGoogle = scenario.google;
    testWidgets(
      scenario.conflict
          ? 'conflicting Google identity preserves both accounts'
          : initialGoogle
          ? 'Google identity adds password and signs in without duplicating data'
          : 'password identity adds Google and signs in without duplicating data',
      (tester) async {
        final auth = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app);
        final db = FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app);
        await auth.signOut();
        final identity = 'access-${DateTime.now().microsecondsSinceEpoch}';
        final googleEmail = '$identity@example.test';
        final email = scenario.conflict ? 'owner-$googleEmail' : googleEmail;
        const password = 'Emulator-only-access-123!';
        final token = _googleToken(googleEmail, identity);
        String? conflictingUid;
        if (scenario.conflict) {
          conflictingUid = (await auth.signInWithCredential(
            GoogleAuthProvider.credential(idToken: token),
          )).user!.uid;
          await auth.signOut();
        }
        final user = initialGoogle
            ? (await auth.signInWithCredential(GoogleAuthProvider.credential(idToken: token))).user!
            : (await auth.createUserWithEmailAndPassword(email: email, password: password)).user!;
        final uid = user.uid;
        expect(auth.currentUser?.email, email);
        expect(auth.currentUser?.uid, uid);
        final profile = db.doc('users/$uid');
        await profile.set({
          'dataGeneration': 0,
          'locale': 'es',
          'countryCode': 'CO',
          'timeZone': 'America/Bogota',
          'defaultCurrency': 'COP',
          'onboardingStatus': 'complete',
          'categoryCatalogVersion': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final account = profile.collection('accounts').doc('access-synthetic-wallet');
        await account.set({
          'name': 'QA acceso',
          'type': 'wallet',
          'currency': 'COP',
          'openingBalanceMinor': 50000,
          'currentBalanceMinor': 50000,
          'includeInDashboard': true,
          'status': 'active',
          'dataGeneration': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final before = (await account.get()).data();
        final remote = FirebaseAuthRemoteDataSource(
          firebaseAuth: auth,
          googleSignInDataSource: _EmulatorGoogle(token),
        );
        final repository = _ObservedRepository(
          remoteDataSource: remote,
          localDataSource: getIt<AuthLocalDataSource>(),
        );
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [authRepositoryProvider.overrideWithValue(repository)],
            child: const PersonalFinanceApp(),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));
        final settings = find.byKey(const ValueKey('global_settings_action'));
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (settings.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        await tester.tap(settings);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings_access_methods')),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const ValueKey('settings_access_methods')));
        await tester.pumpAndSettle();
        final method = initialGoogle ? 'password' : 'google';
        final add = find.byKey(ValueKey('access_add_$method'));
        await tester.scrollUntilVisible(add, 150, scrollable: find.byType(Scrollable).first);
        await tester.tap(add);
        await tester.pumpAndSettle();
        if (initialGoogle) {
          await tester.enterText(find.byKey(const ValueKey('access_new_password')), password);
          await tester.enterText(find.byKey(const ValueKey('access_repeat_password')), password);
        } else {
          await tester.enterText(find.byKey(const ValueKey('access_current_password')), password);
        }
        await tester.ensureVisible(find.byKey(const ValueKey('access_link_submit')));
        expect(repository.currentUser?.id, uid);
        expect(repository.currentUser?.email, email);
        await tester.tap(find.byKey(const ValueKey('access_link_submit')));
        final finished = DateTime.now().add(const Duration(seconds: 25));
        while (find.byType(AlertDialog).evaluate().isNotEmpty &&
            find.byKey(const ValueKey('access_link_error')).evaluate().isEmpty &&
            DateTime.now().isBefore(finished)) {
          await tester.pump(const Duration(milliseconds: 200));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        if (scenario.conflict) {
          expect(find.byKey(const ValueKey('access_link_error')), findsOneWidget);
          expect(
            tester.widget<Text>(find.byKey(const ValueKey('access_link_error'))).data,
            AppLocalizations.of(
              tester.element(find.byKey(const ValueKey('access_link_error'))),
            ).accessConflict,
          );
          expect(auth.currentUser?.uid, uid);
          expect(auth.currentUser!.providerData.map((p) => p.providerId), ['password']);
          expect((await account.get()).data(), before);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await disposeAppRouter();
          await auth.signOut();
          expect(
            (await auth.signInWithCredential(
              GoogleAuthProvider.credential(idToken: token),
            )).user!.uid,
            conflictingUid,
          );
          await auth.signOut();
          expect(
            (await auth.signInWithEmailAndPassword(email: email, password: password)).user!.uid,
            uid,
          );
          await auth.signOut();
          return;
        }
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byKey(ValueKey('access_linked_$method')), findsOneWidget);
        expect(auth.currentUser?.uid, uid);
        await auth.currentUser!.reload();
        expect(
          auth.currentUser!.providerData.map((p) => p.providerId),
          containsAll(['google.com', 'password']),
        );
        expect((await account.get()).data(), before);
        expect((await profile.collection('operations').get()).docs, isEmpty);
        expect((await profile.collection('budgets').get()).docs, isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await disposeAppRouter();
        await auth.signOut();
        await auth.signInWithEmailAndPassword(email: email, password: password);
        expect(auth.currentUser!.uid, uid);
        expect((await account.get()).data(), before);
        await auth.signOut();
        await auth.signInWithCredential(GoogleAuthProvider.credential(idToken: token));
        expect(auth.currentUser!.uid, uid);
        expect((await account.get()).data(), before);
        await auth.signOut();
      },
    );
  }
}
