import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/coach/domain/entities/coach_models.dart';
import 'package:personal_finance/features/coach/presentation/screens/coach_home_screen.dart';

import 'coach_test_support.dart';

void main() {
  setUp(registerCoachFallbacks);

  testWidgets('coach hub exposes both routines, history and reminder settings', (tester) async {
    final repository = repositoryFor(
      completions: [
        const CoachCompletion(periodKey: '2026-10-21', kind: CoachReviewKind.daily),
      ],
    );
    await pumpCoach(tester, const CoachHomeScreen(), repository, language: 'en');

    expect(find.text('Your financial coach'), findsOneWidget);
    expect(find.text('Daily check-in'), findsWidgets);
    expect(find.text('Weekly review'), findsOneWidget);
    expect(find.text('Recent reviews'), findsOneWidget);
    expect(find.text('2026-10-21'), findsOneWidget);
    expect(find.text('Set reminders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coach hub remains readable on compact screen with enlarged Portuguese text', (
    tester,
  ) async {
    await pumpCoach(
      tester,
      const CoachHomeScreen(),
      repositoryFor(),
      language: 'pt',
      compact: true,
    );

    expect(find.text('Seu coach financeiro'), findsOneWidget);
    expect(find.text('Revisão diária'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Revisão semanal'), 300);
    expect(find.text('Revisão semanal'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
