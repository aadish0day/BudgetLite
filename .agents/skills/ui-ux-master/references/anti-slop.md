# Anti-Slop — Concrete Banned Patterns

`design-critique.md` scores by lens. This file is the opposite: a concrete match-and-refuse list of patterns that announce "AI made this." If you're about to write any of these, rewrite the element with different structure. Use it during the build and the final critique pass.

## The AI-slop test

If someone could look at the interface and say "AI made that" without doubt, it failed. Run it at two altitudes:

- **First-order reflex:** if someone could guess the theme + palette from the category alone (e.g. "AI tool → cream + serif + terracotta", "fintech → navy + gold"), it's the first training-data reflex. Rework the color strategy until the answer isn't obvious from the domain.
- **Second-order reflex:** if someone could guess the aesthetic family from category-plus-anti-patterns ("AI workflow tool that's not SaaS-cream → editorial-typographic"), the first reflex was avoided but the second wasn't. Rework until both answers are non-obvious.

## Absolute bans (match-and-refuse)

- **Cream/sand/paper body bg as default.** The warm-neutral band (OKLCH L 0.84–0.97, C < 0.06, hue 40–100) reads as cream/sand/parchment regardless of token name (`--paper`, `--cream`, `--linen`, `--ivory` are tells). "Warmth" belongs in accent + typography + imagery, not body bg. Pick a saturated brand color, a true off-white at chroma 0, or a darker mid-tone tinted neutral.
- **Side-stripe borders.** `border-left`/`border-right` >1px as a colored accent on cards, list items, callouts, alerts. Rewrite with full borders, background tints, leading numbers/icons, or nothing.
- **Gradient text.** `background-clip: text` + gradient background. Decorative, never meaningful. Use a single solid color; emphasis via weight or size.
- **Glassmorphism as default.** Blurs/glass cards used decoratively. Rare and purposeful, or nothing.
- **The hero-metric template.** Big number + small label + supporting stats + gradient accent. SaaS cliché.
- **Identical card grids.** Same-sized cards (icon + heading + text) repeated endlessly. Purpose-driven layouts instead.
- **Tiny uppercase tracked eyebrow above *every* section.** The all-caps kicker ("ABOUT" / "PROCESS" / "PRICING") on every heading is the saturated AI scaffold. One named kicker as a deliberate brand voice is fine; an eyebrow on every section is AI grammar. Choose a different cadence.
- **Numbered section markers as default scaffolding (01 / 02 / 03).** Numbers earn their place only when the section actually *is* a sequence (real 3-step process, ordered flow, typed timeline) and the order carries information. One deliberate numbered sequence per page is voice; numbered eyebrows everywhere is AI grammar.
- **Text overflowing its container.** Long heading words + large clamp scales + narrow grids overflow on tablet/mobile. Test heading copy at every breakpoint; if it overflows, reduce the clamp max or rewrite the copy. The viewport is part of the design.
- **Purple/indigo everything.** Models default to visually "safe" palettes, making every app look identical. Use the project's actual palette.
- **Excessive gradients & rounded-everything.** Gradients add noise; max rounding (`rounded-2xl` everywhere) ignores the hierarchy of corner radii. Flat/subtle + consistent radii from the design system.
- **Lorem ipsum placeholder copy.** Hides layout problems real content reveals (length, wrapping, overflow). Use realistic placeholder content.
- **Oversized uniform padding.** Equal generous padding destroys hierarchy and wastes space. Use the consistent spacing scale with intentional variation for rhythm.
- **Shadow-heavy design.** Layered shadows compete with content and slow low-end rendering. Subtle or none unless the design system specifies.
- **Nested cards.** Almost always wrong — reach for a different affordance.

## Color strategy (pick before picking colors)

Four steps on the commitment axis:
- **Restrained** — tinted neutrals + one accent ≤10%. Product default; brand minimalism.
- **Committed** — one saturated color carries 30–60% of the surface. Identity-driven pages.
- **Full palette** — 3–4 named roles, each used deliberately. Brand campaigns; data viz.
- **Drenched** — the surface *is* the color. Brand heroes, campaign pages.

## Typography bans & ceilings

- Body line length capped at 65–75ch.
- Don't pair fonts that are similar-but-not-identical (two geometric sans, two humanist sans). Pair on a contrast axis (serif + sans, geometric + humanist) or use one family in multiple weights.
- Display heading ceiling: `clamp()` max ≤ 6rem (~96px). Above that the page is shouting.
- Display letter-spacing floor: ≥ -0.04em. Tighter and letters touch.
- `text-wrap: balance` on h1–h3; `text-wrap: pretty` on long prose.
- Muted gray body text on tinted near-white is the #1 readability failure. If contrast is close, bump the body color toward the ink end of the ramp.

## Layout bans

- Flexbox for 1D, Grid for 2D. Don't default to Grid when `flex-wrap` is simpler.
- Responsive grids without breakpoints: `repeat(auto-fit, minmax(280px, 1fr))`.
- Semantic z-index scale (dropdown → sticky → modal-backdrop → modal → toast → tooltip). Never arbitrary `999`/`9999`.
- Dropdowns in `overflow: hidden/auto` containers get clipped — use `<dialog>`/popover, `position: fixed`, or a portal.

## Quick self-check

- [ ] No warm-neutral cream body bg by reflex
- [ ] No eyebrow / 01·02·03 on every section
- [ ] No gradient text, side-stripe borders, decorative glass
- [ ] No identical card grid or hero-metric template
- [ ] Heading doesn't overflow at 320/375px
- [ ] Color strategy named; contrast verified (≥4.5:1 body)
- [ ] z-index on a named scale; flex/grid used appropriately
