# Localization and Language Rules

## Supported languages

The initial product supports:

- Spanish (`es`), the default product language for the first mobile rollout.
- English (`en`), retained for parity with the web project and internationalization readiness.

## Implementation policy

- All user-facing strings belong in Flutter localization resources; do not add new hardcoded UI strings in feature widgets.
- Use Flutter's generated localization workflow (`flutter gen-l10n`) with ARB resources once the first complete screen set is implemented.
- Store the selected language in the user profile and mirror it in a local preference for fast startup.
- Default to the device locale only for a new user; an explicit user choice takes precedence.
- Format dates, currencies, numbers and percentages with the active `Locale`.
- Translation keys are stable semantic identifiers, for example `auth.login.title`, `dashboard.totalBalance` and `transactions.emptyState`.

## Translation quality

- Preserve financial meaning and sign conventions in every language.
- Do not concatenate translated fragments to form sentences.
- Keep labels concise enough for narrow devices; provide longer explanatory text in descriptions.
- Review pluralization and gendered language with native speakers before release.
- Test each screen with both the shortest and longest supported translations.

## Accessibility and fallback

- If a translation is missing, fall back to English and log the missing key in development.
- Never show a raw translation key to a production user.
- Localized semantic labels are required for icons, charts and sensitive-data visibility controls.

## Current status

The theme and login base are in place. Generated ARB resources and the full localization delegate are the next implementation step before feature screens move beyond scaffolding.
