import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/core/offline/pending_operation_queue.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/auth/presentation/widgets/account_identity_card.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_more_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

final createdAt = DateTime.utc(2020, 4, 15, 15);
AuthUser registered({
  String id = 'first',
  String? email = 'first@example.test',
  bool date = true,
}) => AuthUser(id: id, isAnonymous: false, email: email, createdAt: date ? createdAt : null);

Widget subject({
  AuthUser? user,
  Stream<AuthUser?>? session,
  List<PendingOperation> pending = const [],
}) => ProviderScope(
  overrides: [
    authSessionProvider.overrideWith((ref) => session ?? Stream.value(user)),
    pendingOperationsProvider.overrideWith((ref) => Stream.value(pending)),
  ],
  child: const MaterialApp(
    locale: Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CanonicalMoreScreen(),
  ),
);

Future<void> openSignOut(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('more_sign_out')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const ValueKey('more_sign_out')));
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in ['es', 'en', 'pt']) {
    for (final brightness in Brightness.values) {
      testWidgets('identity wraps at 320dp with enlarged text $locale $brightness', (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final email = '${'longaddress' * 8}@example.test';
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(brightness: brightness),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
                child: Scaffold(
                  body: ListView(
                    children: [AccountIdentityCard(user: registered(email: email))],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(find.byType(AccountIdentityCard)));
        expect(find.text(email), findsOneWidget);
        expect(find.byType(SelectableText), findsOneWidget);
        expect(
          find.text(l.settingsMemberSince(DateFormat.yMMMMd(locale).format(createdAt.toLocal()))),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('missing optional values never invent email or date', (tester) async {
    await tester.pumpWidget(subject(user: registered(email: null, date: false)));
    await tester.pumpAndSettle();
    expect(find.text('Correo no disponible'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings_account_since')), findsNothing);
    expect(find.textContaining('first'), findsNothing);
  });
  testWidgets('guest has one protection action and no registration date', (tester) async {
    await tester.pumpWidget(
      subject(
        user: AuthUser(id: 'guest', isAnonymous: true, createdAt: createdAt),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AccountIdentityCard), findsOneWidget);
    expect(find.byKey(const ValueKey('settings_secure_guest_account')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings_account_email')), findsNothing);
    expect(find.byKey(const ValueKey('settings_account_since')), findsNothing);
  });
  testWidgets('confirmation identifies account, cancellation keeps the session', (tester) async {
    await tester.pumpWidget(subject(user: registered()));
    await tester.pumpAndSettle();
    await openSignOut(tester);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('first@example.test'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Tendrás que volver'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings_sign_out_cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('pending operations warning remains alongside account identity', (tester) async {
    final now = DateTime.utc(2026, 1, 1);
    await tester.pumpWidget(
      subject(
        user: registered(),
        pending: [
          PendingOperation(
            id: 1,
            idempotencyKey: 'pending-1',
            operationType: 'expense',
            payload: '{}',
            status: 'pending',
            retryCount: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await openSignOut(tester);
    final l = AppLocalizations.of(tester.element(find.byType(CanonicalMoreScreen)));
    expect(find.textContaining(l.signOutPendingWarning(1)), findsOneWidget);
    expect(find.textContaining('first@example.test'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings_sign_out_cancel')));
    await tester.pumpAndSettle();
  });
  testWidgets('identity and open dialog cannot retain the previous user', (tester) async {
    final stream = StreamController<AuthUser?>();
    await tester.pumpWidget(subject(session: stream.stream));
    stream.add(registered());
    await tester.pumpAndSettle();
    await openSignOut(tester);
    stream.add(registered(id: 'second', email: 'second@example.test'));
    await tester.pumpAndSettle();
    expect(find.textContaining('first@example.test'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings_sign_out_confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings_account_email')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('second@example.test'), findsOneWidget);
    stream.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(AccountIdentityCard), findsNothing);
    expect(find.text('second@example.test'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(stream.close());
    await tester.pump();
  });
}
