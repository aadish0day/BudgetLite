# Layout & Composition

How to arrange things on a page so it reads as intentional and balanced. Layout is the skeleton everything else hangs on — get it wrong and no amount of color or motion saves it.

## The grid is the foundation

- **12-column grid** for marketing/content; **8pt spacing system** for everything (all margins, paddings, gaps are multiples of 4/8px).
- **Content max-width** ~1200–1280px with generous gutters. Full-bleed only for deliberate hero/media moments.
- **Baseline rhythm:** vertical spacing between elements follows the same scale as horizontal — don't invent one-off gaps.
- **Align to the grid, always.** Nothing sits at an accidental offset. If it looks off by 1px, adjust optically (perception beats geometry).

## Spacing scale (8pt)

```
4  8  12  16  24  32  48  64  96  128
```
Use tighter steps (4–16) inside components, larger steps (24–128) between sections. Consistent spacing is the single biggest driver of "this looks designed."

**Proximity law:** related items sit close; unrelated items get more space. Whitespace *is* grouping — you rarely need borders to separate things that are already spaced apart.

## Reading patterns (guide the eye)

- **F-pattern** for text-heavy/scannable pages (blogs, search results): put the most important content top-left and along the left edge.
- **Z-pattern** for simple, sparse pages (landing hero): logo top-left → CTA top-right → diagonal to content → CTA bottom.
- **Layer cake / grid** for dense content: horizontal bands the eye scans down.
- Place the primary action where the eye lands last on its journey to conversion.

## Section patterns that work

- **Hero:** one clear thesis (headline + subhead + one primary CTA + supporting visual). Not "big number + three cards."
- **Feature bento:** asymmetric grid of cards, varied sizes, one hero cell. Modern, flexible, avoids the boring 3-column row.
- **Alternating rows:** image-left/text-right, then flip — good for explaining several features in sequence.
- **Logo/social-proof strip:** quiet, grayscale, directly under the hero to build trust early.
- **Comparison / pricing:** recommended plan pre-highlighted, aligned feature rows, sticky header on scroll.
- **CTA band:** a focused, higher-contrast section near the end that restates the primary action.

## Visual balance

- **Symmetry** = stable, formal, trustworthy. **Asymmetry** = dynamic, modern, editorial — balance it with visual weight (a large quiet area vs a small dense one).
- **Rule of thirds / optical center:** the optical center is slightly above true center; hero focal points feel better placed there.
- **Contrast of scale:** pair one large element with several small ones; equal-sized everything reads flat.
- **Negative space is a feature,** not wasted room. Premium design is confident enough to leave space empty.

## Responsive composition

- Design mobile-first; decide what collapses, stacks, or hides at each breakpoint *by content*, not by device.
- Reflow multi-column → single column; convert side-nav → bottom bar or drawer; tables → cards (see `data-display.md`).
- Keep the primary action reachable in the thumb zone on mobile (see `mobile-touch.md`).
- Test mobile, laptop, and ultra-wide (simulate ultra-wide at 50% zoom) — content shouldn't stretch to unreadable line lengths.

## Common layout mistakes

| Mistake | Fix |
| --- | --- |
| Inconsistent, one-off spacing values | Snap everything to the 8pt scale |
| Everything centered | Center is for short focal content; long content reads better left-aligned |
| Line length too long | Cap body text at ~65–75ch |
| Equal visual weight everywhere | Establish one dominant element per section |
| Borders separating already-spaced items | Remove borders; let whitespace group |
| Content stretched full-width on large screens | Apply a max-width container |
| Accidental misalignment | Align to grid; adjust ±1px optically only when needed |

## Checklist

- [ ] Everything on an 8pt spacing scale
- [ ] Content in a max-width container with real gutters
- [ ] One dominant element per section
- [ ] Reading pattern (F/Z/grid) matches content type
- [ ] Proximity/whitespace does the grouping, not excess borders
- [ ] Balanced composition (weight, scale contrast, negative space)
- [ ] Reflows sensibly mobile → ultra-wide, line length capped
