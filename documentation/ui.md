# PROMPT: Build a Premium Flutter UI/UX for BudgetLite (Material 3 & Fluid Architecture)

---

## 1. INSTRUCTIONS FOR THE CODE GENERATOR

Act as a Principal Mobile UI Architect and Flutter Design Lead. Build a pixel-perfect, highly interactive Flutter prototype for **BudgetLite**, a premium offline-first personal budgeting app for Android.

The application uses Material 3 with a custom teal accent palette that distinguishes it from default Material theming. Every transition, press state, focus ring, loading skeleton, empty state, and edge case must be designed with extreme care in **both dark mode and light mode**.

The layout must implement a consistent 8pt spacing system with safe-area-aware insets, fluid type scaling, and thumb-zone-optimized interactive areas for one-handed use. No emojis may be used in the UI; use Lucide Flutter icons for all iconography.

---

## 2. DESIGN TOKENS

### Color System
```dart
// Primary palette (Teal-based, not generic blue)
--primary: #0D7377         // Deep teal — primary actions, active state
--primary-light: #14B8A6    // Light teal — highlights, containers
--primary-dark: #0B5E62     // Dark teal — dark mode primary

// Neutrals (tinted, not pure gray)
--surface-light: #F8FAFA    // Near-white with teal tint
--surface-dark: #0F171E     // Near-black with cool tint
--card-light: #FFFFFF       // Card surface
--card-dark: #1A2332        // Dark card surface

// Semantic (muted, not fluorescent)
--success: #059669          // Green for income, positive
--error: #DC2626            // Red for expense, negative
--warning: #D97706          // Amber for alerts, caution
```

### Typography Scale
```
Display (DM Sans):
  - Hero: 36/700/1.1    — Dashboard balances
  - H2: 28/600/1.15     — Section titles
  - H3: 22/600/1.2      — Card titles
  - H4: 17/600/1.25     — App bar titles

Body (Inter):
  - Body: 14/400/1.5    — Primary content
  - Small: 12/400/1.4   — Labels, metadata
  - Tiny: 11/500/1.3    — Badge text

Financial (JetBrains Mono, tabular-nums):
  - Large: 32/700       — Balance display
  - Medium: 20/700      — Amount cards
  - Small: 14/600       — Transaction amounts
```

### Border Radius Hierarchy
```
--radius-xl: 22           — Dialogs, bottom sheets
--radius-lg: 18           — Main card surfaces
--radius-md: 14           — Sub-cards, small cards
--radius-sm: 12           — Buttons, chips
--radius-icon: 10         — Category icon backgrounds
--radius-xs: 6            — Badges, progress indicators
--radius-2xs: 3           — Inner progress bars
```

### Shadow System (Layered)
```dart
// Light mode — 3-layer shadow replaces border
cardShadowLight = [
  BoxShadow(blur: 1, color: black@6%),    // border ring
  BoxShadow(blur: 2, offset: 0,1, color: black@6%),  // lift
  BoxShadow(blur: 4, offset: 0,2, color: black@4%),  // ambient
];

// Dark mode — 1-layer white ring
cardShadowDark = [
  BoxShadow(blur: 1, color: white@8%),    // subtle separation
];
```

---

## 3. NAVIGATION SHELL

### Bottom Navigation Bar
```
┌─────────────────────────────────────────────┐
│                                             │
│              [Screen Content]               │
│                                             │
│                                             │
│                                             │
│  `lucide:home`  `lucide:receipt`  `lucide:wallet`  `lucide:flag`  `lucide:creditCard`  `lucide:chartBar`                   │
│ Home  Txns  Bud  Goal  Debt  Insight        │
│              [`lucide:plus` FAB]                        │
└─────────────────────────────────────────────┘
```

- 6 tabs: Home, Transactions, Budget, Goals, Debt, Insights
- FAB visible on Home and Transactions tabs only
- FAB shows extended menu (Expense / Transfer) on tap
- Active tab uses filled icon, inactive uses outlined
- Haptic feedback (`HapticFeedback.selectionClick()`) on tab switch
- Spring scale transition (`AnimatedSwitcher` + `ScaleTransition 0.97→1.0`) on page switch

