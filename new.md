# BudgetLite — Technical Architecture

You are a senior Flutter engineer building a premium offline-first personal budgeting application for Android. The app uses Drift (SQLite) for local persistence, Riverpod for reactive state management, and follows a feature-first directory architecture.

---

## PRIOR ART TO READ FIRST
- **YNAB (You Need A Budget)**: The envelope budgeting methodology that inspired BudgetLite's budget-per-category model. YNAB's "give every dollar a job" translates to allocating monthly amounts per expense category with rollover support.
- **MoneyManager (Indian expense tracker)**: Demonstrated that Indian users need UPI payment support, multiple account types (cash/bank/credit/wallet), and SMS-based transaction detection. BudgetLite adopts this awareness of the Indian market.
- **Material 3 Design System**: Flutter's M3 Token system via `ThemeData` — but BudgetLite overrides the default palette with a custom teal accent and replaces the default shadow/elevation system with layered `BoxShadow` lists.

---

## WHY THIS IS HARDER THAN A BASIC EXPENSE TRACKER
- **Envelope budgeting logic**: Not just CRUD on transactions. Each category has an allocated monthly amount, a running spent total, and a remaining balance. Rollover complicates this: unspent amounts carry to next month, which means budget state depends on the previous month's leftover. This is a stateful calculation, not a simple sum.
- **Recurring transaction auto-posting**: The system must periodically check which recurring transactions are due and auto-create transaction records. This requires a background check (on app launch + periodic timer) that evaluates `recurringInterval` against the last posted date.
- **SMS parsing reliability**: Android SMS text varies wildly between banks (HDFC, ICICI, SBI, Paytm). Parsing merchant name, amount, and date requires regex patterns specific to each bank's SMS format, with confidence scoring and user confirmation before creating transactions.
- **Multi-account balance consistency**: When a transfer occurs between two accounts, both balances must update atomically. If the transfer fails mid-way, the system must not leave one account debited and the other uncredited. Drift's transactions (`batch`) handle this, but the Riverpod invalidation must happen after both writes succeed.

---

## ARCHITECTURE

### Data Flow
```
User Action → Widget → Riverpod Provider → Drift DAO → SQLite
                                          ↕
                                   Notifier (state update)
                                          ↕
                                  Widget rebuild (ref.watch)
```

### Provider Hierarchy
```
databaseProvider (DB instance singleton)
├── categoriesProvider → List<Category>
├── accountsProvider → List<Account>
├── transactionsProvider → List<Transaction>
│   ├── thisMonthTransactionsProvider
│   ├── transactionsByMonthProvider(m)
│   └── totalSpentThisMonthProvider
├── budgetNotifierProvider → BudgetNotifier
│   ├── thisMonthBudgetsProvider
│   ├── monthlyIncomeProvider
│   └── totalSpentThisMonthProvider
├── goalNotifierProvider → GoalNotifier
│   └── goalsProvider
├── debtsProvider → DebtNotifier (in-memory)
├── settingsNotifierProvider → SettingsNotifier
└── smsParserProvider
```

---

## CORE BUSINESS LOGIC

### 1. Budget Rollover Calculation
```dart
// On each month's first load or budget initialization:
// 1. Get last month's budget for this category
// 2. If rollover is enabled, calculate: unspent = allocated - spent
// 3. Add unspent amount to this month's allocation
// 4. Floor at 0 (no negative rollover)

double calculateRollover(Budget lastMonth, double thisMonthSpent) {
  if (!lastMonth.rollover) return 0;
  final unspent = lastMonth.allocatedAmount - thisMonthSpent;
  return unspent > 0 ? unspent : 0;
}
```

### 2. Recurring Transaction Auto-Post
```dart
// On app launch + every hour while running:
// 1. Query all transactions where isRecurring = true
// 2. For each, check if `nextDueDate` has passed
// 3. If due and not already auto-posted this cycle, create a new transaction
// 4. Update `lastPostedDate` on the recurring transaction

DateTime computeNextDue(DateTime lastPosted, String interval) {
  return switch (interval) {
    'daily'    => lastPosted.add(Duration(days: 1)),
    'weekly'   => lastPosted.add(Duration(days: 7)),
    'biweekly' => lastPosted.add(Duration(days: 14)),
    'monthly'  => DateTime(lastPosted.year, lastPosted.month + 1, lastPosted.day),
    'quarterly'=> DateTime(lastPosted.year, lastPosted.month + 3, lastPosted.day),
    'yearly'   => DateTime(lastPosted.year + 1, lastPosted.month, lastPosted.day),
    _ => lastPosted,
  };
}
```

