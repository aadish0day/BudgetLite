# Tailwind Design (v4)

Building a design system and premium UI *with* Tailwind CSS v4. Tailwind is the delivery layer for the tokens and aesthetics defined elsewhere in this skill — this file shows how to wire them in and use utilities without producing generic, inconsistent output.

> See `tokens-to-code.md` for the token→`@theme` pipeline, `modern-aesthetics.md` for the visual language, and `polish-*` refs for detail work.

## v4 is CSS-first

Tailwind v4 configures through CSS, not `tailwind.config.js`. Your design tokens live in an `@theme` block and Tailwind generates utilities from them.

```css
/* app.css */
@import "tailwindcss";

@theme {
  /* Colors — namespace: --color-* → utilities bg-*, text-*, border-* */
  --color-bg:        oklch(0.99 0 0);
  --color-fg:        oklch(0.15 0.02 265);
  --color-muted:     oklch(0.55 0.02 265);
  --color-accent:    oklch(0.62 0.19 265);
  --color-accent-fg: oklch(0.99 0 0);

  /* Neutral ramp (tinted, never pure gray) */
  --color-n-50:  oklch(0.98 0.003 265);
  --color-n-500: oklch(0.55 0.02 265);
  --color-n-900: oklch(0.15 0.02 265);

  /* Type scale (modular) — utilities text-* */
  --text-xs: 0.75rem;  --text-sm: 0.875rem; --text-base: 1rem;
  --text-lg: 1.125rem; --text-xl: 1.25rem;  --text-2xl: 1.5rem;
  --text-3xl: 2rem;    --text-4xl: 2.5rem;  --text-5xl: 3.25rem;

  /* Fonts */
  --font-display: "Satoshi", ui-sans-serif, system-ui;
  --font-sans:    "Inter", ui-sans-serif, system-ui;
  --font-mono:    "Geist Mono", ui-monospace, monospace;

  /* Radii, shadows, easing */
  --radius-md: 0.5rem;
  --radius-xl: 1rem;
  --shadow-sm: 0 1px 2px oklch(0 0 0 / 0.05);
  --shadow-lg: 0 8px 24px -8px oklch(0 0 0 / 0.25);
  --ease-out-quart: cubic-bezier(0.25, 1, 0.5, 1);
}
```

Now `bg-accent`, `text-3xl`, `font-display`, `rounded-xl`, `shadow-lg` all resolve to your tokens. Change a token, every utility updates.

### Use OKLCH
Prefer `oklch()` for color tokens — perceptually uniform, easy to build consistent ramps (hold hue/chroma, step lightness), and looks better in wide-gamut displays than hex/HSL.

## Dark mode

Use the `dark:` variant driven by a class or `prefers-color-scheme`, and override *tokens* (not every utility). Configure the dark selector:

```css
@custom-variant dark (&:where(.dark, .dark *));
```

```css
.dark {
  --color-bg: oklch(0.15 0.02 265);
  --color-fg: oklch(0.98 0.003 265);
  --color-accent: oklch(0.66 0.17 265); /* slightly desaturated for dark */
}
```

Set `color-scheme: dark` on `<html class="dark">` so native controls follow.

## Writing clean utility markup

- **Semantic tokens over raw values.** `bg-accent` not `bg-[#6366f1]`, `p-4` not `p-[17px]`. Arbitrary values are an escape hatch, not the norm — frequent `[...]` values mean a token is missing.
- **Consistent spacing scale** — stick to `1/2/3/4/6/8/12/16/24` (the 8pt-ish rhythm); don't sprinkle `p-[13px]`.
- **Concentric radii:** outer `rounded-2xl` + `p-2` inner → inner `rounded-lg` (see `polish-surfaces.md`).
- **Never `transition-all`** — use `transition-[transform,opacity]` or the specific `transition-transform`/`transition-colors`.
- **`focus-visible:` not `focus:`** for keyboard rings: `focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2`.
- **Press feedback:** `active:scale-[0.96] transition-transform` (never below 0.95).
- **Balanced headings:** `text-balance`; body `text-pretty`; numbers `tabular-nums`.

## Taming long class lists

- **Extract components**, not utility soup copy-pasted everywhere. In React, one `<Button variant="…">` beats 15 repeated class strings.
- **`cn()` helper** (clsx + tailwind-merge) for conditional/variant classes so later classes correctly override earlier ones.
- **CVA (class-variance-authority)** for component variants (size, intent, state) — keeps the state matrix (`component-states.md`) declarative.
- **`@apply` sparingly** — only for genuinely repeated primitives (e.g. a base input); overusing it recreates the CSS-bloat Tailwind avoids.

```ts
import { cva } from "class-variance-authority";
export const button = cva(
  "inline-flex items-center gap-2 rounded-md font-medium transition-transform active:scale-[0.96] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed",
  {
    variants: {
      intent: {
        primary: "bg-accent text-accent-fg hover:brightness-110",
        ghost:   "text-fg hover:bg-n-50",
        danger:  "bg-red-600 text-white hover:bg-red-700",
      },
      size: { sm: "px-3 py-1.5 text-sm", md: "px-4 py-2 text-base" },
    },
    defaultVariants: { intent: "primary", size: "md" },
  },
);
```

## Responsive & layout with Tailwind

- **Mobile-first:** unprefixed = mobile; `sm: md: lg: xl: 2xl:` layer up.
- **Container queries (v4 built-in):** `@container` on a parent, `@sm:/@md:` on children for component-level responsiveness (see `container-queries.md`).
- **Layout:** prefer `grid`/`flex` + `gap-*` over margins for spacing rhythm. Use `min-w-0` on flex children that must truncate.
- **Fluid type:** `text-[clamp(1.5rem,4vw,3rem)]` or define a `--text-*` token with `clamp()`.

## shadcn/ui note

If using shadcn/ui: it generates unstyled-but-accessible components into your repo using these exact conventions (CVA, `cn()`, CSS-var tokens). Customize the tokens in your CSS, not the component internals, so re-theming stays centralized.

## Common Tailwind mistakes

| Mistake | Fix |
| --- | --- |
| Arbitrary values everywhere (`p-[13px]`, `bg-[#...]`) | Add a token; use the scale |
| `transition-all` | List properties |
| `focus:` instead of `focus-visible:` | Use `focus-visible:` for rings |
| Copy-pasted class strings | Extract a component + CVA |
| Same radius parent & child | Concentric radii |
| Overusing `@apply` | Reserve for true primitives |
| Hard-coded dark colors per element | Override tokens under `.dark` |

## Checklist

- [ ] Tokens defined in `@theme`; utilities derive from them
- [ ] OKLCH colors; tinted neutral ramp
- [ ] Semantic tokens over arbitrary values; consistent spacing scale
- [ ] `focus-visible` rings, `active:scale`, no `transition-all`
- [ ] `text-balance`/`text-pretty`/`tabular-nums` applied
- [ ] Variants via CVA + `cn()`; components extracted, not class soup
- [ ] Dark mode overrides tokens + `color-scheme`
- [ ] Container queries / mobile-first responsive where needed
