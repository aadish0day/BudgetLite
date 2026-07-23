# Signature Animations — Damn-Good, Modern Motion

High-end motion (Linear / Stripe / Vercel / Apple / Family caliber). This goes beyond `microinteraction-patterns.md` and `polish-animations.md`: it's about *taste* — the difference between "it animates" and "it feels alive." Read `animation-libraries.md` for tooling and `polish-performance.md` for the perf rules.

## The taste rules

1. **Motion confirms cause and effect** — it should explain what happened or where something came from, never just decorate.
2. **Fast in, gentle out.** Enters are quick (150–250ms); the settle is where the quality lives (spring, not linear).
3. **Spring physics over duration/easing** for anything interactive — it feels physical. Reserve keyframes/cubic-bezier for one-shot choreography.
4. **Interruptible always.** A user re-triggering mid-animation must be honored instantly. Use transitions or spring, not blocking timelines.
5. **Compositor-only props:** animate `transform` and `opacity` (and `filter` sparingly). Never `width/height/top/left` — see `polish-performance.md`.
6. **Respect `prefers-reduced-motion`** — provide a reduced variant (fade/instant), don't just disable.
7. **Less, but better.** Over-animation is the #1 tell of an AI/amateur UI. One orchestrated moment beats twenty micro-bounces.

## The spring values that feel premium

```ts
// Motion (framer-motion) — bounce must be 0 for UI (bouncy = toy-like)
const smooth   = { type: "spring", stiffness: 400, damping: 40, mass: 1 };   // buttons, toggles
const gentle   = { type: "spring", stiffness: 200, damping: 30 };            // panels, cards
const snappy   = { type: "spring", stiffness: 500, damping: 35 };            // menus, popovers
const dramatic = { type: "spring", stiffness: 120, damping: 22 };            // hero, modal enter
```

CSS easings for one-shot/keyframe work:
```css
--ease-out-quart: cubic-bezier(0.25, 1, 0.5, 1);      /* premium decel */
--ease-out-expo:  cubic-bezier(0.16, 1, 0.3, 1);      /* dramatic decel */
--ease-in-out:    cubic-bezier(0.65, 0, 0.35, 1);     /* moving between */
--ease-spring:    linear(0, 0.5, 0.9, 1.02, 1, 1);    /* spring-like in CSS (Chrome/Safari) */
```

## Signature moves (the ones people remember)

### 1. Staggered content reveal (page/section load)
Break content into semantic chunks, stagger ~60–100ms. Fast, subtle, once.
```tsx
<motion.div initial="hidden" animate="show"
  variants={{ show: { transition: { staggerChildren: 0.06 } } }}>
  {items.map((it) => (
    <motion.div key={it.id}
      variants={{ hidden: { opacity: 0, y: 12 }, show: { opacity: 1, y: 0 } }}
      transition={{ type: "spring", stiffness: 300, damping: 30 }}>
      {it.content}
    </motion.div>
  ))}
</motion.div>
```

### 2. Shared-element / layout transitions (the Linear/Family magic)
Elements morph between states/positions instead of cutting.
```tsx
<motion.div layout layoutId={`card-${id}`}
  transition={{ type: "spring", stiffness: 300, damping: 35 }} />
```
Use `layoutId` for expand-from-thumbnail, tab indicators that slide, list reordering. This single feature reads as "expensive" more than any other.

### 3. Magnetic / spotlight hover (buttons, cards)
Cursor-aware micro-motion + a radial glow that follows the pointer. Subtle: translate ≤6px, glow low-opacity. Disable on touch and reduced-motion.

### 4. Scroll-driven reveal & parallax
Prefer the native **Scroll-Driven Animations API** (`animation-timeline: view()`) where supported for jank-free, JS-free reveals; fall back to IntersectionObserver / GSAP ScrollTrigger. Keep parallax shifts small (≤10%). Details in `scroll-animations.md`.
```css
@supports (animation-timeline: view()) {
  .reveal { animation: reveal linear both; animation-timeline: view(); animation-range: entry 0% cover 30%; }
  @keyframes reveal { from { opacity: 0; transform: translateY(24px); } to { opacity: 1; transform: none; } }
}
```

### 5. Number roll / counter
Animate value changes with `tabular-nums` so there's no layout shift; ease-out the count-up on first view.

### 6. Icon state cross-fade (not toggle)
Animate `opacity`/`scale`/`blur` between icons (scale 0.25→1, opacity 0→1, blur 4px→0), `bounce: 0`. Never pop-swap. (See `polish-animations.md`.)

### 7. Press feedback
`scale(0.96)` on active, spring back. Never below `0.95`. Disable during `disabled`.

### 8. Toast / notification entrance
Slide + fade from the edge with a gentle spring; subtle exit (small `translateY`, faster than enter). Stack with layout animation so siblings reflow smoothly.

## Choreography: sequence, don't dump

A hero load that lands: background glow fades in → headline reveals (mask/blur-in) → subhead + CTA stagger → ambient loop starts. Each step ~80–120ms apart. One orchestrated 600–900ms sequence beats ten independent animations firing at once.

## Modern text effects (use one, not all)
- **Blur-in reveal:** `filter: blur(8px)→0` + `opacity` + slight `y`.
- **Mask/wipe reveal:** overflow-clip a line, translate it up into view (great for editorial headings — see `scroll-animations.md`).
- **Gradient sheen** sweeping across a heading once on load.

## Performance & accessibility gates
- Animate only `transform`/`opacity`/`filter`; `will-change` only when you see first-frame stutter, never `will-change: all`.
- No `transition: all` — list properties.
- 60fps target; profile with CPU throttling. Virtualize animated lists.
- `@media (prefers-reduced-motion: reduce)` → replace motion with instant/fade; keep functionality identical.

## Taste checklist
- [ ] Every animation explains cause/effect (nothing purely decorative)
- [ ] Springs for interactive, `bounce: 0`; keyframes only for one-shots
- [ ] At most one signature "wow" moment per view
- [ ] Enters fast, settles gentle; exits subtle and quick
- [ ] Layout/shared-element transitions used where things move between states
- [ ] Scroll reveals subtle, native API where possible
- [ ] Compositor-only props; interruptible; 60fps
- [ ] `prefers-reduced-motion` variant provided
- [ ] Nothing bounces like a toy; nothing over-animates
