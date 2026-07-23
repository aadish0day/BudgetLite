# Project Synopsis
## BudgetLite: Premium Offline-First Personal Budgeting App

---

| Field | Details |
|---|---|
| **Project Title** | BudgetLite: Smart Budgeting, Simplified |
| **Platform** | Android (Flutter) |
| **Type** | Offline-first personal finance manager |
| **State Management** | Riverpod |
| **Database** | Drift (SQLite) |
| **Version** | 1.0.0 |

---

## 1. Abstract

BudgetLite is a premium offline-first personal budgeting application for Android built with Flutter. It combines envelope-style monthly budgeting, savings goals with progress tracking, debt management with EMI projections, and rich analytics into a single tactile interface. Users track income and expenses across multiple accounts (cash, bank, credit card, wallet), categorize transactions with auto-categorization from merchant keywords, and receive budget alerts when approaching category limits. All data resides locally in a Drift SQLite database with optional CSV export for backup. The app features biometric authentication, dark mode, recurring transaction auto-posting, SMS-based transaction detection (Android), and receipt photo attachment. The visual design follows Material 3 principles with a custom teal accent palette and layered shadow system that replaces bare borders with depth.

---

## 2. Problem Statement

Personal finance management remains fragmented for Indian users. Existing solutions fall into two categories: complex international apps (YNAB, Mint) that lack support for Indian payment methods like UPI, or basic expense trackers that lack envelope budgeting, debt management, and recurring transaction support. Most require internet connectivity and cloud accounts, creating privacy concerns and usability gaps in low-connectivity environments. Users need a single, offline-first app that handles the full Indian personal finance workflow: tracking UPI-based expenses, managing credit card bills with EMI calculations, setting savings goals with target dates, and providing visual analytics — all without a cloud dependency.

---

## 3. Objectives

- **Objective 1**: Build a multi-account transaction tracking system supporting cash, bank, credit card, and wallet accounts with individual balances and transfer support.
- **Objective 2**: Implement envelope-style monthly budgeting per category with a rollover toggle for carrying unspent amounts.
- **Objective 3**: Create savings goals with target amounts, target dates, progress tracking, and pace indicators.
- **Objective 4**: Develop a debt tracker supporting loans, EMIs, interest rates, and payoff projections with visual progress.
- **Objective 5**: Build an analytics dashboard with pie charts (category split), bar charts (week-over-week), line charts (6-month trends), heatmap calendar, and smart insights.
- **Objective 6**: Implement recurring transactions with auto-posting (daily, weekly, monthly, quarterly, yearly).
- **Objective 7**: Add receipt photo attachment, SMS auto-detection, and CSV export functionality.
- **Objective 8**: Provide biometric authentication and dark mode with custom palette.

---

## 4. Proposed Solution

BudgetLite is a single-activity Flutter application with a Drift SQLite database powering all CRUD operations locally. The navigation shell uses a 6-tab bottom navigation bar (Home, Transactions, Budget, Goals, Debt, Insights) with a floating action button for quick transaction entry. State management across 300+ Riverpod providers ensures reactive UI updates without boilerplate.

The transaction pipeline supports manual entry, recurring auto-posting, SMS-parsed detection from Android telephony, and receipt photo attachment via image_picker. Auto-categorization uses keyword matching against merchant names to assign categories (e.g., "Zomato" → Food). Transactions can be tagged with cross-cutting labels for grouping across categories.

The budgeting system implements envelope-style allocation per category with a monthly cycle. Each category budget tracks allocated amount, spent amount, and remaining balance. The rollover toggle carries unspent amounts to the next month. Budget alerts trigger local notifications at 80% and 100% of category limits.

Analytics are rendered using the fl_chart library with animated pie, bar, and line charts. The smart insights engine analyzes spending patterns against budgets and previous months to generate actionable observations (e.g., "You spent 30% more on Food this month"). A heatmap calendar visualizes daily spending intensity, and the year-in-review provides an annual summary.

---

## 5. Real-World Example

A user wants to set up tracking for their monthly finances:

1. **Setup**: User creates accounts (HDFC Bank, Paytm Wallet, Cash), sets their monthly income (₹65,000) in the Budget tab.
2. **Budget Allocation**: User allocates ₹15,000 to Food, ₹8,000 to Transport, ₹25,000 to Rent, ₹5,000 to Bills, ₹12,000 to Shopping.
3. **Transaction Entry**: User taps the FAB, enters "Lunch at Zomato — ₹450" — auto-categorized to Food. Later, an SMS from HDFC arrives: the SMS parser detects a UPI payment and suggests adding it.
4. **Recurring**: User sets Rent as a recurring transaction (₹25,000 monthly, auto-posted on the 1st).
5. **Goal**: User creates a goal for "New Laptop — ₹80,000 by December" with a current savings of ₹12,000.
6. **Debt**: User adds a credit card debt of ₹45,000 at 24% APR with a monthly payment of ₹5,000.
7. **Insight**: Mid-month, the Smart Insights engine notifies: "You've used 80% of your Food budget with 15 days remaining."

