import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/routing/discard_changes_scope.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('canceling discard keeps the route and confirming exits it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: _Root(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open_dirty_form')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Draft form'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Root screen'), findsOneWidget);
    expect(find.text('Draft form'), findsNothing);
  });
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('open_dirty_form'),
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const _DirtyForm()),
        ),
        child: const Text('Root screen'),
      ),
    ),
  );
}

class _DirtyForm extends StatelessWidget {
  const _DirtyForm();

  @override
  Widget build(BuildContext context) => DiscardChangesScope(
    isDirty: true,
    child: Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('Draft form')),
    ),
  );
}
