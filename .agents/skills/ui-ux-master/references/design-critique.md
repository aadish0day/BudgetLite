# Design Critique Framework

How to review a design like a senior designer — structured, honest, and actionable. Run this on your own work *while building* and before shipping. The goal is to catch the difference between "it works" and "it's good."

## The mindset

- **Critique the work, propose the fix.** Every observation pairs with a concrete change, not just "this feels off."
- **Squint test:** blur your eyes (or the screenshot). What stands out? If the wrong thing is loudest, hierarchy is broken.
- **Take screenshots and look at them.** You see problems in a static image you miss while building — a picture is worth 1000 tokens.
- **Compare to the bar.** Would this ship at Linear/Stripe/Vercel? If not, name specifically why.
- **Kill your darlings.** Chanel's rule: before finishing, remove one thing. The clever element you're attached to is often the one to cut.

## The 7-lens pass

Review in this order — each lens catches a different class of problem.

### 1. Purpose & hierarchy
- Is the single primary job of this screen obvious in 3 seconds?
- Is there exactly one primary action, clearly dominant?
- Does the visual weight match the business + user priority?
- **Squint test:** does the most important element win?

### 2. Layout & spacing
- Is everything on the spacing scale (no one-off gaps)?
- Aligned to a grid? Any accidental misalignment?
- Is whitespace doing the grouping, or are there redundant borders?
- Line length capped? Content in a max-width container?

### 3. Typography
- Clear scale with intentional weight/size contrast?
- Headings tracked-in, `text-wrap: balance`? Body at comfortable measure?
- Consistent — not five sizes doing the job of two?

### 4. Color & contrast
- One accent, meaningful use of color (not decorative)?
- Neutrals tinted, not pure gray/black/white?
- Contrast passes APCA, including hover/focus/active?
- Status conveyed by more than color?

### 5. Depth & polish
- Layered shadows + semi-transparent borders (no bare 1px gray lines)?
- Concentric, consistent radii?
- Icons optically centered? Images have subtle outlines?
- Does it look *expensive* or does it look flat/templated?

### 6. States & flows
- All component states designed (hover/focus/active/disabled/loading/error)?
- Empty / loading / error / offline states handled?
- What happens on failure? Any dead ends?
- Does the flow minimize steps to value?

### 7. Motion & responsiveness
- Is motion purposeful, springy, interruptible — one signature moment, not noise?
- `prefers-reduced-motion` honored?
- Works mobile → ultra-wide? Thumb-reachable on mobile?

## Anti-generic audit (the AI-slop check)

Ask honestly: *would I produce this exact design for any similar prompt?* If yes, it's a default, not a decision. Red flags:
- Cream + serif + terracotta / near-black + one acid accent / broadsheet hairlines
- Purple-blue gradient hero + "big number, small label" + three identical feature cards
- Numbered `01/02/03` markers on content that isn't actually a sequence
- Everything centered; equal visual weight everywhere; generic stock-photo energy

If any apply, revise that axis and state what you changed and why.

## Severity triage

Label each finding so effort goes where it matters:

- **P0 — Blocker:** broken flow, inaccessible, unusable on mobile, dead end. Fix before ship.
- **P1 — Quality:** weak hierarchy, generic look, missing states, inconsistent spacing. Fix before calling it good.
- **P2 — Polish:** optical alignment, micro-copy, subtle motion. Fix if time allows; these compound into "feels premium."

## Output format

Present critique as grouped findings with fixes, not vague vibes:

```
### Hierarchy  [P1]
- Two equal-weight CTAs compete → make "Get started" primary (accent, filled),
  demote "Learn more" to a ghost button.

### Spacing  [P2]
- Section gaps vary (28px, 40px, 36px) → snap all to 32/48 scale.
```

Group by lens, tag severity, one fix per line. If a lens is clean, say so briefly and move on.

## The final gate

Before declaring done, run the **Self-Audit Rubric** in `SKILL.md`. If any dimension scores 0, return to the matching reference file. Don't ship on "good enough" when a P1 is still open.
