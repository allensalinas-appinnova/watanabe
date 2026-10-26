import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/presentation/widgets/category_icon_picker.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  Widget subject({
    required ValueChanged<String?> onSelected,
    Locale locale = const Locale('es'),
    double textScale = 1,
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onSelected(
            await showCategoryIconPicker(context, 'food'),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );

  testWidgets('searches localized icon names and returns the selected stable id', (tester) async {
    String? selected;
    await tester.pumpWidget(subject(onSelected: (value) => selected = value));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('category_icon_search')), 'Suscripciones');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category_icon_option_subscriptions')), findsOneWidget);
    expect(find.byKey(const ValueKey('category_icon_option_food')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('category_icon_option_subscriptions')));
    await tester.tap(find.byKey(const ValueKey('category_icon_use')));
    await tester.pumpAndSettle();
    expect(selected, 'subscriptions');
    expect(tester.takeException(), isNull);
  });

  testWidgets('localizes option labels and displays an empty search state', (tester) async {
    await tester.pumpWidget(
      subject(onSelected: (_) {}, locale: const Locale('pt')),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('category_icon_search')), 'não existe');
    await tester.pumpAndSettle();

    expect(find.text('Nenhum ícone encontrado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker remains usable on a compact screen with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      subject(onSelected: (_) {}, textScale: 1.5),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('category_icon_search')), 'Deportes');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category_icon_option_sports')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
