# Batch 4 API Contract — AI Features UI (Phase B)

The offline insights engine (Phase A) is already built, committed, and tested at
`lib/services/insights/`. Both agents CONSUME it — neither edits it. Four
features wired into the UI, split across two agents on disjoint files.

Engine entry points (do NOT modify these files):
- `CategorizationEngine.suggest({description, categories, history, type}) -> CategorySuggestion?`
  (lib/services/insights/categorization_engine.dart). CategorySuggestion has
  `int categoryId`, `String reason`, `bool fromHistory`.
- `AnomalyEngine.detect({transactions, history}) -> List<SpendingAnomaly>`
  (lib/services/insights/anomaly_engine.dart). SpendingAnomaly has
  `Transaction transaction`, `double zScore`, `double categoryMean`,
  `double timesTypical`.
- `ForecastEngine.forecastBudget({budget, monthTransactions, recurring, now}) -> BudgetForecast`
  and `forecastMonth(...) -> MonthForecast`
  (lib/services/insights/forecast_engine.dart). BudgetForecast has
  `spentSoFar`, `remainingRecurring`, `projectedDiscretionary`, `projectedTotal`,
  `bool projectedToExceed`, `double projectedOverBy`.
- `InsightsEngine(repositories).buildInsights({now, currencySymbol}) -> List<Insight>`
  and `.topInsight({now, currencySymbol}) -> Insight?`
  (lib/services/insights/insights_engine.dart). Insight has
  `InsightKind kind {info,positive,warning}`, `String title`, `String detail`,
  `int priority`.

Shared conventions:
- Currency: format amounts via CurrencyFormatter (lib/utils/currency.dart) with
  the symbol from `context.read<SettingsController>().currencySymbol`. When calling
  InsightsEngine, pass that symbol as `currencySymbol`.
- Repositories via `context.read<AppRepositories>()`; providers already exist.
- Guard BuildContext across async gaps.
- Use FVM Flutter ~/fvm/versions/3.41.7/bin/flutter. Tests via in-memory
  test/helpers/test_db.dart (TestDb.create()).

================================================================================
## AGENT A — "txn-intel"  (transaction-screen features)
================================================================================

### A1. Auto-categorization (edit `lib/screens/transactions/add_transaction_screen.dart`)
- As the user types the Description, debounce (~400ms), then call
  CategorizationEngine.suggest(description:, categories: <from CategoryProvider,
  filtered to current _selectedType>, history: <TransactionProvider.transactions>,
  type: _selectedType).
- Show a suggestion CHIP directly BELOW the description field, ONLY when:
  a suggestion exists AND the user has NOT already selected a category
  (_selectedCategoryKey == null). Label e.g. "Suggested: Groceries" with the
  reason as a tooltip/subtitle. Tapping the chip sets _selectedCategoryKey to the
  suggested id (and the existing category selector reflects it).
- The chip disappears once a category is chosen. Never auto-apply silently.
- Keep all existing save/validation behaviour unchanged.

### A2. Anomaly flags (edit `lib/screens/transactions/transaction_list_screen.dart`)
- Compute anomalies ONCE per build via
  AnomalyEngine.detect(transactions: <the expenses currently shown>,
  history: <TransactionProvider.transactions>). Build a Set of flagged
  transaction ids for O(1) lookup in the list builder.
- For a flagged transaction, show a small amber warning icon AND a muted inline
  label "Unusually large" under the row (keep it subtle — small amber text).
- Make the row (or icon) tappable to show a bottom sheet / dialog with the
  reason, e.g. "This <amount> is about <N>x your typical <category> spend of
  <mean>." Use CurrencyFormatter + symbol for amounts.
- Respect the existing filter/search — flags apply to whatever is displayed.

### txn-intel OWNS (only):
- lib/screens/transactions/add_transaction_screen.dart
- lib/screens/transactions/transaction_list_screen.dart
- test/screens/txn_intel_test.dart (new, optional widget test — at least ensure
  both screens still build)
MUST NOT edit: home_screen.dart, budget_list_screen.dart, reports_screen.dart,
the engine, repositories, models, or any insights-ui file.

================================================================================
## AGENT B — "insights-ui"  (budgets, reports, dashboard)
================================================================================

### B1. Budget forecast line (edit `lib/screens/budgets/budget_list_screen.dart`)
- For each budget card, compute ForecastEngine.forecastBudget(budget:,
  monthTransactions: <this month's transactions from TransactionProvider>,
  recurring: <RecurringProvider rules>, now: DateTime.now()).
- Show a SECONDARY, muted line on the card: "Projected: <projectedTotal> /
  <budget.amount>" via CurrencyFormatter + symbol. If projectedToExceed, tint it
  amber/red and append "(over by <projectedOverBy>)".
- EARLY-MONTH SUPPRESSION: do not show the projection line when fewer than 4 days
  of the month have elapsed (run-rate is noise). Show nothing in that window.
- Keep existing reactive alert coloring (from the budget-alerts feature) intact;
  the projection is an ADDITIONAL muted line, not a replacement.

### B2. Reports Insights tab (edit `lib/screens/reports/reports_screen.dart`)
- Bump TabController length 4 -> 5; add a 5th tab "Insights"
  (icon Icons.lightbulb_outline or similar) and a _buildInsightsTab().
- The tab shows the full list from InsightsEngine(repositories).buildInsights(
  currencySymbol: <symbol>). Render each Insight as a Card/ListTile with an icon
  coloured by kind (info/positive/warning) + title + detail. Show an empty-state
  message when the list is empty. Use a FutureBuilder (engine is async).

### B3. Dashboard insight highlight (new widget + edit `lib/screens/home_screen.dart`)
- NEW widget `lib/widgets/insight_highlight.dart`:
  `class InsightHighlight extends StatelessWidget { const InsightHighlight({super.key, this.onTap}); final VoidCallback? onTap; }`
  Uses a FutureBuilder on InsightsEngine(context.read<AppRepositories>())
  .topInsight(currencySymbol: <symbol>). Renders a compact card for the single
  top insight (icon by kind + title + detail), tappable (calls onTap). Renders
  SizedBox.shrink() when there is no insight.
- In home_screen.dart: embed InsightHighlight directly BELOW the existing
  BudgetAlertSummary banner (alerts above, insight below — alerts are actionable,
  insights informational). onTap switches the bottom nav to the Reports tab
  (index 4) — reuse the existing onSelectTab mechanism added for the alert banner.

### insights-ui OWNS (only):
- lib/screens/budgets/budget_list_screen.dart
- lib/screens/reports/reports_screen.dart
- lib/widgets/insight_highlight.dart (new)
- lib/screens/home_screen.dart
- test/screens/insights_ui_test.dart (new, optional — at least ensure screens build)
MUST NOT edit: add_transaction_screen.dart, transaction_list_screen.dart, the
engine, repositories, models, settings, or any txn-intel file.

================================================================================
## Shared rules
================================================================================
- No file edited by both agents. home_screen.dart = insights-ui only.
  transaction_list_screen.dart & add_transaction_screen.dart = txn-intel only.
- Neither agent edits lib/services/insights/* (consume only) or the models.
- Each agent: analyze its own files (0 errors) + run its own test before 'done'.
  Orchestrator runs full analyze + full suite + web build after merge.
- Features must be purely additive — existing behaviour (save flow, filters,
  budget reactive alerts, existing report tabs, dashboard cards) unchanged.
