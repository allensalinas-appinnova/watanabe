import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/features/finance/domain/entities/budget.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_flow_type.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_item.dart';
import 'package:personal_finance/features/finance/domain/entities/planning_agenda_entry.dart';
import 'package:personal_finance/features/finance/domain/entities/planning_follow_up.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';

class _Repository extends Mock implements CanonicalFinanceRepository {}

void main() {
  test(
    'agenda reacts to follow-up and item changes without invalidation or changing financial pending',
    () async {
      final repository = _Repository();
      final items = StreamController<List<BudgetItem>>.broadcast();
      final tracking = StreamController<PlanningFollowUpSnapshot>.broadcast();
      addTearDown(items.close);
      addTearDown(tracking.close);
      when(() => repository.watchBudgets('qa', '2026-10')).thenAnswer(
        (_) => Stream.value(const [
          Budget(
            id: 'barber',
            categoryId: 'food',
            flowType: BudgetFlowType.expense,
            monthKey: '2026-10',
            currency: 'COP',
            plannedAmountMinor: 50000,
            status: 'active',
          ),
        ]),
      );
      when(() => repository.watchBudgetItems('qa', 'barber')).thenAnswer((_) async* {
        yield const [
          BudgetItem(
            id: 'one',
            description: 'QA Barber',
            amountMinor: 50000,
            actualAmountMinor: 25000,
            dayOfMonth: 15,
          ),
        ];
        yield* items.stream;
      });
      final container = ProviderContainer(
        overrides: [
          canonicalFinanceRepositoryProvider.overrideWithValue(repository),
          planningFollowUpsProvider('qa').overrideWith((ref) async* {
            yield const PlanningFollowUpSnapshot();
            yield* tracking.stream;
          }),
        ],
      );
      addTearDown(container.dispose);
      const key = (userId: 'qa', monthKey: '2026-10');
      final subscription = container.listen(planningAgendaEntriesProvider(key), (_, _) {});
      addTearDown(subscription.close);
      await container.pump();
      expect(
        (await container.read(planningAgendaEntriesProvider(key).future)).single.followUpState,
        PlanningFollowUpState.open,
      );
      tracking.add(
        const PlanningFollowUpSnapshot(
          items: [
            PlanningFollowUp(
              source: PlanningSource(
                kind: PlanningSourceKind.expense,
                monthKey: '2026-10',
                budgetId: 'barber',
                itemId: 'one',
              ),
              state: PlanningFollowUpState.completed,
              version: 1,
              dataGeneration: 0,
            ),
          ],
        ),
      );
      await container.pump();
      final finished = (await container.read(planningAgendaEntriesProvider(key).future)).single;
      expect(finished.followUpState, PlanningFollowUpState.completed);
      expect(finished.pendingMinor, 25000);
      items.add(const [
        BudgetItem(
          id: 'one',
          description: 'QA Barber',
          amountMinor: 50000,
          actualAmountMinor: 30000,
          dayOfMonth: 15,
        ),
      ]);
      await container.pump();
      expect(
        (await container.read(planningAgendaEntriesProvider(key).future)).single.recordedMinor,
        30000,
      );
    },
  );
  test(
    'attention retains old snoozed periods, merges kinds and exposes partial read failures',
    () async {
      final container = ProviderContainer(
        overrides: [
          planningTodayProvider('qa').overrideWithValue(DateTime(2026, 11, 1)),
          planningFollowUpsProvider('qa').overrideWith(
            (ref) => Stream.value(
              const PlanningFollowUpSnapshot(
                items: [
                  PlanningFollowUp(
                    source: PlanningSource(
                      kind: PlanningSourceKind.expense,
                      monthKey: '2026-10',
                      budgetId: 'old',
                      itemId: 'one',
                    ),
                    state: PlanningFollowUpState.snoozed,
                    version: 1,
                    dataGeneration: 0,
                    remindOn: '2026-11-01',
                  ),
                ],
              ),
            ),
          ),
          planningAgendaEntriesProvider((userId: 'qa', monthKey: '2026-10')).overrideWith(
            (ref) async => [
              PlanningAgendaEntry(
                id: 'old',
                kind: PlanningEntryKind.expense,
                date: DateTime(2026, 10, 15),
                title: 'QA old',
                currency: 'COP',
                plannedMinor: 50,
                recordedMinor: 25,
                pendingMinor: 25,
                monthKey: '2026-10',
                followUpState: PlanningFollowUpState.snoozed,
                remindOn: '2026-11-01',
              ),
            ],
          ),
          planningAgendaEntriesProvider((userId: 'qa', monthKey: '2026-11')).overrideWith(
            (ref) async => [
              PlanningAgendaEntry(
                id: 'debt',
                kind: PlanningEntryKind.debt,
                date: DateTime(2026, 11, 2),
                title: 'QA debt',
                currency: 'COP',
                plannedMinor: 100,
                recordedMinor: 0,
                pendingMinor: 100,
                monthKey: '2026-11',
              ),
            ],
          ),
          planningAgendaEntriesProvider((
            userId: 'qa',
            monthKey: '2026-12',
          )).overrideWith((ref) async => throw StateError('synthetic read failure')),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(planningAttentionProvider('qa'), (_, _) {});
      addTearDown(subscription.close);
      await container.pump();
      await container.pump();
      await container.read(
        planningAgendaEntriesProvider((userId: 'qa', monthKey: '2026-10')).future,
      );
      await container.pump();
      final state = container.read(planningAttentionProvider('qa'));
      expect(state.entries.map((entry) => entry.id), ['old', 'debt']);
      expect(state.incomplete, isTrue);
    },
  );
}
