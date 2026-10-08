# Onboarding visual QA

## Evidence

- Source of visual truth: Figma `P0 / Onboarding`, node `329:2`, in `Personal Finance Mobile — ClearBudget`.
- Figma export used for inspection: `/tmp/clearbudget-onboarding-figma.png` (390 × 844 px; logical frame 390 × 844; 1×).
- Pre-change implementation screenshot: `/Users/allensalinas/Desktop/Screenshot_1791411527.png` (912 × 2048 px as supplied; resized from 1080 × 2424, approximately 2.33×; content shows the onboarding form with keyboard open).
- Post-change runtime evidence: Android E2E now reaches onboarding, creates the user profile and 16 localized categories, completes the financial flow, verifies the dashboard and holds it visible for 10 seconds. This run used only `demo-clearbudget` Emulator Suite; no real Firebase project was used. The test does not yet save a screenshot artifact, and a same-state onboarding screenshot has not been captured for pixel-level Figma comparison.
- Intended comparison state: onboarding, Spanish, keyboard dismissed, 390 × 844 logical viewport. The supplied screenshot has the keyboard open, so it is not the same state as the Figma frame.

## Findings from supplied screen and source

- [P1] The old screen used a large generic AppBar and a different content hierarchy from Figma's compact brand/title/helper header.
- [P1] The old form placed outlined dropdowns directly together; their floating labels visually collided and made field boundaries hard to scan.
- [P1] The language selector changed only the saved value; the visible labels kept using the app locale, producing mixed-language onboarding.
- [P2] The primary action was inside the scroll content and could be covered by the keyboard.

## Changes made

- Rebuilt only `CanonicalOnboardingScreen` using existing `AppColors`, Inter typography, Material 3 filled controls, explicit uppercase labels, 12 px field spacing, and 14 px rounded borders to follow the Figma frame.
- Replaced the generic app bar/progress treatment with the Figma brand, heading, and helper-copy hierarchy.
- Applied the selected locale immediately through `Localizations.override`.
- Kept the form scrollable and constrained its width on larger windows; pinned the primary CTA above the keyboard and kept it disabled until the account name is valid.
- Added Spanish, English, and Brazilian Portuguese helper copy and accessibility semantics for the account-name field.
- Added widget coverage for the initial selected language, CTA validation, compact width, increased text size, and keyboard insets.

## Required fidelity surfaces

- Typography: Inter is inherited from the app theme; heading and secondary hierarchy use Material 3 text roles. Post-change pixel comparison is not available.
- Spacing/layout: explicit header gaps, 12 px between form fields, and fixed bottom action; post-change pixel comparison is not available.
- Colors/tokens: existing ClearBudget `AppColors` are reused, not duplicated in the feature.
- Images/assets: the onboarding frame contains no static imagery requiring asset mapping.
- Copy: heading now follows the Figma frame (`Prepara tu espacio`) and all visible labels use the currently selected locale.

## Comparison history

- Initial review: found the four issues above from the supplied implementation screenshot and inspected Figma frame.
- Fixes: applied in `canonical_onboarding_screen.dart` and the three ARB resources; widget tests added.
- Post-fix runtime smoke: onboarding and dashboard navigation now pass on Android Emulator, disproving the earlier login/loading blocker. Pixel-level sign-off remains open because the E2E does not persist screenshots and the onboarding reference state has not yet been captured at the same viewport/state.

## Verification

- `flutter analyze`: passed after the final implementation and tests.
- `flutter test`: passed (54 tests).
- `git diff --check`: passed.
- Android Emulator E2E against `demo-clearbudget`: passed; onboarding profile complete, one account and 16 categories; canonical finance flow passed; final dashboard held for 10 seconds.
- Visual comparison: pending saved screenshot evidence at matching 390 × 844 logical viewport; this E2E run confirms functional rendering/navigation, not pixel fidelity.

## Final result

pending visual sign-off — runtime navigation now passes. Capture the onboarding and remaining P0 screens at a matching viewport/state before declaring visual acceptance.