### Floating Action Button
- `FloatingActionButton.extended` with label "New"
- On tap: shows bottom sheet with two options:
  - **Expense** (`LucideIcons.plus`, primary color) — opens add transaction sheet
  - **Transfer** (`LucideIcons.arrowLeftRight`, warning color) — opens transfer sheet
- Each option button has press-scale animation (0.94 on tap)

---

## 4. SCREEN DESIGNS

### A. Home Dashboard (`HomeScreen`)
```
┌─────────────────────────────────────────────┐
│  Home                                        │
├─────────────────────────────────────────────┤
│  ┌─────────────────────┬──────────────────┐  │
│  │ ₹ 45,230            │ 68%              │  │
│  │ Total Spent         │ Budget Used      │  │
│  └─────────────────────┴──────────────────┘  │
│                                             │
│  ── Quick Budget Setup ──                   │
│  ┌─────────────────────────────────────┐    │
│  │ Set up your monthly budget to      │    │
│  │ start tracking spending             │    │
│  │                      [Set Up Budget] │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ── Account Balances ──                     │
│  ┌────────────┬───────────┬──────────┐      │
│  │ HDFC Bank  │ Paytm     │ Cash     │      │
│  │ ₹ 25,000   │ ₹ 3,200   │ ₹ 2,000  │      │
│  └────────────┴───────────┴──────────┘      │
│                                             │
│  ── Upcoming Payments ──                    │
│  ┌─────────────────────────────────────┐    │
│  │ `lucide:calendarDays` Rent             Due in 5 days  │    │
│  │ `lucide:calendarDays` Netflix Sub      Due tomorrow   │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ── Budget Overview ──                      │
│  ┌─────────────────────────────────────┐    │
│  │ Food    ₹12k/₹15k  ████████░░ 80%  │    │
│  │ Transp  ₹5k/₹8k    █████░░░░ 63%   │    │
│  │ Rent    ₹25k/₹25k  ██████████ 100% │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

- Summary cards use `cardRadiusSmall` (14) with layered shadows
- Account balances show icons matching account type
- Upcoming payments sorted by days until due
- Budget overview shows top 4 categories by allocation
- All cards have entry animation: fade + slide up

### B. Transaction List (`TransactionsScreen`)
```
┌─────────────────────────────────────────────┐
│  Transactions                    `lucide:search` Filter   │
├─────────────────────────────────────────────┤
│  [All] [Food] [Transp] [Bills] [More ▾]     │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ `lucide:utensils` Zomato             -₹ 450      │    │
│  │ Food • Today • UPI                  │    │
│  ├─────────────────────────────────────┤    │
│  │ `lucide:carFront` Uber               -₹ 320      │    │
│  │ Transport • Yesterday • UPI         │    │
│  ├─────────────────────────────────────┤    │
│  │ `lucide:briefcase` Salary             +₹ 65,000   │    │
│  │ Income • Jul 1 • NEFT              │    │
│  ├─────────────────────────────────────┤    │
│  │ `lucide:shoppingBag` Amazon              -₹ 2,499   │    │
│  │ Shopping • Jun 28 • Credit Card    │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

- Swipe left to delete with confirmation snackbar + undo
- Tap a transaction to open pre-filled edit sheet
- Filter chips scroll horizontally with snap scrolling
- Income transactions shown with green amounts, expenses with red
- Category icon in a `cardRadiusIcon` (10) background container
- Entry animation: fade + slide right on each card

