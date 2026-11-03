import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/coach/presentation/providers/coach_providers.dart';

import 'coach_test_support.dart';

void main() {
  setUpAll(registerCoachFallbacks);
  final request = (
    userId: coachUid,
    startAt: DateTime.utc(2026, 10, 1),
    endAtExclusive: DateTime.utc(2026, 11, 1),
  );
  test('disposing before the first report change cancels the source subscription', () async {
    final repository = repositoryFor();
    final cancelled = Completer<void>();
    final events = StreamController<void>(onCancel: cancelled.complete);
    when(
      () => repository.watchReportChanges(
        coachUid,
        startAt: request.startAt,
        endAtExclusive: request.endAtExclusive,
      ),
    ).thenAnswer((_) => events.stream);
    final container = ProviderContainer(
      overrides: [coachRepositoryProvider.overrideWithValue(repository)],
    )..listen(coachReportChangesProvider(request), (_, _) {});
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    await cancelled.future.timeout(const Duration(seconds: 1));
    expect(events.hasListener, isFalse);
    await events.close();
  });

  test('an active report source still exposes authentication errors for recovery', () async {
    final repository = repositoryFor();
    final events = StreamController<void>();
    when(
      () => repository.watchReportChanges(
        coachUid,
        startAt: request.startAt,
        endAtExclusive: request.endAtExclusive,
      ),
    ).thenAnswer((_) => events.stream);
    final container = ProviderContainer(
      overrides: [coachRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.listen(coachReportChangesProvider(request), (_, _) {});
    await Future<void>.delayed(Duration.zero);
    events.add(null);
    await Future<void>.delayed(Duration.zero);
    const failure = AuthFailure('synthetic-session-expired');
    events.addError(failure);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(coachReportChangesProvider(request)).error, same(failure));
    await events.close();
  });
}
