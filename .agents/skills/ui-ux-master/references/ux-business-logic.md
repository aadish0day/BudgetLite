# UX Business Logic — Designing for Outcomes

UI that looks good but doesn't move a metric is decoration. This file connects interface decisions to business logic: user goals, conversion, retention, and the product thinking behind flows. Design the *system of decisions*, not just screens.

## Start from the job, not the screen

For any feature, answer before drawing anything:
1. **Who** is the user and what is their intent right now?
2. **What single job** is this screen doing? (One primary job per screen.)
3. **What is the success metric?** (signup, activation, purchase, task completion, return visit)
4. **What is the one primary action?** Everything else is secondary or tertiary.
5. **What happens on success / failure / empty?** (see `empty-error-states.md`)

If a screen has two "primary" buttons of equal weight, the design has already failed — pick one.

## Visual hierarchy = business priority

The eye should land on the thing that matters most to the business *and* the user, in that order of tension resolved in the user's favor.

- **One primary CTA** per view, highest contrast, largest tap target.
- Secondary actions are quieter (ghost/outline). Tertiary are text links.
- Destructive actions are visually distinct and never adjacent-by-accident to the primary.
- Use size, weight, color, and position (top-left/center gets seen first in LTR) deliberately — not decoratively.

## Conversion & funnel patterns

- **Reduce steps to value.** Every field, click, and screen between intent and payoff loses users. Cut ruthlessly; defer non-essential input (progressive profiling).
- **Show progress** in multi-step flows (stepper, % complete) — completion rates rise when the end is visible.
- **Anchor & frame** pricing: show the recommended plan pre-selected, most-popular badge, annual-vs-monthly toggle with savings called out.
- **Reduce risk** near the CTA: "No credit card", "Cancel anytime", trust badges, social proof close to the action, not buried.
- **Single-column forms** convert better than multi-column. Label above field. Inline validation *after* the user leaves the field, never while typing.
- **Smart defaults** beat empty inputs. Pre-fill, pre-select the common choice, remember the last choice.
- **Autosave over "Save"** where possible; if manual, keep the button enabled until the request starts.

## Onboarding & activation

- Define the **activation moment** (the action correlated with retention) and drive the whole onboarding toward it — nothing else.
- **Do, don't tell.** Interactive first-run beats a carousel of screenshots. Empty states are onboarding (see `empty-error-states.md`).
- **Sample/seed data** so a new account never looks broken or blank.
- **Checklist / progress** for setup tasks; celebrate completion.

## Cognitive load reduction

- **Hick's Law:** more choices = slower decisions. Group, prioritize, or reveal progressively.
- **Miller's Law:** chunk information (~5–7 items) — break long forms and menus into sections.
- **Jakob's Law:** users expect your product to work like the ones they already know. Don't reinvent standard patterns (search, nav, cart) without a reason.
- **Fitts's Law:** important/ frequent targets should be large and close; destructive ones smaller and guarded.
- **Recognition over recall:** show options, don't make users remember them (menus, autocomplete, recently-used).

## Feedback, trust & error prevention

- **Every action gets feedback** within 100ms (visual state) even if the result is async (optimistic UI + reconcile).
- **Prevent errors** before validating them: constrain inputs, disable impossible options, confirm destructive actions or offer Undo.
- **Undo beats confirm** for reversible actions — a toast with "Undo" is less friction than a modal.
- **Loading honesty:** skeletons for known layouts, keep button labels during loading, never a naked spinner where structure is known.
- **Empty ≠ broken:** guide the next step; never a blank screen.

## Retention & habit loops

- **Trigger → Action → Reward → Investment.** Design each stage: what brings them back, how easy the core action is, whether the reward is satisfying, what they invest (data, content, config) that makes leaving costly.
- **Notifications** are a budget — spend on genuinely useful, timely, actionable messages. Over-notifying churns users.
- **Streaks, progress, saved state** increase investment; use ethically, never dark-pattern.

## Ethics guardrail (no dark patterns)

Never: hidden costs, forced continuity without clear cancel, confirm-shaming ("No, I don't want to save money"), pre-checked upsells, fake urgency, roach-motel cancellation. These win a quarter and lose the brand. Persuasion is fine; deception is not.

## Decision checklist per screen/flow

- [ ] One clear primary job and one primary action
- [ ] Hierarchy matches user + business priority
- [ ] Steps-to-value minimized; non-essential input deferred
- [ ] Progress visible in multi-step flows
- [ ] Smart defaults and pre-selection used
- [ ] Feedback within 100ms for every action
- [ ] Errors prevented, not just reported; Undo where reversible
- [ ] Activation moment identified and prioritized in onboarding
- [ ] Empty/loading/error states designed
- [ ] No dark patterns
