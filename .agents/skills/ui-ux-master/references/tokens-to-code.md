# Design Tokens → Code

Bridges the gap between `design_token_generator.py` output and a real codebase. The generator produces tokens; this file shows how to wire them into CSS variables, Tailwind v4, and TypeScript so the whole UI derives from one source.

## 1. Generate tokens

```bash
python references/design_token_generator.py "#3B82F6" modern css   > tokens.css
python references/design_token_generator.py "#3B82F6" modern json  > tokens.json
```

## 2. CSS custom properties (framework-agnostic)

Put the `:root` block in your global stylesheet. Reference tokens everywhere — never hard-code a hex or px value in a component.

```css
:root {
  --colors-primary-500: #75a6f6;
  --space-4: 1rem;
  --radius-md: 0.5rem;
  --shadow-sm: 0 1px 2px rgb(0 0 0 / 0.05);
}

.button {
  background: var(--colors-primary-500);
  padding: var(--space-4);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
}
```

## 3. Tailwind CSS v4 (`@theme`)

Tailwind v4 is CSS-first. Map tokens into `@theme` so utilities like `bg-primary-500` and `p-4` are generated from your tokens.

```css
/* app.css */
@import "tailwindcss";

@theme {
  --color-primary-50:  #b3cbf2;
  --color-primary-500: #75a6f6;
  --color-primary-900: #0b1a31;

  --spacing-4: 1rem;

  --radius-md: 0.5rem;

  --shadow-sm: 0 1px 2px rgb(0 0 0 / 0.05);
}
```

Now `class="bg-primary-500 p-4 rounded-md shadow-sm"` resolves to your tokens. Changing a token value updates every utility at once.

> Tailwind v4 uses `--color-*`, `--spacing-*`, `--radius-*`, `--shadow-*` namespaces. Rename the generator's `--colors-*` output to `--color-*` (drop the plural) when targeting v4.

## 4. Dark mode

Define a second scope that overrides only the surface/semantic tokens. Components stay unchanged.

```css
:root { --surface-background: #ffffff; --surface-foreground: #0b1a31; }

@media (prefers-color-scheme: dark) {
  :root { --surface-background: #0b1a31; --surface-foreground: #f5f7fb; }
}

/* or class-based */
[data-theme="dark"] { --surface-background: #0b1a31; --surface-foreground: #f5f7fb; }
```

Set `color-scheme: dark` on `<html>` so native controls (scrollbars, form fields) follow.

## 5. TypeScript types from tokens.json

Give autocomplete and type-safety to token consumers.

```ts
import tokens from "./tokens.json";

export const t = tokens;
export type ColorToken = keyof typeof tokens.colors.primary; // "50" | "100" | ...

export function color(scale: ColorToken) {
  return `var(--color-primary-${scale})`;
}
```

## Rules

- **Single source of truth**: every color/space/radius/shadow references a token. If you type a raw hex or px in a component, it's a bug.
- **Semantic over raw**: prefer `--color-primary-500` (semantic) over `--blue-500` in components, so re-theming is one edit.
- **Never fork the scale per component**: if you need a new value, add it to the token set, don't inline it.
- **Regenerate, don't hand-edit** the generated file — keep the brand color + style as the inputs of record.
