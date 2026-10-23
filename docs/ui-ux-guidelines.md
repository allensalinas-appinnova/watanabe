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
- Use the five-destination bottom navigation in this order: Inicio, Actividad,
  Cuentas, Plan and Coach. Use Configuración for global preferences; do not add
  a mobile drawer alongside the tab bar.
- Keep the global registration action on Inicio and Actividad only. Use
  destination-specific actions on Cuentas, Plan and Coach.
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

The current mobile concept is in the Figma file `Personal Finance Mobile — ClearBudget`.
For P0 implementation, **`07 P0 Screens` (page `325:3059`) is the canonical
screen and state reference**. **`00 Current Baseline` is a comparison page**
that records existing product patterns; it is not a parallel implementation
target. Flutter theme tokens and reusable widgets remain the implementation
source of truth for code.

When reconciling a screen, inspect both Figma pages before changing the design.
Keep useful established patterns from `00 Current Baseline`—including tab
icons, top-right header actions, and existing navigation affordances—unless a
documented UX decision supersedes them. Apply approved changes to the matching
screen in `07 P0 Screens`, and update its connected states and prototype links
there. Do not maintain separate competing versions of the same P0 screen.

Every design-to-code task must identify the Figma file, canonical page, and
frame name (and node ID when available). Verify the target page by its actual
page node ID when using Figma tools; a file-level page listing may be
incomplete. If a target cannot be confirmed, request its page/frame URL before
editing. A completed design reconciliation should note which baseline pattern
was retained, changed, or intentionally omitted so later iterations do not
reopen the same discrepancy.
