# AGENTS.md — Personal Finance Flutter

## Project scope

This directory is the Flutter mobile client for the personal finance product.
The sibling `../studio` directory is the original web implementation and may be
used only as a business-domain and functional reference. Do not copy its
architecture or React/Next.js implementation decisions into this project.

The current product concept is named ClearBudget. The functional baseline is
documented in `docs/functional-scope.md`.

## Source of truth

When sources disagree, use this order:

1. Current Flutter code and passing tests.
2. Versioned Flutter architecture and product documentation in `docs/`.
3. The web repository as a reference for behavior and domain vocabulary.
4. Figma as the visual reference for intended mobile UI.

Label proposed behavior as proposed. Do not silently convert web behavior into
mobile behavior when offline, synchronization, platform permissions, or UX
decisions are unresolved.

## Architecture rules

- Use Feature-First Clean Architecture.
- Every feature belongs under `lib/features/<feature_name>/`.
- Keep `domain/` independent from Flutter, Firebase and platform APIs.
- Put entities, repository contracts and reusable use cases in `domain/`.
- Put DTOs, mappers, Firebase data sources and repository implementations in
  `data/`.
- Put screens, feature widgets and Riverpod providers in `presentation/`.
- Put cross-feature concerns in `lib/core/`; do not use `lib/core/` as a dump
  for feature-specific code.
- Dependencies flow from presentation to domain and from data to domain. The
  domain layer must not depend on data or presentation.
- Repository and use-case boundaries return `Either<Failure, Success>` from
  `fpdart` for fallible commands.
- Map data DTOs explicitly into domain entities. Do not expose Firestore
  `DocumentSnapshot`, Firebase `User`, or DTOs to presentation widgets.

## State management and dependency injection

- Use `flutter_riverpod` for reactive state and testable provider overrides.
- Keep business logic out of widgets. Providers/controllers may orchestrate
  use cases but must not contain Firebase query details.
- Use `get_it` for the application dependency graph. Keep registrations in
  `lib/core/di/injection.dart`.
- `injectable` annotations and generated files are supported. Never edit
  generated files by hand.
- Dispose streams, controllers and subscriptions when their owning provider or
  widget is disposed.

## Models and generated code

- Use immutable `freezed` models for DTOs and domain value objects where useful.
- Use `json_serializable` for JSON/Firestore serialization.
- Keep generated files (`*.freezed.dart`, `*.g.dart`, `injection.config.dart`)
  synchronized with their source files.
- After changing annotations or model fields, run:

  ```bash
  dart run build_runner build
  ```

- Do not hand-edit generated output. If generated output is tracked, include
  the regenerated diff with the source change.

## Navigation

- Use `go_router` with named, declarative routes.
- Keep route definitions in `lib/core/routing/`.
- Use a stateful shell for the eventual persistent bottom navigation when the
  feature screens are implemented.
- Guard authenticated routes centrally; do not duplicate auth checks in every
  screen.
- Preserve deep-link behavior when adding routes.

## Firebase and offline behavior

- Firebase is the backend boundary: Auth, Firestore, Storage, Analytics and
  Crashlytics are initialized through `lib/core/firebase/`.
- Use Firestore's native mobile persistent cache as the default offline source
  of truth.
- Do not introduce Isar, Drift or Hive unless a documented requirement needs
  relational queries, full-text search, high-volume local analytics, or a
  cache that Firestore cannot provide.
- Keep Firebase configuration out of source control. Use flavors and
  `--dart-define` values documented in `docs/flavors.md`.
- Never commit API secrets, service-account keys, tokens, production exports,
  real user data or private Firebase configuration files.
- Treat authentication, Firestore rules, Storage rules and Crashlytics setup as
  security-sensitive changes. Verify them independently before release.

## UI/UX and localization

- Follow `docs/ui-ux-guidelines.md` and `docs/ui-standards-and-theme.md`.
- Consume `AppColors`, `AppTheme` and shared widgets instead of hardcoding
  feature-level colors, spacing or typography.
- Use Material 3 components and maintain 48x48 logical-pixel touch targets.
- Every screen must account for loading, empty, error, offline/stale and
  success states as applicable.
- Keep user-facing strings in Flutter localization resources. Do not add new
  hardcoded strings to feature widgets.
- Supported languages are Spanish (`es`) and English (`en`). See
  `docs/localization.md` and use `flutter gen-l10n` after changing ARB files.
- Format dates, currencies and percentages with the active locale.

## Naming and Dart style

- File names use `snake_case.dart`.
- Classes, enums and extensions use `UpperCamelCase`.
- Variables, methods and named parameters use `lowerCamelCase`.
- Prefer `const`, immutable fields, named parameters and small composable
  widgets.
- Use explicit return types and avoid `dynamic` unless crossing a typed API
  boundary with a documented cast.
- Keep imports ordered and run `dart format` before validation.
- Comments should explain intent, constraints or trade-offs, not restate code.

## Testing requirements

- Mirror `lib/` structure under `test/`.
- Unit-test domain logic, use cases, mappers, repository behavior and formatters.
- Use `mocktail` or provider overrides for external dependencies.
- Widget tests should verify user-visible states and accessibility labels.
- Add integration tests for Firebase/auth/navigation workflows when platform
  setup is available.
- Run emulator backed tests only with the reserved `demo-clearbudget` project
  configured in `.firebaserc`; never aim automated tests at a live Firebase
  project.
- Keep emulator endpoint selection behind `USE_FIREBASE_EMULATORS`; do not bake
  emulator hosts into production startup.
- When changing Firestore rules, add or update emulator tests for authorized,
  unauthorized and unauthenticated access.
- When changing a user flow, test validation, loading, success, error and route
  outcomes at the most appropriate layer.
- Do not claim Firebase integration coverage from tests that only use mocks.

## Required validation

Run the smallest relevant checks during iteration. Before handing off a
material change, run:

```bash
flutter pub get
dart run build_runner build
flutter gen-l10n
dart format lib test
dart analyze
flutter test
```

For release or platform changes, additionally run the applicable build and
platform checks, for example:

```bash
flutter build apk --dart-define=APP_ENV=staging
flutter build ios --dart-define=APP_ENV=staging --no-codesign
flutter build web --dart-define=APP_ENV=staging
```

Do not report a command as passing unless it was actually executed. Record
environment limitations, unavailable credentials, emulator requirements and
baseline failures separately from new failures.

## Change workflow for Codex

1. Read this file and the relevant `docs/` page before editing.
2. Inspect the current working tree and preserve unrelated user changes.
3. Identify the feature boundary and update domain contracts before UI code.
4. Implement the smallest vertical slice with tests.
5. Regenerate code, format and run analyzer/tests.
6. Review the diff for secrets, accidental generated churn and architecture
   violations.
7. Summarize changed files, commands run, results, risks and the next vertical
   delivery.

Do not reset, delete or overwrite unrelated files. Ask before making destructive
changes, changing Firebase projects, changing release identifiers, or adding
external services beyond the requested scope.