### C. Add Transaction Sheet (`AddTransactionSheet`)
```
┌─────────────────────────────────────────────┐
│  New Transaction                    [Cancel] │
├─────────────────────────────────────────────┤
│  Amount                                       │
│  ┌─────────────────────────────────────┐    │
│  │ ₹ 0                                  │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  [Expense] [Income]                         │
│                                             │
│  Category                                    │
│  [`lucide:utensils`Food] [`lucide:carFront`Transp] [`lucide:shoppingBag`Shop] [`lucide:lightbulb`Bills]    │
│  [`lucide:plus`More]                                    │
│                                             │
│  Note                                        │
│  ┌─────────────────────────────────────┐    │
│  │ e.g. Zomato order                    │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  Tags                                        │
│  ┌─────────────────────────────────────┐    │
│  │ office, travel                       │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  Date        Payment                        │
│  [Jul 15 ▾]  [UPI ▾]                       │
│                                             │
│  □ Recurring  ┌ Interval ─╮                │
│               │ monthly  ▾│                │
│               └───────────┘                │
│                                             │
│  ┌──────── `lucide:camera` Attach Receipt ────────┐     │
│  │ (tap to capture or select photo)  │     │
│  └───────────────────────────────────┘     │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │        `lucide:smartphone` Add Transaction           │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

- Bottom sheet with 24px top radius, full keyboard handling
- Auto-categorization as user types note (keyword matching)
- Type toggle (Expense/Income) with press-scale animation on `_TypeButton`
- Tags field appends to note as `[tag1, tag2]`
- Receipt picker opens camera or gallery
- Submit button shows loading spinner during async save
- Input fields use themed `InputDecoration` with 14px radius

### D. Budget Screen (`BudgetScreen`)
```
┌─────────────────────────────────────────────┐
│  Budget Setup                                │
├─────────────────────────────────────────────┤
│  ┌── Monthly Income ──────────────────┐     │
│  │ ₹ 65,000                   [Save]  │     │
│  └─────────────────────────────────────┘     │
│                                             │
│  Category Budgets          ₹45,230 spent     │
│                                             │
│  ┌── Food ────────────────────────────┐     │
│  │ `lucide:utensils` Food         Amount: ₹ 15000    │     │
│  │                ████████░░ 80%      │     │
│  │                ₹3,000 left    `lucide:refreshCw`   │     │
│  │                                   `lucide:check`│     │
│  └─────────────────────────────────────┘     │
│                                             │
│  ┌── Transport ───────────────────────┐     │
│  │ `lucide:carFront` Transport     Amount: ₹ 8000    │     │
│  │                █████░░░░ 63%       │     │
│  │                ₹3,000 left    `lucide:refreshCw`   │     │
│  │                                   `lucide:check`│     │
│  └─────────────────────────────────────┘     │
│                                             │
│  [+ Add Custom Category]                     │
└─────────────────────────────────────────────┘
```

- Income field with financial-style monospace typography (32px)
- Each budget slot shows category icon, name, allocated amount input
- Progress bar with color matching category
- Rollover toggle button with press animation
- Save button per slot with checkmark icon
- Income save button has loading state

### E. Savings Goals (`GoalsScreen`)
```
┌─────────────────────────────────────────────┐
│  Savings Goals                     [+ Add]   │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  `lucide:home` ─ New Laptop ─ 256 days left   │    │
│  │                                     │    │
│  │     ╭───────────────╮  42%          │    │
│  │     │  42%          │               │    │
│  │     ╰───────────────╯               │    │
│  │                                     │    │
│  │  Saved           Remaining           │    │
│  │  ₹ 12,000        ₹ 68,000           │    │
│  │                                     │    │
│  │  `lucide:chartBar` ₹ 5,500/month recommended       │    │
│  │                                     │    │
│  │  [          Contribute          ]   │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  `lucide:plane` ─ Europe Trip ─ 180 days left   │    │
│  │  ...                                 │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

- Arc progress ring (`ArcProgress` widget) showing completion percentage
- Pace indicator: per-day or per-month savings recommendation
- Contribute button opens bottom sheet with amount input
- Entry animation with spring easing (`easeOutCubic`, slide + fade)
- Color-coded per goal (user picks color on creation)

