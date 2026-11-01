import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_screen.dart';
import 'package:personal_finance/features/finance/presentation/widgets/finance_popup_selector.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('a suggestion arriving after initial loading becomes the selected valid form value', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    final selection = ValueNotifier<String?>(null);
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ValueListenableBuilder<String?>(
            valueListenable: selection,
            builder: (c, value, _) => Form(
              key: form,
              child: FinancePopupSelector<String>(
                key: const ValueKey('selector'),
                title: 'Category',
                initialValue: value,
                options: value == null ? [] : ['food'],
                optionLabel: (s) => s,
                searchText: (s) => s,
                optionBuilder: (c, s) => Text(s),
                onSelected: (_) {},
                validator: (v) => v == null ? 'Choose category' : null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isFalse);
    selection.value = 'food';
    await tester.pumpAndSettle();
    expect(find.text('food'), findsOneWidget);
    expect(form.currentState!.validate(), isTrue);
    selection.value = null;
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isFalse);
  });
  for (final locale in ['es', 'en', 'pt']) {
    testWidgets(
      'document errors are localized and distinguish disk capacity from network loss ($locale)',
      (tester) async {
        String? disk, offline;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (c) {
                final l = AppLocalizations.of(c);
                disk = documentError(l, 'document-draft-unavailable');
                offline = l.documentOffline;
                return Scaffold(body: Text(disk!));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(disk, isNot(offline));
        expect(disk, isNotEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
