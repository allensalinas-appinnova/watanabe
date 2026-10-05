# UI/UX Guidelines

## Product principles

1. **Clarity before density.** Show the user's balance, cash flow and budget status before secondary actions.
2. **One primary action per surface.** A screen or form should have one visually dominant next step.
3. **Safe financial actions.** Destructive operations, retroactive movements and transfers require explicit confirmation and clear consequences.
4. **Progressive disclosure.** Keep the first view simple; reveal filters, advanced import options and details on demand.
5. **Trust through feedback.** Every remote operation exposes loading, success, empty, offline and error states.

## Mobile layout

- Design baseline: 390 × 844 logical pixels, scalable to compact phones and large phones.
- Respect safe areas, system text scaling and platform back navigation.
- Use a four-destination bottom navigation for Inicio, Actividad, Presupuesto and Cuentas.
- Keep primary controls reachable with one hand and place destructive actions away from the primary action.
- Use cards for grouped financial summaries, not as decoration for every isolated field.

## Forms and financial data

- Use explicit labels, not placeholder-only fields.
- Validate on submit and provide field-level messages in the user's language.
- Display currency, dates and percentages using the selected locale.
- Preserve user input on recoverable network errors.
- Show the account, category and date in every transaction confirmation.

## Accessibility

- Maintain WCAG AA contrast for text and controls.
- Minimum interactive target: 48 × 48 logical pixels.
- Never communicate state by color alone; pair color with icon, label or text.
- Provide semantic labels for balance visibility, account type, transaction type and chart summaries.
- Support dynamic text size without clipping or horizontal overflow.

## States required for every feature

- loading;
- loaded;
- empty with a useful next action;
- offline or stale data;
- recoverable error with retry;
- permission/authentication error;
- destructive confirmation where applicable.

## Figma relationship

The current mobile concept is in the Figma file `Personal Finance Mobile — ClearBudget`. Figma is the visual reference; Flutter theme tokens and reusable widgets are the implementation source of truth.