### F. Insights Screen (`InsightsScreen`)
```
┌─────────────────────────────────────────────┐
│  Insights                                    │
├─────────────────────────────────────────────┤
│  ┌─────────────┬──────────────────────┐     │
│  │ ₹ 45,230    │ 68%                  │     │
│  │ Total Spent │ Budget Used          │     │
│  └─────────────┴──────────────────────┘     │
│                                             │
│  ── Spending by Category ──                 │
│  ┌─────────────────────────────────────┐    │
│  │  `lucide:chartPie``lucide:chartPie``lucide:chartPie`                   Food 35% │    │
│  │  `lucide:home``lucide:home``lucide:home`                 Rent 30%  │    │
│  │  `lucide:carFront``lucide:carFront`              Transport 15%  │    │
│  │  `lucide:shoppingBag``lucide:shoppingBag`              Shopping 12%  │    │
│  │  `lucide:lightbulb`                    Bills 8%  │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ── Smart Insights ──                       │
│  ┌─────────────────────────────────────┐    │
│  │ `lucide:lightbulb` Food is 35% above last month     │    │
│  │ `lucide:triangleAlert` Rent budget exceeded by 5%       │    │
│  │ `lucide:calendarDays` You spend ₹1,500/day on average  │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ── This Week vs Last Week ──              │
│  ┌─────────────────────────────────────┐    │
│  │  ▇▇▇▇▇▇▇▇  Bar chart              │    │
│  │  Mon Tue Wed Thu Fri Sat Sun       │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ── 6-Month Trend ──                       │
│  ┌─────────────────────────────────────┐    │
│  │  ╱╲    ╱╲   Line chart              │    │
│  │ ╱  ╲  ╱  ╲                          │    │
│  │╱    ╲╱    ╲                         │    │
│  │ Feb Mar Apr May Jun Jul              │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ── Spend Heatmap ──                        │
│  ┌─────────────────────────────────────┐    │
│  │ Jul 2026                            │    │
│  │ Mon ██░░███░███░████░░██           │    │
│  │ Tue ██░██░░███░░██░████            │    │
│  │ Wed ███░██░████░███░███            │    │
│  │ ...                                 │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ── Year in Review ──                       │
│  ┌─────────────────────────────────────┐    │
│  │ Total Income: ₹7,80,000            │    │
│  │ Total Spent:  ₹5,40,000            │    │
│  │ Savings Rate: 31%                   │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

- Animated fl_chart pie chart with category breakdown
- Smart insights with Lucide icons per observation type
- Week-over-week grouped bar chart
- 6-month line chart with gradient area fill
- Heatmap calendar showing daily spend intensity
- Year-in-review card with annual totals and savings rate

---

## 5. INTERACTION DESIGN

### Press States
- All tappable elements have `AnimatedScale(scale: 0.94)` on press
- Color chips and selection circles: scale 0.88
- Duration: 120ms, curve: easeOut
- `onTapDown` / `onTapUp` / `onTapCancel` handlers

### Entry Animations
- List items: staggered fade + slideY (easeOutCubic, 400ms)
- Page transitions: `AnimatedSwitcher` with scale 0.97→1.0 + fade 0.3→1.0
- Goal cards: spring-eased slideY (easeOutCubic, no overshoot)
- Cards: fadeIn + slideX(begin: -0.02) for subtle reveal

### Haptic Feedback
- Tab switch: `HapticFeedback.selectionClick()`
- Swipe delete: `HapticFeedback.mediumImpact()`
- FAB press: `HapticFeedback.lightImpact()`

### Loading States
- Save/submit buttons: disable + replace label with `CircularProgressIndicator`
- Async operations wrapped in `try/finally` with `setState`
- `addPostFrameCallback` to ensure spinner renders before state reverts

### Empty States (no emojis)
- **No transactions**: "No transactions yet — tap + to add your first expense"
- **No goals**: "No savings goals yet — create a goal to start saving for what matters"
- **No budget**: "No budget set — allocate categories to start tracking"
- **No debt**: "No debts tracked — add a loan or credit card to start tracking"
- **No insights**: "Not enough data — add more transactions to see insights"

---

## 6. CONTAINER & SURFACE RULES

### Concentric Radii
When nesting rounded elements, outer radius = inner radius + padding:
```dart
// Card (radius 18) with padding 12 containing an inner surface:
// Inner radius = 18 - 12 = 6
Container(
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(18),
  ),
  child: Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),  // 18 - 12
    ),
  ),
)
```

### Shadow Over Border Rule
Replace bare borders on cards and containers with layered shadows:
```dart
// Good
boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,