---

## 6. System Modules (10 Modules)

### Module 1: Multi-Account Management
Users create and manage financial accounts of different types (cash, bank, credit card, wallet). Each account tracks its current balance, which updates automatically on transactions and transfers. A default account handles single-account users. Accounts are displayed in the Home screen summary and can be edited or deleted from Settings.

### Module 2: Transaction Engine
Core CRUD for income and expense transactions. Each transaction has an amount, category, payment method, date, optional note, tags, and optional receipt photo path. Transactions support filtering by category, date range, and amount range. The transaction list displays with swipe-to-delete and tap-to-edit.

### Module 3: Auto-Categorization
A merchant keyword matching system maps transaction notes to categories. The matching is case-insensitive and checks against a predefined keyword-to-category mapping (e.g., "zomato", "swiggy" → Food). On the add transaction sheet, as the user types a note, the system suggests a category match in real-time.

### Module 4: Recurring Transactions
Transactions can be flagged as recurring with intervals (daily, weekly, biweekly, monthly, quarterly, yearly). A periodic check evaluates due recurring transactions and auto-creates new transaction records. Recurring transactions display a repeating indicator icon in the transaction list.

### Module 5: Envelope Budget System
Monthly budgets are allocated per expense category. The Budget screen shows each category with its allocated amount, current spending, a linear progress bar, and remaining balance. The rollover toggle carries unspent budget to the next month. A monthly income field sets the month's total available amount.

### Module 6: Savings Goals
Goals have a name, target amount, current amount, target date, color, and icon. Progress is displayed using an arc progress ring. A pace indicator calculates the per-day or per-month savings needed to reach the goal by the target date. A "Contribute" button allows quick fund allocation to the goal.

### Module 7: Debt Tracker
Debts track total amount, remaining amount, interest rate, start date, and category. Each debt displays a progress ring showing payoff percentage, monthly EMI calculation using the standard amortization formula, and projected payoff date. A payment sheet allows recording payments toward the debt.

### Module 8: Analytics & Insights
Pie charts show spending distribution by category. Bar charts compare this week vs last week. Line charts show 6-month spending trends. A day-of-week analysis identifies highest spending days. Smart insights generate natural-language observations about spending patterns, budget adherence, and category-level overruns. A heatmap calendar visualizes spend intensity. A year-in-review summarizes annual totals and savings rate.

### Module 9: SMS Parser (Android)
Reads SMS messages matching financial transaction patterns (UPI payments, card transactions, bank credits). Parses merchant name, amount, and date from SMS text using regex patterns. Presents parsed transactions for user confirmation before adding to the database. Requires Android READ_SMS permission.

### Module 10: Settings & Security
Account management (create/edit/delete financial accounts), CSV export of all transactions, demo data seeding, biometric app lock via local_auth, dark mode toggle, database backup via file export, and receipt gallery for browsing all attached receipt photos.

---

## 7. Technology Stack

| Layer | Technology | Role |
|---|---|---|
| **Framework** | Flutter 3.x | Cross-platform UI framework |
| **State Management** | Riverpod (code-gen) | Reactive state with 300+ providers |
| **Database** | Drift (SQLite) | Local relational data store |
| **Charts** | fl_chart | Animated pie, bar, line charts |
| **Animations** | flutter_animate | Entry, exit, and micro-interactions |
| **Icons** | Lucide Icons | Consistent iconography |
| **Fonts** | Google Fonts | DM Sans (display), Inter (body), JetBrains Mono (data) |
| **CSV Export** | csv + share_plus | Data portability |
| **Biometrics** | local_auth | Fingerprint / face unlock |
| **Notifications** | flutter_local_notifications | Budget alerts, bill reminders |
| **SMS Parsing** | telephony | Auto-detect UPI/credit transactions |

---

## 8. Drift Database Schema

```sql
-- Categories (pre-seeded + custom)
categories (
  id TEXT PK,
  name TEXT NOT NULL,
  icon TEXT,
  color INTEGER,
  type TEXT NOT NULL DEFAULT 'expense' -- expense | income
)

-- Accounts
accounts (
  id TEXT PK,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'cash', -- cash | bank | credit_card | wallet
  balance REAL NOT NULL DEFAULT 0,
  createdAt TEXT NOT NULL
)

-- Transactions (core table)
transactions (
  id TEXT PK,
  accountId TEXT NOT NULL REFERENCES accounts(id),
  categoryId TEXT NOT NULL REFERENCES categories(id),
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  paymentMethod TEXT NOT NULL DEFAULT 'cash',
  note TEXT,
  isRecurring INTEGER NOT NULL DEFAULT 0,
  recurringInterval TEXT, -- daily | weekly | monthly | etc.
  receiptImagePath TEXT,
  paymentMethodRef TEXT, -- UPI ref, cheque no.
  createdAt TEXT NOT NULL
)

-- Budgets (monthly per category)
budgets (
  id TEXT PK,
  categoryId TEXT NOT NULL REFERENCES categories(id),
  allocatedAmount REAL NOT NULL,
  month TEXT NOT NULL, -- YYYY-MM format
  rollover INTEGER NOT NULL DEFAULT 0,
  createdAt TEXT NOT NULL
)

-- Savings Goals
goals (
  id TEXT PK,
  name TEXT NOT NULL,
  targetAmount REAL NOT NULL,
  currentAmount REAL NOT NULL DEFAULT 0,
  targetDate TEXT NOT NULL,
  icon TEXT DEFAULT 'flag',
  color INTEGER,
  createdAt TEXT NOT NULL
)

-- Settings (key-value store for flexible app config)
app_settings (
  key TEXT PK,
  value TEXT NOT NULL
)
```