### 3. Auto-Categorization Engine
```dart
// Keyword → category mapping
final categoryKeywords = {
  'food':       ['zomato', 'swiggy', 'mcdonald', 'domino', 'pizza', 'dining', 'restaurant'],
  'transport':  ['uber', 'ola', 'rapido', 'metro', 'petrol', 'fuel', 'bus'],
  'shopping':   ['amazon', 'flipkart', 'myntra', 'ajio', 'meesho'],
  'bills':      ['electricity', 'water', 'gas', 'broadband', 'recharge', 'bill'],
  'rent':       ['rent', 'lease'],
  'income':     ['salary', 'freelance', 'refund', 'credit salary'],
};

String detectCategory(String note) {
  final lower = note.toLowerCase();
  for (final entry in categoryKeywords.entries) {
    if (entry.value.any((kw) => lower.contains(kw))) {
      return entry.key;
    }
  }
  return 'other'; // default fallback
}
```

### 4. Debt EMI Calculation
```dart
// Standard amortization formula
// EMI = P × r × (1+r)^n / ((1+r)^n - 1)
// Where: P = principal, r = monthly interest rate, n = months

double calculateEMI(double principal, double annualRate, int months) {
  if (annualRate == 0) return principal / months;
  final monthlyRate = annualRate / 12 / 100;
  final factor = pow(1 + monthlyRate, months).toDouble();
  return principal * monthlyRate * factor / (factor - 1);
}

int estimatePayoffMonths(double principal, double annualRate, double monthlyPayment) {
  if (monthlyPayment <= 0) return -1;
  if (annualRate == 0) return (principal / monthlyPayment).ceil();
  
  // Binary search for months needed
  int low = 1, high = 120; // max 10 years
  while (low < high) {
    final mid = (low + high) ~/ 2;
    final emi = calculateEMI(principal, annualRate, mid);
    if (emi <= monthlyPayment) high = mid;
    else low = mid + 1;
  }
  return low;
}
```

### 5. Smart Insights Generation
```dart
List<String> generateInsights({
  required Map<String, double> categorySpending,
  required List<Category> categories,
  required double totalSpent,
  required List<Budget> budgets,
}) {
  final insights = <String>[];
  
  // Top category
  final top = categorySpending.entries.reduce((a,b) => a.value > b.value ? a : b);
  final cat = categories.firstWhere((c) => c.id == top.key);
  final pct = (top.value / totalSpent * 100).toStringAsFixed(0);
  insights.add('${cat.name} is your highest spend at $pct% of total');
  
  // Daily average
  final daysInMonth = DateTime.now().day;
  final avg = (totalSpent / daysInMonth).toStringAsFixed(0);
  insights.add('You spend INR $avg per day on average');
  
  // Over budget categories
  for (final b in budgets) {
    final spent = categorySpending[b.categoryId] ?? 0;
    if (spent > b.allocatedAmount) {
      final cat = categories.firstWhere((c) => c.id == b.categoryId);
      final over = ((spent - b.allocatedAmount) / b.allocatedAmount * 100).toStringAsFixed(0);
      insights.add('${cat.name} is over budget by $over%');
    }
  }
  
  return insights;
}
```

---

## DATABASE DESIGN

### Tables
```sql
-- Categories: seeded + custom, expense or income type
categories (id TEXT PK, name TEXT, icon TEXT, color INTEGER, type TEXT)

-- Accounts: financial accounts with real-time balance
accounts (id TEXT PK, name TEXT, type TEXT, balance REAL, createdAt TEXT)

-- Transactions: core financial events
transactions (id TEXT PK, accountId TEXT FK, categoryId TEXT FK,
  amount REAL, date TEXT, paymentMethod TEXT, note TEXT,
  isRecurring INTEGER, recurringInterval TEXT,
  receiptImagePath TEXT, paymentMethodRef TEXT, createdAt TEXT)

-- Budgets: monthly allocation per category
budgets (id TEXT PK, categoryId TEXT FK, allocatedAmount REAL,
  month TEXT, rollover INTEGER, createdAt TEXT)

-- Goals: savings targets
goals (id TEXT PK, name TEXT, targetAmount REAL, currentAmount REAL,
  targetDate TEXT, icon TEXT, color INTEGER, createdAt TEXT)

-- App Settings: flexible key-value store
app_settings (key TEXT PK, value TEXT)
```

### Key Queries
```sql
-- Monthly spending by category
SELECT categoryId, SUM(amount) as total
FROM transactions
WHERE date >= '2026-07-01' AND date < '2026-08-01' AND amount > 0
GROUP BY categoryId;

-- Account balance (computed from transactions + initial balance)
SELECT a.balance + COALESCE(SUM(
  CASE WHEN t.amount < 0 THEN ABS(t.amount)
       WHEN t.categoryId = 'transfer' AND t.accountId = a.id THEN -t.amount
       ELSE -t.amount END
), 0)
FROM accounts a
LEFT JOIN transactions t ON t.accountId = a.id
WHERE a.id = ?;

-- Due recurring transactions
SELECT * FROM transactions
WHERE isRecurring = 1
  AND datetime(createdAt, '+' || CASE recurringInterval
    WHEN 'daily' THEN '1 days'
    WHEN 'weekly' THEN '7 days'
    WHEN 'monthly' THEN '1 months'
  END) <= datetime('now');
```

---

## NAVIGATION ARCHITECTURE

