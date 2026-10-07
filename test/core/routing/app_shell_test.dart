import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/core/routing/app_shell.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('keeps tab state when switching branches and exposes global actions', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, _) => const _Tab(title: 'Home'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/activity', builder: (_, _) => const _ActivityTab()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/budgets',
                  builder: (_, _) => const _Tab(title: 'Budgets'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/accounts',
                  builder: (_, _) => const _Tab(title: 'Accounts'),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/operations/new',
          builder: (_, state) => Text(state.uri.queryParameters['type']!),
        ),
        GoRoute(path: '/transfers/new', builder: (_, _) => const Text('transfer route')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('increment')));
    await tester.pumpAndSettle();
    expect(find.text('Count: 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Count: 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('global_add_operation')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add_income_action')), findsOneWidget);
    expect(find.byKey(const ValueKey('add_expense_action')), findsOneWidget);
    expect(find.byKey(const ValueKey('add_transfer_action')), findsOneWidget);
  });
}

class _Tab extends StatelessWidget {
  const _Tab({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(title)));
}

class _ActivityTab extends StatefulWidget {
  const _ActivityTab();

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  var count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Count: $count'),
        ElevatedButton(
          key: const ValueKey('increment'),
          onPressed: () => setState(() => count++),
          child: const Text('Increment'),
        ),
      ],
    ),
  );
}