---

## 9. Competitive Analysis

| Feature | YNAB | MoneyManager | BudgetLite |
|---|---|---|---|
| **Offline-first** | No | Partial | **Yes** |
| **UPI support** | No | Yes | **Yes** |
| **Envelope budgeting** | Yes | No | **Yes** |
| **Debt tracker with EMI calc** | No | No | **Yes** |
| **Savings goals** | Yes | Yes | **Yes (with pace indicator)** |
| **Multi-account** | Yes | Yes | **Yes** |
| **Receipt photos** | No | Yes | **Yes** |
| **SMS auto-detect** | No | No | **Yes (Android)** |
| **Biometric lock** | No | No | **Yes** |
| **CSV export** | Yes | Yes | **Yes** |
| **Free** | Subscription | Freemium | **Free** |

---

## 10. Project Architecture

```
lib/
├── app.dart                       # Navigation shell (6 tabs + FAB)
├── main.dart                      # Bootstrap + providers
├── core/
│   ├── theme/                     # Material 3 tokens
│   ├── database/                  # Drift schema + DB class
│   ├── utils/                     # Formatters, parsers, helpers
│   └── widgets/                   # Shared arc ring, animated counter
├── features/
│   ├── home/                      # Dashboard: balance, quick budget, payments
│   ├── transactions/              # List + add/edit sheet + transfer sheet
│   ├── budget/                    # Monthly budget setup + category manager
│   ├── goals/                     # Savings goals with arc progress
│   ├── debt/                      # Debt tracker with EMI projection
│   ├── insights/                  # Charts, heatmap, year-in-review
│   ├── settings/                  # Accounts, export, security
│   └── onboarding/                # First-launch intro carousel
└── providers/
    ├── database_provider.dart     # DB instance singleton
    ├── transaction_provider.dart  # Transactions + CRUD
    ├── budget_provider.dart       # Budgets + monthly income
    ├── goal_provider.dart         # Goals + contributions
    └── settings_provider.dart     # App settings key-value
```

---

## 11. Development Timeline

| Phase | Tasks | Milestone |
|---|---|---|
| **Foundation** | Project setup, Drift schema, Riverpod providers, theme system | Database operations live |
| **Transactions** | Add/edit/delete transactions, multi-account, categories, auto-categorization | Core CRUD complete |
| **Budgeting** | Envelope budgets, rollover, monthly tracking, income setup | Budget engine live |
| **Goals & Debt** | Savings goals with arc progress, debt tracker with EMI, contributions | Goal + debt live |
| **Analytics** | Pie/bar/line charts, smart insights, heatmap, year-in-review, day-of-week | Insights engine live |
| **Polish** | SMS parser, receipts, CSV export, biometrics, dark mode, demo data | Feature-complete |
| **UI/UX Pass** | Animations, press states, layered shadows, empty states, spring transitions | Polished release |

---

## 12. Conclusion

BudgetLite addresses the fragmented personal finance management landscape for Indian users with a comprehensive, offline-first application that combines envelope budgeting, savings goals, debt tracking, and rich analytics in a single tactile interface. The 10 modules span the full personal finance workflow from transaction capture (manual, recurring, SMS-parsed) through analysis (charts, insights, heatmap) to security (biometric lock, local-only data). The Drift SQLite database ensures all data remains on-device with no cloud dependency, while CSV export provides optional portability. The Material 3 design language with custom teal accents, layered shadow system, and spring-microinteractions delivers a premium feel that reads above its zero-cost positioning.

---

## Interview Pitch

> *"I built a premium offline-first personal budgeting Android app called BudgetLite using Flutter and Riverpod. It handles the full Indian personal finance workflow: multi-account tracking with UPI support, envelope-style monthly budgeting with rollover, savings goals with pace indicators that tell you how much to save per day, a debt tracker with EMI calculations and payoff projections, and a full analytics suite with animated charts and a smart insights engine that generates natural-language observations about your spending. All data lives locally in SQLite with no cloud dependency, secured behind biometric authentication. The design uses Material 3 with a custom shadow system and spring animations that make it feel premium despite being completely free."*
