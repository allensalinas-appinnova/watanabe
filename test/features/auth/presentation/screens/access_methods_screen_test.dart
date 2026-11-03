import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_access_method.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_account_link_result.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/domain/repositories/auth_repository.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/auth/presentation/screens/access_methods_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _Repository extends Mock implements AuthRepository {}

void main() {
  const owner = AuthUser(
    id: 'owner',
    isAnonymous: false,
    email: 'owner@example.test',
    providerIds: ['password'],
    emailVerified: false,
  );
  late _Repository repository;
  setUpAll(() {
    registerFallbackValue(AuthAccessMethod.password);
    registerFallbackValue(
      const LinkAccessMethodCommand(expectedUid: 'owner', method: AuthAccessMethod.google),
    );
  });
  setUp(() {
    repository = _Repository();
    when(() => repository.currentUser).thenReturn(owner);
    when(
      () => repository.refreshAccessMethods(expectedUid: any(named: 'expectedUid')),
    ).thenAnswer((_) async => const Right(owner));
  });
  Future<void> show(
    WidgetTester tester, {
    AuthUser user = owner,
    Stream<AuthUser?>? session,
    String locale = 'es',
    double scale = 1,
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          authSessionProvider.overrideWith((ref) => session ?? Stream.value(user)),
        ],
        child: MaterialApp(
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const AccessMethodsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows confirmed providers, verification and available Google', (tester) async {
    await show(tester);
    expect(find.byKey(const ValueKey('access_linked_password')), findsOneWidget);
    expect(find.text('Correo pendiente de verificar'), findsOneWidget);
    expect(find.byKey(const ValueKey('access_add_google')), findsOneWidget);
    expect(find.byKey(const ValueKey('access_add_password')), findsNothing);
    expect(find.byKey(const ValueKey('access_add_apple')), findsNothing);
  });
  testWidgets('legacy unknown providers remain blocked after refresh failure and retry recovers', (
    tester,
  ) async {
    const legacy = AuthUser(id: 'owner', isAnonymous: false, email: 'owner@example.test');
    when(
      () => repository.refreshAccessMethods(expectedUid: 'owner'),
    ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
    await show(tester, user: legacy);
    final button = tester.widget<OutlinedButton>(find.byKey(const ValueKey('access_add_google')));
    expect(button.onPressed, isNull);
    expect(find.byKey(const ValueKey('access_methods_error')), findsOneWidget);
    when(
      () => repository.refreshAccessMethods(expectedUid: 'owner'),
    ).thenAnswer((_) async => const Right(owner));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('access_linked_password')), findsOneWidget);
  });
  testWidgets('Google conflict retains current password input and session', (tester) async {
    when(
      () => repository.reauthenticateForLinking(
        expectedUid: 'owner',
        method: AuthAccessMethod.password,
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Right(unit));
    when(() => repository.addAccessMethod(any())).thenAnswer(
      (_) async => const Left(AuthFailure('conflict', technicalCode: 'credential-already-in-use')),
    );
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('access_add_google')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('access_current_password')), 'Synthetic123!');
    await tester.tap(find.byKey(const ValueKey('access_link_submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('access_link_error')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('access_current_password')))
          .controller!
          .text,
      'Synthetic123!',
    );
    verifyNever(() => repository.signOut());
    verifyNever(() => repository.signInWithGoogle());
  });
  testWidgets('cancelled provider authorization leaves the form without alarming error', (
    tester,
  ) async {
    when(
      () => repository.reauthenticateForLinking(
        expectedUid: 'owner',
        method: AuthAccessMethod.password,
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const Left(AuthFailure('cancel', technicalCode: 'web-context-canceled')),
    );
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('access_add_google')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('access_current_password')), 'Synthetic123!');
    await tester.tap(find.byKey(const ValueKey('access_link_submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('access_link_error')), findsNothing);
    verifyNever(() => repository.addAccessMethod(any()));
  });
  testWidgets('Apple with private email disables password and requires consent for Google', (
    tester,
  ) async {
    final user = owner.copyWith(
      email: 'hidden@privaterelay.appleid.com',
      providerIds: ['apple.com'],
      emailVerified: true,
    );
    when(() => repository.currentUser).thenReturn(user);
    when(
      () => repository.refreshAccessMethods(expectedUid: 'owner'),
    ).thenAnswer((_) async => Right(user));
    await show(tester, user: user);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const ValueKey('access_add_password'))).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('access_add_google')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('access_apple_consent')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('access_link_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Confirma que aceptas esta asociación.'), findsOneWidget);
    verifyNever(
      () => repository.reauthenticateForLinking(
        expectedUid: any(named: 'expectedUid'),
        method: any(named: 'method'),
        password: any(named: 'password'),
      ),
    );
  });
  testWidgets('successful link refreshes list and never calls guest upgrade methods', (
    tester,
  ) async {
    final linked = owner.copyWith(providerIds: ['password', 'google.com']);
    when(
      () => repository.reauthenticateForLinking(
        expectedUid: 'owner',
        method: AuthAccessMethod.password,
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Right(unit));
    when(() => repository.addAccessMethod(any())).thenAnswer((_) async {
      when(() => repository.currentUser).thenReturn(linked);
      when(
        () => repository.refreshAccessMethods(expectedUid: 'owner'),
      ).thenAnswer((_) async => Right(linked));
      return Right(AuthAccountLinkResult(user: linked));
    });
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('access_add_google')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('access_current_password')), 'Synthetic123!');
    await tester.tap(find.byKey(const ValueKey('access_link_submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('access_linked_google')), findsOneWidget);
    expect(find.byKey(const ValueKey('access_add_google')), findsNothing);
    verifyNever(() => repository.linkGoogle());
    verifyNever(() => repository.reauthenticateForDeletion(password: any(named: 'password')));
  });
  testWidgets('Firebase replacement of unverified password is explained from actual providers', (
    tester,
  ) async {
    final linked = owner.copyWith(providerIds: ['google.com'], emailVerified: true);
    when(
      () => repository.reauthenticateForLinking(
        expectedUid: 'owner',
        method: AuthAccessMethod.password,
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Right(unit));
    when(() => repository.addAccessMethod(any())).thenAnswer((_) async {
      when(() => repository.currentUser).thenReturn(linked);
      when(
        () => repository.refreshAccessMethods(expectedUid: 'owner'),
      ).thenAnswer((_) async => Right(linked));
      return Right(AuthAccountLinkResult(user: linked));
    });
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('access_add_google')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Firebase puede sustituir'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('access_current_password')), 'Synthetic123!');
    await tester.tap(find.byKey(const ValueKey('access_link_submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('La contraseña anterior ya no figura'), findsOneWidget);
    expect(find.byKey(const ValueKey('access_linked_password')), findsNothing);
    expect(find.byKey(const ValueKey('access_add_password')), findsOneWidget);
  });
  testWidgets('session switch removes previous account providers and blocks stale data', (
    tester,
  ) async {
    final controller = StreamController<AuthUser?>();
    addTearDown(controller.close);
    await show(tester, session: controller.stream);
    controller.add(owner);
    await tester.pumpAndSettle();
    const other = AuthUser(
      id: 'other',
      isAnonymous: false,
      email: 'other@example.test',
      providerIds: ['google.com'],
      emailVerified: true,
    );
    when(() => repository.currentUser).thenReturn(other);
    when(
      () => repository.refreshAccessMethods(expectedUid: 'other'),
    ).thenAnswer((_) async => const Right(other));
    controller.add(other);
    await tester.pumpAndSettle();
    expect(find.text(owner.email!), findsNothing);
    expect(find.byKey(const ValueKey('access_linked_password')), findsNothing);
    expect(find.byKey(const ValueKey('access_linked_google')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('session change closes access to previous identity and clears credential fields', (
    tester,
  ) async {
    final controller = StreamController<AuthUser?>();
    addTearDown(controller.close);
    await show(tester, session: controller.stream);
    controller.add(owner);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('access_add_google')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('access_current_password')), 'Synthetic123!');
    final field = tester
        .widget<TextField>(find.byKey(const ValueKey('access_current_password')))
        .controller!;
    final other = owner.copyWith(id: 'other', email: 'other@example.test');
    when(() => repository.currentUser).thenReturn(other);
    when(
      () => repository.refreshAccessMethods(expectedUid: 'other'),
    ).thenAnswer((_) async => Right(other));
    controller.add(other);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('access_current_password')), findsNothing);
    expect(field.text, isEmpty);
    expect(find.text(owner.email!), findsNothing);
    expect(find.textContaining('La sesión cambió'), findsOneWidget);
    verifyNever(() => repository.addAccessMethod(any()));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('guest keeps save-account entry without method controls', (tester) async {
    await show(tester, user: const AuthUser(id: 'guest', isAnonymous: true));
    expect(find.text('Guardar mi cuenta'), findsOneWidget);
    expect(find.byKey(const ValueKey('access_add_google')), findsNothing);
    verifyNever(() => repository.refreshAccessMethods(expectedUid: any(named: 'expectedUid')));
  });
  testWidgets('resume refresh failure retains last providers and disables additions', (
    tester,
  ) async {
    await show(tester);
    when(
      () => repository.refreshAccessMethods(expectedUid: 'owner'),
    ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('access_linked_password')), findsOneWidget);
    expect(find.byKey(const ValueKey('access_methods_error')), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const ValueKey('access_add_google'))).onPressed,
      isNull,
    );
  });
  for (final locale in ['es', 'en', 'pt']) {
    testWidgets('compact large text and dark theme work in $locale', (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, locale: locale, scale: 2, dark: true);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('access_add_google')),
        150,
        scrollable: find
            .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('access_add_google')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
