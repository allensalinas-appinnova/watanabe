import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/core/routing/app_shell.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('budget child routes pop back to the active budget branch', (tester) async {
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/budgets',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [GoRoute(path: '/home', builder: (_, _) => const Text('Home'))],
            ),
            StatefulShellBranch(
              routes: [GoRoute(path: '/activity', builder: (_, _) => const Text('Activity'))],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/budgets',
                  builder: (_, _) => Builder(
                    builder: (context) => Scaffold(
                      body: Column(
                        children: [
                          const Text('Budget list'),
                          TextButton(
                            key: const ValueKey('open_create'),
                            onPressed: () => context.push('/budgets/new'),
                            child: const Text('Create'),
                          ),
                          TextButton(
                            key: const ValueKey('open_detail'),
                            onPressed: () => context.push('/budgets/test-budget'),
                            child: const Text('Detail'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  routes: [
                    GoRoute(
                      path: 'new',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, _) => Builder(
                        builder: (context) => Scaffold(
                          body: TextButton(
                            key: const ValueKey('create_back'),
                            onPressed: context.pop,
                            child: const Text('Back from create'),
                          ),
                        ),
                      ),
                    ),
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, _) => Builder(
                        builder: (context) => Scaffold(
                          body: Column(
                            children: [
                              const Text('Budget detail'),
                              TextButton(
                                key: const ValueKey('detail_back'),
                                onPressed: context.pop,
                                child: const Text('Back from detail'),
                              ),
                              TextButton(
                                key: const ValueKey('open_edit'),
                                onPressed: () =>
                                    context.push('/budgets/test-budget/items/test-item/edit'),
                                child: const Text('Edit item'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      routes: [
                        GoRoute(
                          path: 'items/:itemId/edit',
                          parentNavigatorKey: rootNavigatorKey,
                          builder: (_, _) => Builder(
                            builder: (context) => Scaffold(
                              body: TextButton(
                                key: const ValueKey('edit_back'),
                                onPressed: context.pop,
                                child: const Text('Back from edit'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [GoRoute(path: '/accounts', builder: (_, _) => const Text('Accounts'))],
            ),
          ],
        ),
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

    Future<void> expectActiveBudgetList() async {
      final createButton = find.byKey(const ValueKey('open_create')).hitTestable();
      expect(createButton, findsOneWidget);
      expect(find.text('Budget list').hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<NavigationBar>(find.byKey(const ValueKey('finance_bottom_navigation')))
            .selectedIndex,
        2,
      );
    }

    await expectActiveBudgetList();
    await tester.tap(find.byKey(const ValueKey('open_create')));
    await tester.pumpAndSettle();
    expect(find.text('Back from create'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create_back')));
    await tester.pumpAndSettle();
    await expectActiveBudgetList();

    await tester.tap(find.byKey(const ValueKey('open_detail')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open_edit')));
    await tester.pumpAndSettle();
    expect(find.text('Back from edit'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit_back')));
    await tester.pumpAndSettle();
    expect(find.text('Budget detail').hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('detail_back')));
    await tester.pumpAndSettle();
    await expectActiveBudgetList();
  });

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
    expect(find.byKey(const ValueKey('global_add_operation')), findsNothing);

    await tester.tap(find.byIcon(Icons.pie_chart_outline));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('global_add_operation')), findsNothing);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('global_add_operation')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add_income_action')), findsOneWidget);
    expect(find.byKey(const ValueKey('add_expense_action')), findsOneWidget);
    expect(find.byKey(const ValueKey('add_transfer_action')), findsOneWidget);

    Navigator.of(tester.element(find.byKey(const ValueKey('add_income_action')))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<NavigationBar>(
            find.byKey(const ValueKey('finance_bottom_navigation')),
          )
          .selectedIndex,
      3,
    );
    expect(find.byKey(const ValueKey('global_add_operation')), findsNothing);
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
