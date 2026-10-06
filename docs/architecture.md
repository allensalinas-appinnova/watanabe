# Flutter Architecture

## Decisions

- **Feature-First Clean Architecture:** each feature owns its domain, data and presentation layers.
- **State management:** `flutter_riverpod` for reactive state, dependency overrides in tests and low ceremony provider composition.
- **Functional errors:** `fpdart` `Either<Failure, Success>` at repository/use-case boundaries.
- **Models:** `freezed` plus `json_serializable`; DTOs map explicitly into domain entities.
- **Navigation:** `go_router` with declarative named routes.
- **DI:** `get_it` registration centralized in `lib/core/di/injection.dart`, with `injectable` annotations kept available for generator adoption as the graph grows.
- **Offline:** Firebase Auth session persistence and Firestore's native mobile persistent cache. A separate local database is intentionally deferred until requirements need relational joins, full-text search or high-volume local analytics.

## Feature contract

Each feature follows:

```text
presentation → domain ← data
```

Presentation depends on use cases and domain entities. Data implements domain repository contracts. Domain has no Firebase, Flutter UI or platform imports.

## Implemented vertical slices

`features/auth` contains:

- a domain `AuthUser` entity and repository contract;
- email/password, Google and anonymous Firebase data source, plus password reset;
- `SharedPreferences` cache adapter;
- repository error mapping to domain `Failure`;
- Riverpod action/session providers;
- a login screen and anonymous sign-in flow;
- a Home dashboard with live Firestore aggregates and recent activity.

`features/finance` contains the canonical mobile model documented in
[canonical-data-model.md](canonical-data-model.md): integer money, localized
category snapshots, accounts, operations plus ledger entries, itemized budgets
and derived monthly summaries. Presentation uses the canonical repository for
onboarding, categories, accounts, income, expense, transfer, budget and tracker
flows. Receipt support remains available as a separate attachment capability.

The app also includes a Drift-backed pending-operation queue for offline
commands and a Firebase Functions worker for balance and monthly-summary
projections.

## Planned feature modules

Reports and imports should follow the same boundary rules when added. Budget
tracking derives actual values from confirmed operations by category, month,
flow type and currency; stored budget amounts describe the plan only.
