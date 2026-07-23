# Empty, Error & Edge States

Design the states that aren't the happy path. These are where products feel broken or polished. Every screen that renders data must handle: loading, empty, sparse, dense, error, and offline.

## The six data states

| State | Trigger | Design goal |
| --- | --- | --- |
| **Loading** | Request in flight | Skeleton mirroring final layout; no spinner-only if layout is known |
| **Empty** | No data yet (new user, cleared filter) | Explain why + one clear primary action |
| **Sparse** | 1–2 items | Still looks intentional, not "half-broken" |
| **Dense** | Many items | Virtualize (>50), paginate, or group |
| **Error** | Request failed | Say what failed + how to recover (retry) |
| **Offline** | No connection | Distinguish from error; queue or inform |

## Empty states

An empty screen is an invitation to act, not a dead end.

```tsx
function EmptyProjects() {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <FolderIcon className="size-10 text-neutral-400" aria-hidden />
      <h2 className="mt-4 text-lg font-semibold">No projects yet</h2>
      <p className="mt-1 max-w-sm text-sm text-neutral-500">
        Create your first project to start tracking work.
      </p>
      <button className="mt-6 rounded-md bg-primary-500 px-4 py-2 text-white">
        New project
      </button>
    </div>
  );
}
```

Distinguish the *kinds* of empty:
- **First-run empty** — onboarding tone, teach the primary action.
- **Cleared-by-filter empty** — offer to reset the filter, don't imply there's no data at all.
- **All-done empty** — positive framing ("You're all caught up").

## Error states

Errors don't apologize and are never vague. State what happened and the recovery path, in the interface's voice.

```tsx
function LoadError({ onRetry }: { onRetry: () => void }) {
  return (
    <div role="alert" className="flex flex-col items-center py-16 text-center">
      <AlertIcon className="size-10 text-error-500" aria-hidden />
      <h2 className="mt-4 text-lg font-semibold">Couldn't load your data</h2>
      <p className="mt-1 max-w-sm text-sm text-neutral-500">
        The request timed out. Check your connection and try again.
      </p>
      <button onClick={onRetry} className="mt-6 rounded-md border px-4 py-2">
        Try again
      </button>
    </div>
  );
}
```

- Use `role="alert"` so it's announced.
- Always offer a next step (retry, go back, contact) — no dead ends.
- Inline field errors go next to the field; page-level errors get a block like above.

## Loading with skeletons

Skeletons must mirror the real content's dimensions to avoid layout shift (CLS).

```tsx
function CardSkeleton() {
  return (
    <div className="animate-pulse" aria-hidden>
      <div className="h-48 rounded-lg bg-neutral-200" />
      <div className="mt-4 h-4 w-3/4 rounded bg-neutral-200" />
      <div className="mt-2 h-4 w-1/2 rounded bg-neutral-200" />
    </div>
  );
}
```

Mark skeletons `aria-hidden` and expose a polite loading message to assistive tech (`aria-busy` on the container).

## Content resilience

Real content breaks naive layouts. Test every text container with:
- **Empty string** — no broken UI.
- **Very long unbroken string** — `break-words` / `truncate` / `line-clamp-*`; flex children need `min-w-0`.
- **Very long list** — virtualize >50 items.
- **Missing optional fields** — no "undefined" or empty gaps.
- **Localized content** — text expansion (German ~30% longer), RTL, locale-aware numbers/dates.

## Checklist

- [ ] Loading uses skeletons mirroring final layout (no CLS)
- [ ] Empty state explains why + offers primary action
- [ ] Filter-empty differs from first-run empty
- [ ] Error states say what failed + offer recovery, `role="alert"`
- [ ] Offline distinguished from error
- [ ] Long/empty/missing content handled (`truncate`, `line-clamp`, `min-w-0`)
- [ ] Dense lists virtualized or paginated
- [ ] No dead ends anywhere
