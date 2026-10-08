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
- Use `FilledButton` for the primary action, `OutlinedButton` for a secondary/reversible action, and `TextButton` for low-emphasis inline actions.
- Full-width primary calls to action use a 52 px height, 14 px corner radius, and centered label. On narrow layouts they may grow vertically only when accessibility text scaling requires it.
- Enabled primary buttons use `blueDark` with white text. Disabled primary buttons use `blueSoft` with `navy` text; do not render disabled actions as solid blue. Loading keeps the button's dimensions and replaces its label with a progress indicator.
- Secondary buttons use a white surface, `line` outline, `navy` label, the same 52 px minimum height and 14 px radius, with a centered label. Text buttons keep compact, context-appropriate alignment and a minimum 48 px touch target.
- Icon-only buttons are a separate role: center the icon, provide a visible tooltip/semantic label, and retain a minimum 48 × 48 px target. Do not apply the full-width CTA alignment rule to them.
- Keep button labels concise and action-oriented, localized, and consistent with the action being performed (for example, “Continuar”, not “Comenzar” when advancing an existing setup flow).
- Inputs use filled white surfaces, 14 px radius and visible labels.
- Financial forms use a label above the control (`FinanceLabeledField`), not a floating label embedded in the field. Keep 12 px between fields and 7 px between label and control.
- Income and expense share one form and one 48 px segmented type selector (`FinanceOperationTypeSelector`). The initial selection follows the entry point; the user can switch types before saving.
- Income and expense save directly after validation. A transfer must show a review confirmation with amount, source, and destination before writing; cancellation must not submit it.
- Budget item amounts and totals use the user's profile default currency and its minor-unit scale, not a hard-coded currency.
- Cards have zero elevation, white surface and consistent rounded corners.
- Charts must include a text summary for screen readers and users who cannot perceive color.

## Behavior rules

- Do not hardcode colors in feature screens; consume `AppColors` or `ColorScheme`.
- Do not format currency with string concatenation; use `CurrencyFormatter` or an equivalent locale-aware formatter.
- Do not place business rules in widgets.
- Use semantic route names and preserve state across bottom-navigation branches when the feature requires it.
