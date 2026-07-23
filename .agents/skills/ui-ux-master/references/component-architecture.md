# Component Architecture & Engineering

The craft side of UI: how to structure components so the design system actually holds up in code. Pairs with `component-states.md` (states), `tokens-to-code.md` (tokens), and `tailwind-design.md` (styling). Rules follow `web-interface-guidelines.md` for a11y.

## Composition over configuration

Prefer composable children over a mega-config object:

```tsx
// Good: composable
<Card>
  <CardHeader><CardTitle>Tasks</CardTitle></CardHeader>
  <CardBody><TaskList tasks={tasks} /></CardBody>
</Card>

// Avoid: over-configured
<Card title="Tasks" headerVariant="large" bodyPadding="md" content={<TaskList />} />
```

- Keep each component focused: does one thing, accepts clear props.
- Colocate a component's files: `TaskList/TaskList.tsx`, `.test.tsx`, `use-task-list.ts`, `types.ts`.

## Separate data from presentation

```tsx
// Container: data, loading, error, empty
export function TaskListContainer() {
  const { tasks, isLoading, error } = useTasks();
  if (isLoading) return <TaskListSkeleton />;
  if (error) return <ErrorState message="Failed to load tasks" retry={refetch} />;
  if (tasks.length === 0) return <EmptyState message="No tasks yet" />;
  return <TaskList tasks={tasks} />;
}

// Presentation: pure render
export function TaskList({ tasks }: { tasks: Task[] }) {
  return <ul role="list" className="divide-y">{tasks.map(t => <TaskItem key={t.id} task={t} />)}</ul>;
}
```

## State management ladder

Choose the simplest that works:

| Need | Tool |
| --- | --- |
| Component-specific UI state | `useState` / `useReducer` |
| Shared between 2–3 siblings | Lifted state |
| Theme, auth, locale (read-heavy) | Context |
| Filters, pagination, shareable UI | URL state (`searchParams`) |
| Remote data with caching | Server state (React Query, SWR) |
| Complex app-wide client state | Global store (Zustand, Redux) |

- Avoid prop drilling deeper than 3 levels. If passing props through components that don't use them, introduce context or restructure.

## Semantic color tokens (not raw hex)

- Use `text-primary`, `bg-surface`, `border-default` — never inline hex/rgb in components.
- Contrast: ≥4.5:1 normal text, ≥3:1 large text. Don't rely on color alone (icons/text/patterns too).

## Keyboard & focus (non-negotiable)

```tsx
// Interactive element = real <button>, not <div onClick>
<button onClick={handleClick}>Click me</button>          // ✓ focusable
<div onClick={handleClick}>Click me</div>                // ✗ not focusable

// Move focus on open; trap inside dialog
function Dialog({ isOpen, onClose }) {
  const closeRef = useRef<HTMLButtonElement>(null);
  useEffect(() => { if (isOpen) closeRef.current?.focus(); }, [isOpen]);
  return <dialog open={isOpen}><button ref={closeRef} onClick={onClose}>Close</button>{/* ... */}</dialog>;
}
```

- Label icon-only buttons (`aria-label`); label inputs with `<label htmlFor>` or `aria-label`.
- Don't remove `outline` without a visible `:focus-visible` replacement.

## Meaningful empty & error states

Never ship a blank screen. Empty state = icon + heading + one-line help + primary action. Error state = what happened + how to fix + retry.

```tsx
if (tasks.length === 0) return (
  <div role="status" className="text-center py-12">
    <TasksEmptyIcon className="mx-auto h-12 w-12 text-muted" />
    <h3 className="mt-2 text-sm font-medium">No tasks</h3>
    <p className="mt-1 text-sm text-muted">Get started by creating a new task.</p>
    <Button className="mt-4" onClick={onCreateTask}>Create Task</Button>
  </div>
);
```

## Loading & transitions

- Skeletons (not spinners) for content: `aria-busy="true" aria-label="Loading…"`.
- Honor `prefers-reduced-motion`; only animate `transform`/`opacity`.
- Avoid animating CSS layout properties unless truly needed.

## Responsive engineering

- Mobile-first: `grid-cols-1 sm:grid-cols-2 lg:grid-cols-3`.
- Test at 320 / 375 / 768 / 1024 / 1440px.
- `min-w-0` on flex children that must truncate.

## Checklist

- [ ] Composition over config; components focused and colocated
- [ ] Data/error/empty/loading separated from presentation
- [ ] State tool chosen from the ladder; no deep prop drilling
- [ ] Semantic color tokens only; contrast met
- [ ] Real interactive elements; focus moved/trapped; labels present
- [ ] Empty + error states with recovery action
- [ ] Skeletons for content; reduced-motion honored
- [ ] Responsive tested across breakpoints
