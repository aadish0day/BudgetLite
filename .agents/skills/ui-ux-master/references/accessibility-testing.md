# Accessibility Testing (Depth)

Goes beyond the MUST/SHOULD checklist in `web-interface-guidelines.md`. Use this when auditing or building for real accessibility compliance, not just ticking boxes.

## Contrast: prefer APCA over WCAG 2

WCAG 2 contrast ratios are known to be inaccurate for dark backgrounds and thin fonts. Prefer [APCA](https://apcacontrast.com/).

| Text | WCAG 2 (min) | APCA (Lc, min) |
| --- | --- | --- |
| Body text (normal) | 4.5:1 | 75 |
| Large text (≥24px or ≥18.66px bold) | 3:1 | 60 |
| Non-text UI (borders, icons) | 3:1 | 45 |

Always **increase** contrast on `:hover`, `:active`, `:focus` — never decrease it.

## Screen reader flows to verify

Test at least one flow end-to-end with a real screen reader (VoiceOver on macOS/iOS, NVDA on Windows, TalkBack on Android):

1. **Landmark navigation** — user can jump between `<header>`, `<nav>`, `<main>`, `<footer>` via rotor/landmarks.
2. **Heading navigation** — headings form a logical `<h1>`→`<h6>` outline with no skipped levels.
3. **Form flow** — every field has an associated `<label>`; errors are announced via `aria-live="polite"`; on submit, focus moves to first error.
4. **Dynamic updates** — toasts, validation, and loading announce via `aria-live` without stealing focus.
5. **Modal/dialog** — focus traps inside, `Esc` closes, focus returns to the trigger on close.

## Keyboard test matrix

Run through every interactive component with keyboard only:

- `Tab` / `Shift+Tab` reaches everything in a logical order, nothing is trapped (except intentional modal traps).
- Visible focus ring on every focusable element (`:focus-visible`).
- `Enter`/`Space` activate buttons; `Enter` submits forms; arrow keys move within composite widgets (menus, tabs, radio groups) per [WAI-ARIA APG](https://www.w3.org/WAI/ARIA/apg/patterns/).
- Custom widgets match an APG pattern exactly (roles, states, key bindings).

## Semantics before ARIA

Reach for native elements first: `<button>`, `<a href>`, `<label>`, `<table>`, `<dialog>`, `<details>`. Only add ARIA when no native element fits. Wrong ARIA is worse than no ARIA.

- Icon-only buttons: `aria-label` describing the action.
- Decorative images/icons: `aria-hidden="true"` and empty `alt=""`.
- Status not conveyed by color alone — add an icon + text label.

## Automated + manual tooling

- **axe DevTools** / **Lighthouse** — catch ~30-40% of issues automatically. Never rely on them alone.
- **Keyboard-only pass** — unplug the mouse.
- **Screen reader pass** — one real device.
- **Zoom to 200%** and **400%** — content reflows, no horizontal scroll, no clipping.
- **`prefers-reduced-motion`** — enable it in OS settings and verify animations are reduced/disabled.
- **`prefers-contrast: more`** and forced-colors (Windows High Contrast) — UI stays usable.

## Quick audit checklist

- [ ] All contrast meets APCA thresholds (incl. hover/focus/active states)
- [ ] Logical heading outline, no skipped levels
- [ ] Every input has a programmatic label
- [ ] Errors announced and focus moves to first error on submit
- [ ] Full keyboard operability, visible focus everywhere
- [ ] Custom widgets follow an APG pattern
- [ ] Native semantics used before ARIA; ARIA correct where present
- [ ] Status uses redundant cues (icon + text, not color only)
- [ ] Reflows at 200%/400% zoom, no horizontal scroll
- [ ] `prefers-reduced-motion` and forced-colors respected
- [ ] One end-to-end screen reader pass completed
