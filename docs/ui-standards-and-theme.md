# UI Standards and Theme Rules

## Design system foundations

The application uses Material 3 with a finance-oriented visual language:

| Token | Value | Usage |
| --- | --- | --- |
| `navy` | `#102A43` | High-emphasis surfaces and headings |
| `blue` | `#64B5F6` | Brand highlight and positive navigation affordance |
| `blueDark` | `#1C61D1` | Primary actions and links |
| `blueSoft` | `#E3F2FD` | Informational surfaces and selected states |
| `background` | `#F6FAFE` | App background |
| `orange` | `#FFB74D` | Attention, pending and budget warnings |
| `green` | `#14A765` | Income and positive variance |
| `muted` | `#60748A` | Secondary text |
| `line` | `#DCE6F0` | Dividers and input borders |

Canonical definitions live in `lib/core/theme/app_colors.dart` and `lib/core/theme/app_theme.dart`.

## Typography

- Primary family: Inter.
- Use Material 3 text roles rather than local font sizes when possible.
- Headings use bold/high emphasis; labels use medium or semibold; supporting text uses regular/muted.
- Financial values must use tabular-looking, high-contrast presentation where the platform font supports it.

## Components

- Prefer Material 3 components and shared widgets under `lib/core/widgets/`.
- Feature-specific widgets stay under their feature's `presentation/widgets/`.
- Buttons use `FilledButton` for the primary action and `OutlinedButton` for secondary authentication or reversible actions.
- Inputs use filled white surfaces, 14 px radius and visible labels.
- Cards have zero elevation, white surface and consistent rounded corners.
- Charts must include a text summary for screen readers and users who cannot perceive color.

## Behavior rules

- Do not hardcode colors in feature screens; consume `AppColors` or `ColorScheme`.
- Do not format currency with string concatenation; use `CurrencyFormatter` or an equivalent locale-aware formatter.
- Do not place business rules in widgets.
- Use semantic route names and preserve state across bottom-navigation branches when the feature requires it.
