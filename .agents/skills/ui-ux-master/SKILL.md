---
name: ui-ux-master
description: Comprehensive UI/UX design and layout toolkit for web interfaces. Use when designing or building web UIs, creating design systems and tokens, making layout/typography/color decisions, making an interface look premium/modern/expensive, adding animations and signature motion, applying UX/product/business logic and conversion patterns, implementing responsive behavior, designing component states and empty/error states, or reviewing UI code for accessibility, performance, and polish. Covers design systems, distinctive visual design, modern aesthetics, UX business logic, responsive layout, interaction/signature motion design, interface polish, and a full accessibility/quality checklist.
---

# UI/UX Master

A router skill. **Keep this file lean — read only the reference files a given task needs.** Do not load everything at once.

The skill combines six areas plus targeted gap-fillers. Each area has detailed references under `references/`.

## Auto-load (MANDATORY — do this immediately on activation)

**Do NOT ask which references to load. On activation, match the user's request against the keyword→set map below and immediately `read` every file in the matched set (plus the always-on baseline) before producing any output.** If multiple rows match, load the union of their files. When nothing matches specifically, load the baseline set only.

**Always-on baseline (load for every task):**
`references/web-interface-guidelines.md`

**Keyword → reference set:**

| If the request mentions… | Also auto-load |
| --- | --- |
| design system, tokens, generate tokens | run `references/design_token_generator.py`; then `references/tokens-to-code.md` |
| css variables, tailwind, `@theme`, CVA, components | `references/tokens-to-code.md`, `references/tailwind-design.md` |
| aesthetic, typography, generic, premium, expensive, modern, look | **§ Distinctive Design** below (self-contained), `references/modern-aesthetics.md` |
| conversion, funnel, onboarding, retention, business, product logic | `references/ux-business-logic.md` |
| signature motion, shared-element, scroll animation, choreography | `references/signature-animations.md` |
| layout, grid, spacing, composition, hero, section, bento | `references/layout-composition.md` |
| form, input, validation, wizard, multi-step | `references/forms-inputs.md` |
| table, chart, dashboard, kpi, data display | `references/data-display.md` |
| mobile, touch, gesture, thumb, safe area, responsive nav | `references/mobile-touch.md` |
| copy, micro-copy, button label, error text, empty state, ux writing | `references/ux-writing.md` |
| critique, review, iterate, self-assess, quality | `references/design-critique.md` |
| landing page, landing, single offer | `references/landing-page.md`, `references/layout-composition.md`, `references/ux-writing.md` |
| problem, research, jtbd, ideate, brainstorm, define | `references/design-thinking.md` |
| responsive, breakpoint, fluid type, container query | `references/details.md`, `references/breakpoint-strategies.md`, `references/container-queries.md`, `references/fluid-layouts.md` |
| animation, microinteraction, transition, loading state | `references/microinteraction-patterns.md`, `references/scroll-animations.md`, `references/animation-libraries.md` |
| polish, radius, shadow, optical, enter/exit | `references/polish-surfaces.md`, `references/polish-animations.md`, `references/polish-typography.md`, `references/polish-performance.md` |
| component state, hover, focus, disabled, loading state | `references/component-states.md` |
| empty, error state, edge case, skeleton | `references/empty-error-states.md` |
| accessibility, a11y, screen reader, audit, contrast | `references/accessibility-testing.md` |
| ai slop, generic, boring, bland, cliché, template, avoid default | `references/anti-slop.md`, `references/modern-aesthetics.md` |
| component, architecture, composition, state, colocate, refactor, structure | `references/component-architecture.md` |

After loading, follow the workflow below and run the self-audit rubric before declaring the work done.

## Thinking Protocol (MANDATORY — reason before you build)

Do not jump to code or copy. Before producing any output, think through the task out loud using `<thinking>` blocks (or a short written reasoning pass) and work these steps in order. This is the "thinking power" of the skill — it forces design-lead reasoning instead of templated output.

