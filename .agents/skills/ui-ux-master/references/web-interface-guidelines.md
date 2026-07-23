# Web Interface Guidelines

Concise, opinionated rules for building accessible, fast, and delightful web interfaces. Rules use **MUST / SHOULD / NEVER** so they can be applied mechanically during design and review. This is the "house style" baseline — pair it with `tailwind-design.md` (implementation), `accessibility-testing.md` (verification), and `polish-*` / `modern-aesthetics.md` (visual quality).

## Quick reference

| Area | Key rules |
| --- | --- |
| Interactions / Keyboard | Full keyboard support; visible focus; managed focus on modals |
| Targets & Input | Hit area ≥24px (mobile 44px); input ≥16px on mobile; never block zoom |
| Forms | Inline validation; no dead zones; warn on unsaved changes |
| State & Nav | URL reflects state; links are real `<a>`; no `<div onClick>` nav |
| Feedback | Optimistic UI; Undo or confirm; `aria-live` for toasts |
| Animation | Honor `prefers-reduced-motion`; only `transform`/`opacity`; no `transition: all` |
| Layout | Optical alignment; safe areas; no accidental scrollbars |
| Color & Contrast | Meet APCA/WCAG; redundant cues; not color-only |
| Typography | `tabular-nums` for numbers; `text-wrap: balance`; locale-aware |
| Components | Every state designed; native semantics before ARIA |
| Mobile | `100dvh`; `env(safe-area-inset-*)`; thumb-zone actions |
| Performance | Virtualize >50 items; <500ms mutations; preload critical fonts |
| Dark mode | `color-scheme: dark`; theme-color matching; explicit `<select>` colors |
| Hydration | Controlled inputs need `onChange`; guard date/time |

## Interactions

### Keyboard

