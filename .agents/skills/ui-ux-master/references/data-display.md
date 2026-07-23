# Data Display & Dashboards

Presenting data clearly is its own discipline. Dense, information-rich UIs (tables, charts, dashboards) live by different rules than marketing pages: clarity and scannability beat decoration.

## Tables — the workhorse

- **Right-align numbers, left-align text**, headers match their column's alignment. Use `tabular-nums` so digits line up and don't shift.
- **Reduce chrome:** horizontal row dividers (or subtle zebra striping), no heavy vertical grid lines. Whitespace separates columns.
- **Sticky header** (and sometimes first column) on scroll so context never leaves.
- **Row height:** comfortable (~44–52px) for readability, compact mode as an option for power users.
- **Truncate long cells** with `truncate` + tooltip/expand; flex children need `min-w-0`.
- **Primary column** (name/title) heavier weight; secondary metadata lighter/smaller.
- **Row actions:** reveal on hover (desktop) but keep them keyboard-reachable and always visible on touch.

### Sorting, filtering, pagination
- **Sortable headers:** clear ascending/descending indicator; remember the sort; sort on the column the user is most likely to care about by default.
- **Filtering:** show active filters as removable chips; a "clear all"; reflect filters in the URL (deep-linkable). Empty-after-filter state offers to reset (not "no data").
- **Pagination vs infinite scroll vs virtualization:** pagination for finite/navigable sets; infinite scroll for feeds; **virtualize any list/table >50 rows** for performance regardless.
- Show total count and current range ("1–25 of 340").

### Selection & bulk actions
- Row checkboxes + "select all (on page / across all)"; a bulk-action bar appears when ≥1 selected, showing the count and available actions; make deselect obvious.

## Charts — show the right one

| Goal | Chart |
| --- | --- |
| Trend over time | Line / area |
| Compare categories | Bar (horizontal if labels are long) |
| Part-to-whole | Stacked bar or a single donut (avoid many-slice pies) |
| Correlation | Scatter |
| Single KPI vs target | Number + sparkline or radial |
| Distribution | Histogram / box plot |

- **Label directly** where possible instead of forcing legend lookups.
- **Start bar axes at zero** (truncated axes mislead); line charts may use a focused range if labeled.
- **Color = meaning,** consistent across the dashboard; use a **color-blind-safe palette**; never encode by color alone (add labels/patterns).
- **Reduce ink:** drop gridlines to faint, remove chart borders, minimize decimals.
- **Interaction:** hover tooltip with exact values, focus/keyboard access, empty and loading states for every chart.

## KPI / metric cards

- **Big number first**, `tabular-nums`, with a short label and a comparison (▲ 12% vs last week) using color + arrow + text.
- Optional sparkline for trend at a glance.
- Group related KPIs; establish one hero metric per view.
- Handle loading (skeleton mirroring the card) and no-data ("—", not "0" when unknown).

## Dashboard layout

- **Inverted pyramid:** most important/summary metrics top, detail below.
- **Bento/grid** of cards with consistent gutters; let key charts span wider cells.
- **Progressive disclosure:** summary by default, drill-down on click — don't show everything at once.
- **Filters/date-range** at the top, applying to the whole view, reflected in the URL.
- **Responsive:** cards reflow to one column; wide tables become horizontally scrollable or card-per-row on mobile.

## Empty, loading & dense states

- **Loading:** skeletons shaped like the real content (mirror table rows / card layout) to prevent CLS — not a lone spinner.
- **Empty:** explain why + a primary action (import data, connect source). Distinguish "no data yet" from "no results for this filter."
- **Dense:** virtualize, paginate, or group; never render thousands of DOM nodes at once.
- **Error per widget:** one failed chart shouldn't blank the whole dashboard — isolate with a retry.

## Accessibility

- Real `<table>`/`<th scope>` semantics (not divs) so screen readers announce rows/columns.
- Charts need a text alternative (summary, or a data table toggle).
- Sort/filter controls are real buttons with `aria-sort` / clear labels.
- Meet contrast (prefer APCA); status via icon + text, not color alone.

## Checklist

- [ ] Numbers right-aligned + `tabular-nums`; minimal grid chrome
- [ ] Sticky header; truncation with `min-w-0`; hover/keyboard row actions
- [ ] Sortable headers with indicators; filters as chips, URL-reflected
- [ ] Lists/tables >50 rows virtualized
- [ ] Right chart for the goal; direct labels; zero-based bars; color-blind-safe
- [ ] KPI cards: big number, `tabular-nums`, comparison with arrow+text
- [ ] Skeleton loading mirrors content; distinct empty vs no-results states
- [ ] Per-widget error isolation with retry
- [ ] Table/chart semantics + text alternatives for a11y
