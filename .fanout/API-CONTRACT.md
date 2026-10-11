# Batch 3 API Contract — Budget Alerts (in-app) + Recurring Transactions

Two independent features, built in parallel. The ownership split is engineered
so NO file is edited by both agents.

- **alerts** agent — in-app budget alerts (threshold setting, card coloring,
  at-save warning, a dashboard-summary WIDGET consumed by the recurring agent).
- **recurring** agent — recurring transactions (schema v2, repo, startup
  generator, management screen) PLUS it owns all shared integration files
  (home_screen.dart, main.dart).

Use FVM Flutter: `~/fvm/versions/3.41.7/bin/flutter`. App uses Drift + Provider +
AppRepositories (lib/repositories/repositories.dart). In-memory test helper:
test/helpers/test_db.dart → TestDb.create().

================================================================================
## FEATURE A — Budget Alerts (alerts agent)
================================================================================

### A1. Threshold setting (edit `lib/providers/settings_provider.dart`)
Add to SettingsController, matching the existing style:
- key: `static const String budgetAlertThresholdKey = 'settings.budgetAlertThreshold';`
- `static const int defaultBudgetAlertThreshold = 80;` (percent)
- `int get budgetAlertThreshold;`
- `Future<void> setBudgetAlertThreshold(int percent);` (clamp 1..100, persist, notify, skip no-op)
- Load it in `SettingsController.load()` alongside the others.
Do NOT change existing themeMode/currency behaviour or keys.

### A2. Alert computation helper (new file `lib/utils/budget_alerts.dart`)
Pure logic, no widgets, no settings dependency:
```dart
enum BudgetAlertLevel { ok, nearing, exceeded }

class BudgetAlertStatus {
  final BudgetAlertLevel level;
  final double spent;
  final double limit;        // budget.amount
  final double progress;     // spent/limit, not clamped
  const BudgetAlertStatus({...});
  bool get isOk => level == BudgetAlertLevel.ok;
}

class BudgetAlerts {
  /// thresholdPercent is the "nearing" boundary (e.g. 80).
  /// exceeded: spent > limit. nearing: progress*100 >= thresholdPercent && !exceeded.
  static BudgetAlertStatus evaluate({
    required double spent,
    required double limit,
    required int thresholdPercent,
  });
}
```

### A3. Dashboard summary WIDGET (new file `lib/widgets/budget_alert_summary.dart`)
A self-contained widget the recurring agent will embed in the dashboard:
```dart
/// Shows a compact banner ("2 over · 1 nearing") ONLY when something needs
/// attention; renders SizedBox.shrink() when all budgets are ok. Tapping it
/// calls [onTap] (the host navigates to the Budgets tab).
class BudgetAlertSummary extends StatelessWidget {
  const BudgetAlertSummary({super.key, this.onTap});
  final VoidCallback? onTap;
}
```
Internally it reads BudgetProvider + TransactionProvider (via context.watch) and
SettingsController.budgetAlertThreshold, computes per-active-budget status with
BudgetAlerts.evaluate, and summarises counts. Spent-per-budget: reuse the same
logic budget_list_screen uses (transactions for that category within the budget
period). Keep it dependency-light; a small private helper to compute spent is fine.

### A4. Budget card coloring + status (edit `lib/screens/budgets/budget_list_screen.dart`)
Use BudgetAlerts.evaluate(threshold from SettingsController) to color each card
and show a status chip: ok (normal), nearing (amber "Nearing limit"), exceeded
(red "Over by <currency>X"). Use the existing CurrencyFormatter + currency symbol
from SettingsController for any amounts. Keep existing delete/edit behaviour.

### A5. At-save warning (edit `lib/screens/transactions/add_transaction_screen.dart`)
After a transaction is saved successfully AND it is an expense with a category:
look up the active budget for that category (BudgetProvider.getActiveBudgetForCategory),
compute projected spent (existing spend in the budget period + this amount),
evaluate with the threshold. If level is nearing or exceeded, show a non-blocking
SnackBar BEFORE/with the existing success message, e.g.
"Heads up: this puts your Food budget R120 over." Guard context across async gaps.
Do not block navigation.

### A6. Settings UI for threshold (edit `lib/screens/settings/settings_screen.dart`)
Add a "Budget alerts" row under the existing sections: a slider or stepper for
the threshold percent (1..100, default 80), wired to
SettingsController.setBudgetAlertThreshold. Short caption: "Warn when a budget
reaches this percentage."

### alerts agent OWNS (and nothing else):
- lib/providers/settings_provider.dart
- lib/utils/budget_alerts.dart (new)
- lib/widgets/budget_alert_summary.dart (new)
- lib/screens/budgets/budget_list_screen.dart
- lib/screens/transactions/add_transaction_screen.dart
- lib/screens/settings/settings_screen.dart
- test/utils/budget_alerts_test.dart (new)
MUST NOT touch: home_screen.dart, main.dart, app_database.dart, repositories,
models, or any recurring file.

================================================================================
## FEATURE B — Recurring Transactions (recurring agent)
================================================================================

### B1. Schema change (edit `lib/database/app_database.dart`)
- Add a `RecurringTransactions` table (@DataClassName('RecurringTransactionRow')):
  id (autoIncrement), amount (real), description (text nullable),
  categoryId (int nullable, references Categories, onDelete SET NULL),
  type (text: income|expense), frequency (text: daily|weekly|monthly|yearly),
  startDate (dateTime), endDate (dateTime nullable),
  lastGeneratedDate (dateTime nullable), createdAt (dateTime).