### Shell Structure
```
MaterialApp
└── MainShell (StatefulWidget)
    ├── IndexedStack → AnimatedSwitcher
    │   ├── [0] HomeScreen (ConsumerWidget)
    │   ├── [1] TransactionsScreen (ConsumerWidget)
    │   ├── [2] BudgetScreen (ConsumerStatefulWidget)
    │   ├── [3] GoalsScreen (ConsumerWidget)
    │   ├── [4] DebtScreen (ConsumerStatefulWidget)
    │   └── [5] InsightsScreen (ConsumerWidget)
    ├── BottomNavigationBar (6 items)
    └── FloatingActionButton (tabs 0-1 only)
        ├── Expense → AddTransactionSheet
        └── Transfer → TransferSheet
```

### Route Design
No named routes — the app uses a single-scaffold shell with IndexedStack for tab persistence. All secondary flows (add transaction, edit, transfer, goal creation, debt payment) use modal bottom sheets. Dialogs are used for confirmation and account management. This keeps the navigation stack flat and avoids the complexity of Flutter's Navigator for a single-activity app.

---

## STATE MANAGEMENT PATTERNS

### Provider Types Used
```dart
// 1. Simple data fetch (read-only, auto-refresh)
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).get();
});

// 2. Mutable state with notifier
final transactionNotifierProvider = NotifierProvider<TransactionNotifier, TransactionState>(
  TransactionNotifier.new,
);

// 3. Parameterized queries
final transactionsByMonthProvider = FutureProvider.family<List<Transaction>, String>(
  (ref, monthKey) async { ... },
);

// 4. Computed values (derived state)
final totalSpentThisMonthProvider = Provider<double>((ref) {
  final transactions = ref.watch(thisMonthTransactionsProvider).valueOrNull ?? [];
  return transactions.where((t) => t.amount > 0).fold(0, (a, b) => a + b.amount);
});
```

### Invalidation Strategy
- After any write operation, invalidate the relevant provider chain
- Transaction writes invalidate: `transactionsProvider`, `thisMonthTransactionsProvider`, `totalSpentThisMonthProvider`, budget-derived providers
- Budget writes invalidate: `thisMonthBudgetsProvider`, `budgetNotifierProvider`
- Goal writes invalidate: `goalsProvider`
- Nested invalidations cascade via `ref.invalidate(provider)` → dependent providers auto-refresh

---

## PERFORMANCE CONSIDERATIONS

### Database
- All queries use Drift's type-safe DAO methods (no raw SQL in providers)
- Transactions table indexed on `date` and `categoryId` for common queries
- Budget queries filtered by `month` string (YYYY-MM format) for fast lookups
- Batch inserts for demo data seeding

### Rendering
- Transaction list uses `ListView` with item count typically <500 (no virtualization needed)
- Chart rebuilds gated behind `valueOrNull` to prevent null-state flicker
- `AnimatedSwitcher` for page transitions uses `const` keys for widget identity
- All animations use compositor-friendly properties (`transform`, `opacity`)

### Memory
- `TextEditingController`s disposed in `dispose()` overrides
- Provider states are immutable data classes (no accidental mutation)
- Images loaded via `FileImage` (local) — no network caching needed

---

## KNOWN GAPS & FUTURE WORK

1. **No cloud backup**: All data is local-only. CSV export provides manual backup. Future: Drive/Google backup integration.
2. **No multi-currency**: Currently single-currency (INR). The `formatCurrency` utility has a currency switch, but the schema doesn't store per-transaction currency.
3. **No spending limits on goals**: Goals track progress but don't enforce hard limits. Future: "Stop saving when goal is reached" auto-stop.
4. **No budget carry-over**: Rollover works per category, but unspent budget across all categories doesn't reallocate automatically.
5. **SMS parser is best-effort**: Regex patterns cover major Indian banks (HDFC, ICICI, SBI, Paytm) but may fail on newer formats. Confidence scoring flags low-confidence parses for manual review.
6. **Recurring auto-post requires app running**: The timer-based auto-post only works while the app is in memory. Future: Android WorkManager for background execution.
7. **No split transactions**: One payment across multiple categories isn't supported. Tags serve as a workaround.

---

## DELIVERABLES

1. **Drift database schema** with 6 tables (categories, accounts, transactions, budgets, goals, app_settings) — `database.dart` + `tables.dart`
2. **Riverpod provider layer** — 5 notifier providers + 20+ utility providers for computed state
3. **Feature screens** — 6 main screens + 4 bottom sheets + 1 onboarding flow
4. **UI component library** — arc progress ring, animated number counter, heatmap calendar, year-in-review card
5. **Auto-categorization engine** — keyword matching with real-time suggestion on transaction entry
6. **Recurring transaction engine** — interval-based auto-posting with due-date computation
7. **SMS parser module** — bank-specific regex patterns with confidence scoring
8. **CSV export** — full data export via `share_plus` with proper column mapping
9. **Design system** — colored tokens, typography helpers, layered shadow constants, spatial constants
10. **Test plan**: validate budget rollover math, recurring interval computation, auto-categorization keyword matching, and Drift CRUD operations via widget tests