1. **Name the real problem.** What is the user actually trying to accomplish? Restate it in one sentence as a job-to-be-done. Separate the stated request from the underlying need.
2. **Constraint & context map.** Who is the user? What device/context? What's fixed (brand, existing system, tech) vs free? What are the top 3 risks of getting it wrong?
3. **Generate options.** For the key decision (layout, aesthetic direction, copy angle, interaction), propose at least **2–3 structurally different** approaches — not variations of one. Note the trade-off of each.
4. **Decide with justification.** Pick one approach and state *why* it wins for this specific brief (impact, effort, fit). Explicitly say what you're rejecting and why.
5. **Plan the build.** Sequence the work (frame → system → aesthetic → layout → pieces → motion → copy → polish → audit). Identify the riskiest assumption and prototype/address it first.
6. **Self-check against principles.** Before final output, run the loaded references' MUST rules and the self-audit rubric mentally; note any dimension likely to score <1 and how you'll lift it.

Only after this reasoning should you write code, copy, or design. Surface the key reasoning to the user briefly (the chosen direction + the rejected alternatives + the one risk you're watching) so they can redirect early.

## When NOT to over-apply (gating)

- **Static, content-only pages**: skip interaction/animation references. Motion here reads as AI-generated noise.
- **Prototypes / throwaway demos**: skip the full a11y audit and token pipeline; keep only focus rings + semantics.
- **Existing design system present**: do NOT generate new tokens — consume the existing ones. Only add tokens, never fork the scale.
- **Small single-component edit**: read just the polish + component-states refs, not the whole workflow.
- **`prefers-reduced-motion` users**: reduce/disable motion regardless of what the interaction refs suggest.

## Recommended end-to-end workflow

1. **Frame the problem** — user job, primary action, success metric, funnel. → `design-thinking.md`, `ux-business-logic.md`
2. **System first** — tokens (color, type scale, spacing), responsive rules, a11y baseline. → `tokens-to-code.md`, `web-interface-guidelines.md`; for Tailwind, set tokens in `@theme` (`tailwind-design.md`)
3. **Aesthetic direction** — deliberate, non-templated choices; make it look premium. → § Distinctive Design + `modern-aesthetics.md`
4. **Layout & composition** — grid, spacing, section/hero/bento structure. → `layout-composition.md`
5. **Responsive & mobile** — mobile-first, fluid type, grid, container queries, touch. → responsive refs + `mobile-touch.md`
6. **Build the pieces** — forms, data displays, and their component states. → `forms-inputs.md`, `data-display.md`, `component-states.md`
7. **Interactions & signature motion** — purposeful feedback + one wow moment. → interaction refs + `signature-animations.md`
8. **Copy & edge states** — micro-copy plus loading/empty/error/offline. → `ux-writing.md`, `empty-error-states.md`
9. **Polish** — concentric radii, optical alignment, shadows, tabular numbers. → polish refs
10. **Critique & audit** — self-critique, accessibility, performance, rubric. → `design-critique.md`, `accessibility-testing.md`, `web-interface-guidelines.md`

---

## § Distinctive Design (self-contained)

Approach as the design lead at a studio known for identities that can't be mistaken for anyone else's. Make deliberate, opinionated choices about palette, typography, and layout specific to the brief; take one real aesthetic risk you can justify.

- **Ground it in the subject.** If the brief doesn't pin down the product, pin it yourself: subject, audience, the page's single job. Distinctive choices come from the subject's own materials, artifacts, and vernacular.
- **Hero is a thesis.** Open with the most characteristic thing. Avoid the template answer (big number + label + gradient) unless truly best.
- **Typography carries personality.** Pair display and body faces deliberately; set an intentional type scale.
- **Structure is information.** Numbering/eyebrows/dividers must encode something true. Only use `01/02/03` if content is genuinely a sequence.
- **Motion deliberately.** One orchestrated moment beats scattered effects; often less is more.
- **Match complexity to vision.** Maximalist needs elaborate execution; minimal needs precision.

**Anti-generic calibration.** AI design clusters around: (1) cream #F4F1EA + serif + terracotta; (2) near-black + one acid accent; (3) broadsheet hairline rules, zero radius, dense columns. Legitimate for some briefs but defaults, not choices. Follow the brief where it pins a direction; where an axis is free, don't spend it on a default.

**Process:** brainstorm a compact token plan (Color: 4–6 named hex; Type: 2+ roles; Layout: concept + ASCII wireframes; Signature: the one memorable element) → critique it against the brief and revise anything generic → build deriving every decision from the plan. Watch CSS selector specificity (type vs element selectors cancelling paddings). Spend boldness in one place; keep everything else quiet.

**Writing:** words make a design easier to use. Write from the user's side ("manage notifications", not "webhook config"), active voice ("Save changes", not "Submit"), consistent action names through a flow, errors/empty states as direction not mood, conversational register in sentence case.

---

## Self-Audit Rubric

Score each dimension 0–2 (0 = missing, 1 = partial, 2 = solid). **Do not ship below 1 on any row; target ≥ total 21/26.**

| # | Dimension | 0 | 1 | 2 |
| --- | --- | --- | --- | --- |
| 1 | **Business framing** | No clear goal | Job identified | Primary action + success metric drive the design |
| 2 | **Tokens** | Hard-coded hex/px | Some tokens | Everything derives from tokens |
| 3 | **Typographic hierarchy** | Flat/inconsistent | Basic scale | Deliberate scale, balanced wrapping |
| 4 | **Distinctiveness** | Generic default look | Some intent | Clear signature, non-templated |
| 5 | **Premium aesthetics** | Looks cheap/flat | Clean | Reads expensive: depth, restraint, tinted neutrals |
| 6 | **Responsive** | Breaks on mobile/wide | Works, minor issues | Fluid, tested mobile→ultra-wide |
| 7 | **Component states** | Only default | Most states | All applicable states incl. focus-visible |
| 8 | **Edge states** | None | Some | Loading/empty/error/offline all designed |
| 9 | **Motion** | None or janky | Present | Purposeful, springy, one signature moment, reduced-motion honored |
| 10 | **Polish** | Mismatched radii/borders | Some | Concentric radii, shadows, optical alignment |
| 11 | **Accessibility** | Fails basics | Keyboard+labels | APCA contrast, SR pass, semantics-first |
| 12 | **Performance** | CLS/jank | Acceptable | No CLS, virtualized lists, compositor-only anims |
| 13 | **Ethics** | Dark patterns present | Neutral | Persuasive without deception |

If any row scores 0, go back to the matching reference file before finishing.

---

## Reference index

- `references/ux-business-logic.md` — product thinking, conversion, funnels, flows, ethics
- `references/modern-aesthetics.md` — making it look premium: color systems, depth, glass, bento, anti-generic
- `references/signature-animations.md` — high-end motion: springs, shared-element, scroll, choreography
- `references/layout-composition.md` — grid, 8pt spacing, reading patterns, section/hero/bento patterns, balance
- `references/forms-inputs.md` — form flows, validation UX, input types, multi-step wizards, a11y
- `references/data-display.md` — tables, charts, KPI cards, dashboards, filtering/sorting/virtualization
- `references/mobile-touch.md` — touch targets, thumb zones, gestures, safe areas, responsive nav, platform conventions
- `references/ux-writing.md` — voice/tone, button/label/error copy, empty states, i18n-safe micro-copy
- `references/design-critique.md` — 7-lens critique, anti-slop audit, severity triage, iteration
- `references/landing-page.md` — high-conversion single-offer page: structure, layout types, copy templates, SEO/AEO, pitfalls
- `references/anti-slop.md` — concrete banned patterns + AI-slop test + color strategy + typography/layout bans
- `references/component-architecture.md` — composition over config, data/presentation split, state ladder, semantic tokens, focus management
- `references/design_token_generator.py` — generate tokens from a brand color (`python … "#3B82F6" modern css`)
- `references/tokens-to-code.md` — wire tokens into CSS vars, Tailwind v4, TypeScript, dark mode
- `references/details.md`, `references/breakpoint-strategies.md`, `references/container-queries.md`, `references/fluid-layouts.md` — responsive patterns
- `references/microinteraction-patterns.md`, `references/scroll-animations.md`, `references/animation-libraries.md` — interaction patterns
- `references/polish-typography.md`, `references/polish-surfaces.md`, `references/polish-animations.md`, `references/polish-performance.md` — UI polish details
- `references/component-states.md` — full component state matrix
- `references/empty-error-states.md` — loading/empty/error/edge states
- `references/accessibility-testing.md` — APCA, screen-reader flows, keyboard matrix, tooling
- `references/web-interface-guidelines.md` — full MUST/SHOULD/NEVER quality checklist (a11y, forms, perf, motion, dark mode)
- `references/design-thinking.md` — problem framing, JTBD, research, ideation, double diamond
- `references/tailwind-design.md` — Tailwind v4 tokens/`@theme`, CVA, component extraction, common mistakes
