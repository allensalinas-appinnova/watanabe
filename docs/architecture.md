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

`features/finance` contains:

- domain entities for accounts, cashflow entries and category budgets;
- a repository contract and Firestore data source scoped to
  `users/{authenticatedUid}`;
- Firebase Storage receipt uploads scoped to the authenticated user's path;
- Riverpod stream providers for accounts, transactions and budgets;
- an atomic expense write for cashflow, account balance and matching budget,
  with uploaded receipts cleaned up if the Firestore transaction fails;
- the Figma-backed Activity, Budget planner, Accounts and Add expense screens.

## Planned feature modules

Transfers, income entry, category management, full budget-item planning, budget
tracking, reports, imports and profile preferences should follow the same
boundary rules.