- MUST: Full keyboard support per [WAI-ARIA APG](https://www.w3.org/WAI/ARIA/apg/patterns/)
- MUST: Visible focus rings (`:focus-visible`; group with `:focus-within`)
- MUST: Manage focus (trap, move, return) per APG patterns
- NEVER: `outline: none` without visible focus replacement

### Targets & Input

- MUST: Hit target ≥24px (mobile ≥44px); if visual <24px, expand hit area
- MUST: Mobile `<input>` font-size ≥16px to prevent iOS zoom
- NEVER: Disable browser zoom (`user-scalable=no`, `maximum-scale=1`)
- MUST: `touch-action: manipulation` to prevent double-tap zoom
- SHOULD: Set `-webkit-tap-highlight-color` to match design

### Forms

- MUST: Hydration-safe inputs (no lost focus/value)
- NEVER: Block paste in `<input>`/`<textarea>`
- MUST: Loading buttons show spinner and keep original label
- MUST: Enter submits focused input; in `<textarea>`, ⌘/Ctrl+Enter submits
- MUST: Keep submit enabled until request starts; then disable with spinner
- MUST: Accept free text, validate after—don't block typing
- MUST: Allow incomplete form submission to surface validation
- MUST: Errors inline next to fields; on submit, focus first error
- MUST: `autocomplete` + meaningful `name`; correct `type` and `inputmode`
- SHOULD: Disable spellcheck for emails/codes/usernames
- SHOULD: Placeholders end with `…` and show example pattern
- MUST: Warn on unsaved changes before navigation
- MUST: Compatible with password managers & 2FA; allow pasting codes
- MUST: Trim values to handle text expansion trailing spaces
- MUST: No dead zones on checkboxes/radios; label+control share one hit target

### State & Navigation

- MUST: URL reflects state (deep-link filters/tabs/pagination/expanded panels)
- MUST: Back/Forward restores scroll position
- MUST: Links use `<a>`/`<Link>` for navigation (support Cmd/Ctrl/middle-click)
- NEVER: Use `<div onClick>` for navigation

### Feedback

- SHOULD: Optimistic UI; reconcile on response; on failure rollback or offer Undo
- MUST: Confirm destructive actions or provide Undo window
- MUST: Use polite `aria-live` for toasts/inline validation
- SHOULD: Ellipsis (`…`) for options opening follow-ups ("Rename…") and loading states ("Loading…")

### Touch & Drag

- MUST: Generous targets, clear affordances; avoid finicky interactions
- MUST: Delay first tooltip; subsequent peers instant
- MUST: `overscroll-behavior: contain` in modals/drawers
- MUST: During drag, disable text selection and set `inert` on dragged elements
- MUST: If it looks clickable, it must be clickable

### Autofocus

- SHOULD: Autofocus on desktop with single primary input; rarely on mobile

## Animation

- MUST: Honor `prefers-reduced-motion` (provide reduced variant or disable)
- SHOULD: Prefer CSS > Web Animations API > JS libraries
- MUST: Animate compositor-friendly props (`transform`, `opacity`) only
- NEVER: Animate layout props (`top`, `left`, `width`, `height`)
- NEVER: `transition: all`—list properties explicitly
- SHOULD: Animate only to clarify cause/effect or add deliberate delight
- SHOULD: Choose easing to match the change (size/distance/trigger)
- MUST: Animations interruptible and input-driven (no autoplay)
- MUST: Correct `transform-origin` (motion starts where it "physically" should)
- MUST: SVG transforms on `<g>` wrapper with `transform-box: fill-box`

## Layout

- SHOULD: Optical alignment; adjust ±1px when perception beats geometry
- MUST: Deliberate alignment to grid/baseline/edges—no accidental placement
- SHOULD: Balance icon/text lockups (weight/size/spacing/color)
- MUST: Verify mobile, laptop, ultra-wide (simulate ultra-wide at 50% zoom)
- MUST: Respect safe areas (`env(safe-area-inset-*)`)
- MUST: Avoid unwanted scrollbars; fix overflows
- SHOULD: Flex/grid over JS measurement for layout

## Color & Contrast

- MUST: Meet contrast minimums — prefer [APCA](https://apcacontrast.com/) over WCAG 2 for modern UIs; otherwise WCAG AA (4.5:1 text, 3:1 large text/UI)
- MUST: Increase contrast on `:hover`/`:active`/`:focus` (not decrease)
- MUST: Redundant status cues—never rely on color alone (pair color with icon/label/pattern)
- SHOULD: Tint neutrals toward the background hue for cohesion (see `modern-aesthetics.md`)
- MUST: Accessible charts/visualizations—color-blind-safe palettes
- SHOULD: Avoid dark gradient banding on large surfaces (use subtle noise/background image)
- SHOULD: Match browser chrome/`theme-color` to page background

## Typography

- MUST: `font-variant-numeric: tabular-nums` for number comparisons and tables
- SHOULD: `text-wrap: balance` for headings; `text-wrap: pretty` for body
- SHOULD: Curly quotes (" "); avoid widows/orphans
- MUST: Locale-aware dates/times/numbers (`Intl.DateTimeFormat`, `Intl.NumberFormat`)
- SHOULD: `translate="no"` on brand names, code tokens, identifiers to prevent garbled auto-translation
- MUST: Non-breaking spaces: `10&nbsp;MB`, `⌘&nbsp;K`, brand names
- SHOULD: Respect `font-display: swap`; preload critical fonts (see Performance)
- MUST: Design for text expansion (~30% longer than English) for i18n

## Components & State

- MUST: Enumerate every state before styling: default, hover, focus, active, disabled, loading, error, empty, success (see `component-states.md`)
- MUST: Prefer native semantics (`button`, `a`, `label`, `table`) before ARIA
- MUST: Accessible names exist even when visuals omit labels
- MUST: Icon-only buttons have descriptive `aria-label`; decorative elements `aria-hidden`
- MUST: Accurate `aria-label`; meaningful `name`/`autocomplete` on inputs
- SHOULD: Skip-to-content link; hierarchical `<h1>`–`<h6>`; `scroll-margin-top` on headings
- MUST: Skeletons mirror final content to avoid layout shift
- MUST: No dead ends—always offer a next step / recovery path
- MUST: Design empty, sparse, dense, and error states explicitly

## Mobile & Viewports

- MUST: Use `100dvh` (not `100vh`) for full-height layout—mobile browser chrome changes
- MUST: Respect safe areas (`env(safe-area-inset-*)`) for notches/home indicators
- MUST: Primary actions reachable in the thumb zone (bottom ~⅓ on phones)
- SHOULD: Bottom sheets/drawers for mobile flows; side panels for desktop
- MUST: Test at real device widths (320–480px), not just resized desktop
- SHOULD: Avoid hover-only affordances on touch (provide tap/tap-hold equivalents)

## Content Handling

- MUST: Text containers handle long content (`truncate`, `line-clamp-*`, `break-words`)
- MUST: Flex children need `min-w-0` to allow truncation
- MUST: Handle empty states—no broken UI for empty strings/arrays
- MUST: Resilient to user-generated content (short / average / very long)
- SHOULD: Inline help first; tooltips last resort (see `ux-writing.md`)

## Performance

- SHOULD: Test iOS Low Power Mode and macOS Safari
- MUST: Measure reliably (disable extensions that skew runtime)
- MUST: Track and minimize re-renders (React DevTools/React Scan)
- MUST: Profile with CPU/network throttling
- MUST: Batch layout reads/writes; avoid reflows/repaints
- MUST: Mutations (`POST`/`PATCH`/`DELETE`) target <500ms
- SHOULD: Prefer uncontrolled inputs; controlled inputs cheap per keystroke
- MUST: Virtualize large lists (>50 items)
- MUST: Preload above-fold images; lazy-load the rest
- MUST: Prevent CLS (explicit image dimensions)
- SHOULD: `<link rel="preconnect">` for CDN domains
- SHOULD: Critical fonts: `<link rel="preload" as="font">` with `font-display: swap`

## Dark Mode & Theming

- MUST: `color-scheme: dark` on `<html>` for dark themes
- SHOULD: `<meta name="theme-color">` matches page background
- MUST: Native `<select>`: explicit `background-color` and `color` (Windows fix)
- SHOULD: Re-tune (not just invert) accent contrast for dark surfaces

## Hydration

- MUST: Inputs with `value` need `onChange` (or use `defaultValue`)
- SHOULD: Guard date/time rendering against hydration mismatch

## Design Quality

- SHOULD: Layered shadows (ambient + direct)
- SHOULD: Crisp edges via semi-transparent borders + shadows
- SHOULD: Nested radii: child ≤ parent; concentric
- SHOULD: Hue consistency: tint borders/shadows/text toward bg hue
- MUST: Meet contrast—prefer APCA over WCAG 2
- MUST: Increase contrast on `:hover`/`:active`/`:focus`
- SHOULD: Match browser UI to bg
- SHOULD: Avoid dark color gradient banding (use background images when needed)

## Self-audit (run before shipping)

- [ ] Every interactive element reachable by keyboard with a visible focus ring
- [ ] Forms validate inline; no dead zones; paste allowed; unsaved-changes warned
- [ ] URL reflects navigable state; real `<a>` for links
- [ ] Animations honor `prefers-reduced-motion`; only transform/opacity; no `transition: all`
- [ ] Contrast meets APCA/WCAG; status not color-only
- [ ] Numbers `tabular-nums`; text expands 30%; locale-aware formatting
- [ ] All component states designed; native semantics before ARIA
- [ ] Mobile uses `dvh` + safe areas; primary action in thumb zone
- [ ] No CLS; lists >50 virtualized; mutations <500ms
- [ ] Dark mode sets `color-scheme` and re-tuned accents