// Avoid — bare border without shadow
border: Border.all(color: outline),
```

Exceptions: dividers, form input outlines (accessibility), side borders for layout separation.

### Image Outlines
Receipt images use a subtle outline:
- Light mode: `outline: 1px solid rgba(0,0,0,0.1)`
- Dark mode: `outline: 1px solid rgba(255,255,255,0.1)`

---

## 7. RESPONSIVE & TOUCH RULES

### Touch Targets
- Minimum hit area: 44x44dp (Material guideline)
- If visual element is smaller, extend hit area with padding
- Primary actions in bottom third (thumb zone)
- Minimum 8px spacing between interactive targets

### Safe Areas
- Use `MediaQuery.padding.top` for status bar
- Respect bottom safe area for home indicator
- `SafeArea` wrapper on Scaffold body

### Keyboard Handling
- `MediaQuery.of(context).viewInsets.bottom` for keyboard height
- Bottom sheets scroll when keyboard is open
- Input fields minimum 16px font size to prevent iOS zoom

---

## 8. COMPONENT STATE MATRIX

| Component | Default | Active | Disabled | Loading | Focus |
|-----------|---------|--------|----------|---------|-------|
| FilledButton | teal bg | darken 10% | opacity 35% | spinner replaces text | ring 2px |
| OutlinedButton | transparent border | tint bg | opacity 35% | — | ring 2px |
| TextButton | transparent | tint hover | opacity 35% | — | ring 2px |
| Filter Chip | outline tint | filled tint | — | — | ring 2px |
| TypeToggle | surface bg | accent tint | — | — | — |
| TextInput | surface fill | accent border | opacity 60% | — | ring accent |
| Card | shadow | lift hover | — | shimmer skeleton | — |

---

## 9. 10 PRODUCTION-GRADE ENHANCEMENTS

1. **Arc Progress Ring Signature**: The `ArcProgress` widget is BudgetLite's signature visual element — used for goal completion, debt payoff, and budget health. It animates on value change with a spring curve, and the arc cap is always rounded.

2. **Animated Number Counters**: Dashboard balances and goal amounts animate (count up/down) when values change using the `AnimatedNumber` widget with a 200-400ms interpolation.

3. **Layered Shadow System**: Every card surface uses the 3-layer shadow model (border ring + lift + ambient) instead of bare borders, creating consistent depth across light and dark modes.

4. **Press-Scale Tactile Feedback**: Every interactive element has an `AnimatedScale(0.88-0.94)` press response with 120ms easeOut — the primary tactile feedback mechanism replacing Material ripple in custom components.

5. **Spring Page Transitions**: Tab switches use `AnimatedSwitcher` with `ScaleTransition(0.97→1.0)` + `FadeTransition(0.3→1.0)` using `easeOutCubic` — no overshoot, smooth and fast.

6. **Color-Blind-Safe Encoding**: All financial status indicators use icon + color + text (never color alone). Positive amounts get a green up-arrow icon, negative get a red down-arrow.

7. **Exact-Geometry Skeleton Loading**: Loading states mirror the exact layout dimensions of populated content — no layout shift, no spinner-only fallbacks.

8. **Complete Focus Ring Navigation**: Every interactive element has visible focus indicators for keyboard/talkback navigation — `focus-visible: ring-2 accent`.

9. **In-Voice Empty States**: Empty screens are framed as invitations to act, not dead ends: "No transactions yet — tap + to add your first expense" — with a clear primary action.

10. **BANNED DESIGN PATTERNS**: No warm-neutral cream backgrounds, no gradient text, no glassmorphism as default, no identical card grids, no side-stripe borders, no emoji in UI (Lucide icons only).

---

## 10. THEME MODE TOGGLING

Light mode and dark mode share the same token structure with different values:
- Dark mode elevates surfaces with lighter overlays (not lighter grays)
- Dark mode reduces accent saturation by 10-15%
- Dark mode shadows are softer (white rings instead of black)
- Transitions between modes: `ThemeData` swap with 220ms ease
- System default: follow `MediaQuery.platformBrightness`
- Manual override: stored in `AppSettings`
