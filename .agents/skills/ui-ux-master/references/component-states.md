# Component States Matrix

Most "unfinished" UI comes from missing states. Every interactive component should define all applicable states before it ships. Design and implement them explicitly — don't let the browser defaults decide.

## The full state matrix

| State | When | Must convey |
| --- | --- | --- |
| **Default** | Resting | Base appearance from tokens |
| **Hover** | Pointer over (desktop only) | Increased contrast / subtle elevation |
| **Focus** | Keyboard focus | Visible `:focus-visible` ring — never removed |
| **Active/Pressed** | Mouse/touch down | `scale(0.96)` or darker fill — tactile feedback |
| **Disabled** | Not actionable | Reduced opacity + `cursor: not-allowed` + `aria-disabled`; still readable |
| **Loading** | Async in progress | Spinner, keep original label, block re-submit |
| **Error/Invalid** | Validation failed | Color + icon + text (not color alone); message nearby |
| **Success** | Action succeeded | Brief confirmation, then settle |
| **Selected/Active** | Toggled/current | Clear persistent indicator (`aria-pressed`/`aria-current`) |
| **Empty** | No data yet | Guidance + primary action (see empty-error-states.md) |
| **Read-only** | Viewable not editable | Distinct from disabled; content selectable |

## Which states apply to which components

- **Button**: default, hover, focus, active, disabled, loading.
- **Input/Textarea**: default, focus, filled, error, disabled, read-only.
- **Checkbox/Radio/Toggle**: default, hover, focus, checked, disabled, indeterminate (checkbox).
- **Link**: default, hover, focus, visited, active.
- **Card/List item (interactive)**: default, hover, focus, selected, disabled.
- **Tab**: default, hover, focus, active/selected, disabled.
- **Menu item**: default, hover, focus, disabled, destructive variant.

## Example: fully-stated button (Tailwind)

```tsx
<button
  type="button"
  disabled={loading || disabled}
  aria-disabled={disabled}
  className={cn(
    "inline-flex items-center gap-2 rounded-md px-4 py-2 font-medium",
    "bg-primary-500 text-white",
    "hover:bg-primary-600",
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-400 focus-visible:ring-offset-2",
    "active:scale-[0.96] transition-transform",
    "disabled:opacity-50 disabled:cursor-not-allowed disabled:active:scale-100",
  )}
>
  {loading && <Spinner className="size-4 animate-spin" />}
  {label}
</button>
```

Key details:
- `focus-visible` (not `focus`) so mouse users don't see the ring but keyboard users do.
- Loading keeps the label and disables re-submit; spinner is additive.
- Disabled cancels the press animation (`disabled:active:scale-100`).

## Example: input with error state

```tsx
<div>
  <label htmlFor="email" className="block text-sm font-medium">Email</label>
  <input
    id="email"
    type="email"
    inputMode="email"
    autoComplete="email"
    aria-invalid={!!error}
    aria-describedby={error ? "email-error" : undefined}
    className={cn(
      "mt-1 w-full rounded-md border px-3 py-2",
      "focus-visible:ring-2 focus-visible:ring-primary-400",
      error ? "border-error-500" : "border-neutral-300",
    )}
  />
  {error && (
    <p id="email-error" className="mt-1 flex items-center gap-1 text-sm text-error-600">
      <AlertIcon className="size-4" aria-hidden /> {error}
    </p>
  )}
</div>
```

## Checklist

- [ ] Every interactive component enumerates all applicable states
- [ ] `:focus-visible` ring on all focusable elements
- [ ] Active/pressed feedback (`scale(0.96)` or fill change)
- [ ] Disabled is visually distinct, non-actionable, and `aria-disabled`
- [ ] Loading keeps label + blocks re-submit
- [ ] Error uses color + icon + text and is programmatically linked (`aria-describedby`)
- [ ] Selected/current state uses `aria-pressed`/`aria-current`
- [ ] Read-only distinguished from disabled
