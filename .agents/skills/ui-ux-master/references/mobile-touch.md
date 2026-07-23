# Mobile & Touch Design

Mobile isn't a shrunken desktop — it's a different interaction model: one hand, one thumb, small screen, variable connection, interruptions. Design for it first.

## Touch targets & the thumb zone

- **Minimum hit area 44×44px** (Apple HIG) / 48×48dp (Material). If the visible element is smaller, extend the hit area with padding or a pseudo-element.
- **Spacing between targets** ≥8px so fat-finger taps don't hit the wrong control.
- **Thumb zone:** the bottom-center of the screen is easiest to reach one-handed; top corners are hardest. Put **primary actions in the bottom third**, destructive/rare actions out of the easy path.
- **Bottom navigation / bottom sheets / floating action buttons** exist because of the thumb zone — prefer them over top-anchored primary actions on mobile.
- Never place two interactive elements' hit areas so they overlap.

## Gestures (with fallbacks)

- **Standard, discoverable gestures:** tap, scroll, swipe (dismiss/navigate carousels), long-press (context menu), pull-to-refresh, pinch-zoom on media.
- **Always provide a visible fallback** — never make a gesture the *only* way to do something (hidden gestures are undiscoverable). Swipe-to-delete needs a visible delete too.
- **Feedback on touch:** immediate visual response (`:active` state, ripple, `scale(0.96)`) — latency feels broken on touch.
- During drag, disable text selection and set `inert` on dragged elements; use `overscroll-behavior: contain` in modals/sheets/drawers to stop scroll chaining.
- Set `touch-action: manipulation` to remove the 300ms double-tap-zoom delay.

## Viewport, safe areas & zoom

- **Never disable zoom** — no `user-scalable=no` or `maximum-scale=1` (accessibility failure). Standard meta: `width=device-width, initial-scale=1`.
- **Respect safe areas** (notches, home indicator, rounded corners): `padding: env(safe-area-inset-*)` and `viewport-fit=cover`.
- **`100vh` is buggy** on mobile browsers (address bar). Use `100dvh` (dynamic viewport height) for full-height layouts.
- **16px minimum input font-size** to prevent iOS auto-zoom on focus.

## Responsive navigation patterns

- **Bottom tab bar:** 3–5 top-level destinations, always visible, thumb-reachable. Best for app-like products.
- **Hamburger drawer:** secondary/overflow nav; acceptable but hides content behind a tap — don't bury primary destinations in it.
- **Sticky/collapsing header:** shrinks on scroll to reclaim space; keep the key action pinned.
- **Segmented control** for switching views within a screen.
- Convert desktop mega-menus and side-nav deliberately; don't just shrink them.

## Layout for small screens

- **Single column**, stacked, generous vertical spacing.
- **Tables → cards** (one record per card) or horizontal scroll with a sticky first column.
- **Reduce, don't cram:** hide/relegate secondary info behind "show more" or detail views (progressive disclosure).
- **Fixed elements sparingly** — a fixed header + bottom bar already eat vertical space; avoid a third.
- Keyboard-aware: ensure focused inputs aren't hidden behind the on-screen keyboard (scroll into view).

## Performance & network (mobile reality)

- Mobile CPUs/networks are slower — **profile with CPU + network throttling** and test iOS Low Power Mode.
- Responsive images (`srcset`/`sizes`), preload above-fold, lazy-load the rest, explicit dimensions to prevent CLS.
- Minimize JS; virtualize long lists; keep interactions <100ms.
- Test on a real mid-range device, not just a desktop simulator.

## Platform conventions (respect them)

- **iOS:** back-swipe from left edge, share sheet, bottom sheets, momentum scroll. Don't fight the OS back gesture.
- **Android:** system back button/gesture, Material ripples, FAB, snackbars.
- Match native affordances where users expect them (Jakob's law); a familiar pattern beats a clever custom one.

## Checklist

- [ ] Hit targets ≥44×44px with ≥8px spacing
- [ ] Primary actions in the thumb zone (bottom third)
- [ ] Gestures have visible fallbacks; immediate touch feedback
- [ ] Zoom not disabled; safe areas respected; `100dvh` for full height
- [ ] Inputs ≥16px; focused input not hidden by keyboard
- [ ] Mobile nav pattern fits the product (bottom bar / drawer / collapsing header)
- [ ] Tables reflow to cards or scroll with sticky column
- [ ] Responsive images, lazy-load, CLS prevented
- [ ] Tested on a real mid-range device with throttling
- [ ] Platform back/gesture conventions respected
