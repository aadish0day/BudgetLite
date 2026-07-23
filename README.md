<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://img.shields.io/badge/BudgetLite-v1.0.0-14b8a6?style=flat-square&labelColor=1a1a2e" />
  <img alt="BudgetLite v1.0.0" src="https://img.shields.io/badge/BudgetLite-v1.0.0-14b8a6?style=flat-square&labelColor=f0fdfa" />
</picture>

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod-8B5CF6?style=flat-square)](https://riverpod.dev)
[![Drift](https://img.shields.io/badge/DB-Drift-0D7377?style=flat-square)](https://drift.simonbinder.eu)
[![License](https://img.shields.io/badge/license-MIT-6B7280?style=flat-square)](LICENSE)

---

**BudgetLite** is a premium, offline-first personal budgeting app for Android — built with Flutter. It combines envelope-style budgeting, savings goals, debt tracking, and rich analytics in a modern, tactile interface.

> Smart budgeting, simplified.

## Features

### Transactions & Tracking
- **Manual & quick-add** — floating action button + home screen widget for rapid entry
- **Auto-categorization** — keyword matching (e.g., "Zomato" → Food)
- **Recurring transactions** — daily, weekly, monthly (rent, subscriptions, EMIs) with auto-post
- **Receipt attachment** — snap and attach photos to transactions
- **Multiple accounts** — cash, bank, credit card, wallet with individual balances
- **Account transfers** — move funds between accounts seamlessly
- **Tags** — cross-cutting labels for grouping (e.g., "Trip: Goa")

### Budgeting
- **Envelope-style budgets** — monthly budgets per category
- **Rollover toggle** — carry unspent budget to next month per category
- **Savings goals** — target amount + date with progress tracking
- **Pace indicator** — shows per-day or per-month amount needed to reach goal
- **Debt tracker** — loans, EMIs, interest, payoff projections

### Insights & Analytics
- **Dashboard** — net worth snapshot, monthly spend vs income, budget health
- **Charts** — pie (category split), bar (week-over-week), line (6-month trend)
- **Spending by day of week** — identify patterns in your habits
- **Heatmap calendar** — spend intensity visualized per day
- **Smart insights** — "You spent 30% more on Food this month"
- **Year-in-review** — annual spending summary + savings rate

### Smart Features
- **Biometric lock** — fingerprint / face unlock protection
- **Dark mode** — system-aware with custom dark palette
- **CSV export** — full data export for analysis or backup
- **Search & filter** — by category, date range, amount
- **Budget alerts** — push notification at 80% / 100% of category limit
- **Bill reminders** — never miss a payment
- **Demo data** — one-tap sample data for testing

### Optional (Android)
- **SMS parsing** — auto-detect bank transactions from SMS (requires permission)

## Design

- **Material 3** with custom teal accent palette
- **Typography**: DM Sans (headings) + Inter (body) + JetBrains Mono (financial data)
- **Tactile micro-interactions**: press-scale animations, haptic feedback, spring page transitions
- **Layered shadows** replace bare borders for surface depth
- **Responsive layouts** with safe-area awareness
- **Animated charts** powered by `fl_chart`

## Tech Stack

| Layer | Choice |
|-------|--------|
| **Framework** | Flutter 3.x |
| **State management** | Riverpod (code-gen) |
| **Local database** | Drift (SQLite) |
| **Charts** | fl_chart |
| **Animations** | flutter_animate |
| **Icons** | Lucide Icons |
| **Fonts** | Google Fonts (DM Sans, Inter, JetBrains Mono) |
| **CSV export** | csv + share_plus |
| **Biometrics** | local_auth |
| **Notifications** | flutter_local_notifications |
| **SMS parsing** | telephony |

## Project Structure

```
lib/
├── app.dart                     # App entry + navigation shell
├── main.dart                    # Bootstrap
├── core/
│   ├── theme/                   # Colors, typography, tokens
│   │   ├── app_theme.dart       # Light/dark theme definitions
│   │   └── colors.dart          # Color constants + shadows
│   ├── database/
│   │   ├── database.dart        # Drift database definition
│   │   └── tables.dart          # Table schemas
│   ├── utils/
│   │   ├── constants.dart       # App-wide constants (radii, padding)
│   │   ├── formatters.dart      # Currency, date, percentage formatting
│   │   ├── icon_helper.dart     # Category icon mapping
│   │   └── sms_parser.dart      # SMS transaction detection
│   └── widgets/
│       ├── arc_progress.dart    # Circular progress ring
│       ├── animated_number.dart # Animated counter widget
│       └── insight_cards.dart   # Heatmap + year-in-review
├── features/
│   ├── home/                    # Dashboard screen
│   ├── transactions/            # Transaction list + add/edit sheet
│   ├── budget/                  # Budget setup + category management
│   ├── goals/                   # Savings goals
│   ├── debt/                    # Debt tracker
│   ├── insights/                # Charts + analytics
│   ├── settings/                # Account management + export
│   └── onboarding/              # First-launch intro
└── providers/
    ├── database_provider.dart   # DB instance provider
    ├── transaction_provider.dart
    ├── budget_provider.dart
    ├── goal_provider.dart
    └── settings_provider.dart
```

## Getting Started

### Prerequisites
- Flutter SDK 3.12+
- Android Studio / VS Code with Flutter extensions

### Installation
```bash
# Clone the repo
git clone https://github.com/yourusername/budget_lite
cd budget_lite

# Install dependencies
flutter pub get

# Generate Riverpod + Drift code
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Building for release
```bash
flutter build apk --release
```

## Running Tests

```bash
flutter test
```

## Contributing

Contributions welcome! Please open an issue first to discuss the change you'd like to make.

1. Fork the repo
2. Create a feature branch (`git checkout -b feat/amazing-idea`)
3. Commit your changes (`git commit -m 'Add amazing idea'`)
4. Push to the branch (`git push origin feat/amazing-idea`)
5. Open a Pull Request

## License

MIT — see [LICENSE](LICENSE) for details.

---

<p align="center">
  Built with Flutter<br>
  <sub>Smart budgeting, simplified.</sub>
</p>
