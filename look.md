# BudgetLite — Visual Design Brief

## Design a Flutter mobile app UI for a premium offline-first personal budgeting application.

---

## STYLE & MOOD
- Premium but approachable
- Financial — trustworthy, precise, calm
- Material 3 foundation, not default Material
- Dark mode first, light mode compatible
- Inspired by Linear, YNAB, and modern fintech UIs
- No skeuomorphism, no decorative flourishes
- Feels like a pro tool, not a toy

---

## COLOR PALETTE

### Primary (Teal — differentiated from generic fintech blue)
- **Accent**: `#0D7377` — deep teal, primary actions, active state
- **Accent Hover**: `#0B5E62` — pressed state
- **Accent Subtle**: `#0D7377` at 12% alpha — container backgrounds

### Neutrals (tinted, never pure gray)
- **Surface Light**: `#F8FAFA` — near-white with teal tint
- **Surface Dark**: `#0F171E` — near-black with cool tint
- **Card Light**: `#FFFFFF` — clean white cards
- **Card Dark**: `#1A2332` — elevated dark surface
- **OnSurface Light**: `#1A1A2E` — deep navy-black text
- **OnSurface Dark**: `#E8EDF2` — off-white text

### Semantic (muted, not fluorescent)
- **Success**: `#059669` — income, positive changes, goal achieved
- **Error**: `#DC2626` — expenses, over budget, debt
- **Warning**: `#D97706` — alerts, near-limit, pending
- **Info**: `#0D7377` — insights, tips, information

### Shadows
- **Light mode**: Black at 6% / 6% / 4% alpha — 3-layer
- **Dark mode**: White at 8% alpha — single ring layer

---

## TYPOGRAPHY

### Display: DM Sans (Google Font)
- Geometric sans-serif, clean numerals
- Tight tracking (-0.5 to -0.3) on headings
- Weights: 600 (semibold) for subtitles, 700 (bold) for hero numbers

### Body: Inter (Google Font)
- Highly legible at small sizes
- Neutral, no personality — lets the display font be the voice
- Line-height: 1.4 for labels, 1.5 for body text

### Financial: JetBrains Mono (Google Font)
- Monospace for all financial figures
- Tabular figures enabled (`FontFeature.tabularFigures()`)
- Letter-spacing: -0.5 for tight data display
- Weights: 600-700 for amounts

### Hierarchy Rules
```
Hero balance:     DM Sans 36/700/1.1
Section title:    DM Sans 17/600/1.25
Card title:       DM Sans 16/600
Category name:    Inter 14/500
Body text:        Inter 14/400/1.5
Financial value:  JetBrains Mono 20/700
Amount label:     JetBrains Mono 14/600
Small label:      Inter 12/400
```

---

## LAYOUT & SPACING

### Grid
- 8px base spacing unit
- Screen padding: 20px horizontal, 16px vertical
- Card padding: 20px (standard), 16px (compact)
- Card gap: 12-16px between cards in a list

### Card Architecture
```
┌──────────────────────────────────┐  ← cardRadius: 18
│  ┌── card padding: 20px ────┐  │
│  │                          │  │
│  │  ┌── inner surface ──┐   │  │  ← cardRadiusIcon: 10
│  │  │  [icon]           │   │  │
│  │  └───────────────────┘   │  │
│  │                          │  │
│  └──────────────────────────┘  │
└──────────────────────────────────┘
```

### Concentric Radii Chain
```
22 (xl) → dialogs, bottom sheets
18 (lg) → main cards
14 (md) → sub-cards, summary cards
12 (sm) → buttons, chips, inputs
10 (icon) → category icon containers
6 (xs) → badges, small elements
3 (2xs) → progress bars
```

---

## SURFACE TREATMENTS

### Cards
- No bare borders — use layered shadow system
- Light mode: 3-layer box-shadow (border ring + lift + ambient)
- Dark mode: 1-layer white ring
- No elevation in either mode (shadows replace z-elevation)

### Dividers
- Hairline (0.5px)
- 30% opacity outline color
- Used for layout separation (between list items), not surface depth

### Images (Receipts)
- Subtle outline overlay: black/white at 10% alpha
- `outline-offset: -1px` (inset, doesn't affect layout)

---

## INTERACTION LANGUAGE

### Press States
```
Scale on press:
  Buttons, cards, chips:    0.94 (6% shrink)
  Color circles, icon chips: 0.88 (12% shrink)
  Duration: 120ms
  Curve: easeOut
```

### Entry Animations
```
Cards entering viewport:
  Fade: 0→1, 300-400ms
  Slide: translateY 6-8%, easeOutCubic
  Stagger: 0-100ms delay between siblings

Page transitions:
  Scale: 0.97→1.0
  Fade: 0.3→1.0
  Duration: 350ms
  Curve: easeOutCubic (no overshoot)
```

### Haptic Feedback
```
Tab switch:   selectionClick()
Swipe delete: mediumImpact()
FAB press:    lightImpact()
```

---

## ICONOGRAPHY

### Source: Lucide Icons (Flutter package)
- Consistent 24px design grid
- 1.5px stroke weight
- No filled/duotone variants — use outlined by default, filled for active nav

### Common Icons
```
Home:          house / home
Transactions:  receipt / arrowLeftRight
Budget:        wallet / piggyBank
Goals:         flag / target
Debt:          creditCard / minusCircle
Insights:      barChart / trendingUp
Add:           plus / circlePlus
Delete:        trash2 / x
Edit:          pencil
Settings:      settings / cog
Search:        search
Filter:        listFilter
Calendar:      calendarDays
Camera:        camera
```

### Category Icons
```
Food:          utensils / pizza
Transport:     carFront / train
Shopping:      shoppingBag / shoppingCart
Bills:         lightbulb / zap
Rent:          building2 / home
Entertainment: film / music
Health:        heart / cross
Education:     graduationCap
Salary:        briefcase
```

---

## DARK MODE SPECIFICS

### Not an inversion
- Dark mode has its own palette, not inverse of light
- Surface colors are cool-tinted, not pure blacks
- Shadows switch from black-on-white to white-on-dark
- Accent saturation reduced by 10%
- Card surfaces are 12% lighter than the page background

### Dark Mode Values
```
Page background:  #0F171E
Card surface:     #1A2332
Elevated surface: #222D3D
Text primary:     #E8EDF2
Text secondary:   #8896A6
Outline:          #2A3545
Shadow:           white at 8% alpha (1 layer)
```

---

## WHAT BUDGETLITE IS NOT
- Not a cloud-dependent app (all local)
- Not a generic Material template (custom accent, shadows, type)
- Not a PDF-reader aesthetic (warm neutrals, serifs, dense)
- Not a neon fintech app (fluorescent gradients, glass, dark patterns)
- Not "just another expense tracker" (has envelope budgeting, debt, goals, analytics)

---

## MOOD BOARD REFERENCE
- **Linear** — clean cards, layered shadows, restrained color
- **YNAB** — envelope budgeting UX, goal-based savings flow
- **MoneyControl** — Indian financial context, UPI awareness
- **Stripe** — typography hierarchy, tabular numbers, precise spacing
- **Material 3** — foundation, but overridden where generic