- Add a nullable `recurringId` column to the existing `Transactions` table,
  references RecurringTransactions id, onDelete SET NULL.
- Bump `schemaVersion` to 2 and add `onUpgrade` to MigrationStrategy:
  from 1→2 create the new table and add the recurringId column
  (m.createTable(recurringTransactions); m.addColumn(transactions, transactions.recurringId)).
  KEEP the existing beforeOpen PRAGMA foreign_keys = ON.
- Regenerate: `~/fvm/versions/3.41.7/bin/flutter pub run build_runner build --delete-conflicting-outputs`.

### B2. Domain model (new file `lib/models/recurring_transaction.dart`)
Plain class mirroring the table (id nullable, etc.), with copyWith, ==, a
`DateTime nextDueDate(DateTime from)` helper, and an `advance(DateTime d)` helper
that returns the next date for the frequency (daily:+1d, weekly:+7d,
monthly:+1 month, yearly:+1 year). isActive(now): now within [startDate, endDate?].

### B3. Repository (edit `lib/repositories/repositories.dart` + `lib/repositories/drift_repositories.dart`)
Add RecurringTransactionRepository interface + Drift impl:
getAll(), getById(int), insert(RecurringTransaction)->int, update(...), delete(int).
Wire it into AppRepositories (new getter `recurring`) and DriftRepositories, and
include it in clearAllData() (delete recurring rows too).
NOTE: this is the ONE file both features might want, but alerts does NOT touch
repositories — so recurring owns repositories.dart/drift_repositories.dart solely.

### B4. Generator service (new file `lib/services/recurring_generator.dart`)
```dart
class RecurringGenerator {
  RecurringGenerator(this._repositories);
  /// For each active rule, create missing Transactions from the day AFTER
  /// lastGeneratedDate (or startDate if null) up to and including today
  /// (never past endDate). Each created Transaction carries recurringId and the
  /// rule's amount/type/category/description. Update the rule's lastGeneratedDate.
  /// Idempotent: running twice the same day creates nothing new.
  Future<int> generateDue({DateTime? now}); // returns count created
}
```
Insert generated transactions via the transaction repository with recurringId set.

### B5. Startup wiring (edit `lib/main.dart`)
After building repositories and BEFORE runApp (or right after, before first
frame), run `await RecurringGenerator(repositories).generateDue();` so missed
occurrences are caught up. Keep existing settings load + provider setup intact.

### B6. Management screen (new files)
- `lib/screens/recurring/recurring_list_screen.dart` — lists rules (frequency,
  amount via CurrencyFormatter + symbol, next due date), add/edit/delete.
  Deleting a rule keeps already-generated transactions (recurringId → null via
  the FK's SET NULL; just delete the rule row).
- `lib/screens/recurring/add_recurring_screen.dart` — form: amount, type, category,
  description, frequency (daily/weekly/monthly/yearly), start date, optional end date.
- Use a RecurringProvider (new `lib/providers/recurring_provider.dart`,
  ChangeNotifier) backed by the repository, following the existing provider
  pattern; provide it in main.dart.

### B7. Entry point + dashboard banner host (edit `lib/screens/home_screen.dart`)
- Add a "Recurring" entry in the dashboard overflow PopupMenu (new value
  'recurring') that pushes RecurringListScreen.
- Embed the alerts agent's `BudgetAlertSummary` widget near the top of the
  dashboard body, passing onTap that switches the bottom nav to the Budgets tab
  (index 3). Import it from lib/widgets/budget_alert_summary.dart. This is the
  ONLY cross-feature coupling and it is one-directional (recurring consumes the
  alerts widget).

### recurring agent OWNS (and nothing else):
- lib/database/app_database.dart (+ regenerated .g.dart)
- lib/models/recurring_transaction.dart (new)
- lib/repositories/repositories.dart, lib/repositories/drift_repositories.dart
- lib/services/recurring_generator.dart (new)
- lib/providers/recurring_provider.dart (new)
- lib/screens/recurring/*.dart (new)
- lib/main.dart
- lib/screens/home_screen.dart
- test/services/recurring_generator_test.dart (new)
- test/models/recurring_transaction_test.dart (new, optional)
MUST NOT touch: settings_provider.dart, budget_list_screen.dart,
add_transaction_screen.dart, settings_screen.dart, budget_alerts.dart,
budget_alert_summary.dart (it only IMPORTS/embeds the latter, never edits it).

================================================================================
## Shared rules
================================================================================
- No file is edited by both agents. home_screen.dart & main.dart = recurring only.
  settings_provider.dart & the alert UI files = alerts only. The dashboard banner
  is a widget alerts CREATES and recurring EMBEDS.
- Currency: always format via CurrencyFormatter with the symbol from
  SettingsController.currencySymbol (both agents).
- Guard BuildContext across async gaps (mounted / context.mounted).
- Each agent: `flutter analyze <own files>` → 0 errors, run its own test → pass,
  before reporting done. Orchestrator runs full analyze + full suite + web build
  after merge, and resolves any seam issues.
- recurring agent: because it changes the Drift schema, run build_runner and
  ensure the generated file compiles before reporting done.
