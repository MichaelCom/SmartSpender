import '../../models/transaction.dart';
import '../../repositories/repositories.dart';
import 'anomaly_engine.dart';
import 'forecast_engine.dart';

/// Severity/kind of an insight, used by the UI to pick an icon/colour.
enum InsightKind { info, positive, warning }

/// A single templated, human-readable insight.
class Insight {
  final InsightKind kind;
  final String title;
  final String detail;

  /// Priority for choosing the single most-important insight (higher = more
  /// important). Used by the dashboard highlight.
  final int priority;

  const Insight({
    required this.kind,
    required this.title,
    required this.detail,
    this.priority = 0,
  });
}

/// Composes the curated set of offline insights from the user's data.
///
/// On-demand: pulls fresh data from the repositories and analyses in-memory.
/// Formatting of currency is left to the UI (insights carry raw strings with
/// numbers already rounded; the caller may re-render amounts if desired) — to
/// keep the engine free of settings/formatting dependencies, amounts are
/// embedded using a plain two-decimal representation and the UI can leave them
/// as-is (they are already prefixed by the currency symbol at call sites that
/// pass one in; see [currencySymbol]).
class InsightsEngine {
  InsightsEngine(this._repositories);

  final AppRepositories _repositories;

  /// Builds all applicable insights for the month containing [now].
  ///
  /// [currencySymbol] is injected so amount strings read naturally; it defaults
  /// to 'R' but the UI should pass SettingsController.currencySymbol.
  Future<List<Insight>> buildInsights({
    DateTime? now,
    String currencySymbol = 'R',
  }) async {
    final today = now ?? DateTime.now();
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 0, 23, 59, 59);
    final prevStart = DateTime(today.year, today.month - 1, 1);
    final prevEnd = DateTime(today.year, today.month, 0, 23, 59, 59);

    final allTx = await _repositories.transactions.getAllWithCategoryInfo();
    final recurring = await _repositories.recurring.getAll();

    final thisMonth = allTx
        .where((t) => !t.date.isBefore(monthStart) && !t.date.isAfter(monthEnd))
        .toList();
    final lastMonth = allTx
        .where((t) => !t.date.isBefore(prevStart) && !t.date.isAfter(prevEnd))
        .toList();

    final insights = <Insight>[];
    String money(double v) => '$currencySymbol${v.toStringAsFixed(2)}';

    // --- Savings rate (this month) ---
    final income = _sum(thisMonth, 'income');
    final expenses = _sum(thisMonth, 'expense');
    if (income > 0) {
      final rate = ((income - expenses) / income * 100).round();
      if (rate >= 0) {
        insights.add(Insight(
          kind: rate >= 20 ? InsightKind.positive : InsightKind.info,
          title: 'Savings rate',
          detail: 'You saved $rate% of your income this month.',
          priority: rate >= 20 ? 50 : 30,
        ));
      } else {
        insights.add(Insight(
          kind: InsightKind.warning,
          title: 'Spending exceeds income',
          detail: 'You spent ${money(expenses - income)} more than you earned '
              'this month.',
          priority: 80,
        ));
      }
    }

    // --- Biggest category (this month) ---
    final byCat = _expensesByCategoryName(thisMonth);
    if (byCat.isNotEmpty && expenses > 0) {
      final top = byCat.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final pct = (top.value / expenses * 100).round();
      insights.add(Insight(
        kind: InsightKind.info,
        title: 'Biggest expense category',
        detail: '${top.key} was your largest expense this month '
            '(${money(top.value)}, $pct% of spending).',
        priority: 40,
      ));
    }

    // --- Top mover (month-over-month category change) ---
    if (lastMonth.isNotEmpty) {
      final thisByCat = _expensesByCategoryName(thisMonth);
      final lastByCat = _expensesByCategoryName(lastMonth);
      String? moverName;
      double moverDelta = 0;
      for (final name in {...thisByCat.keys, ...lastByCat.keys}) {
        final delta = (thisByCat[name] ?? 0) - (lastByCat[name] ?? 0);
        if (delta.abs() > moverDelta.abs()) {
          moverDelta = delta;
          moverName = name;
        }
      }
      if (moverName != null && moverDelta.abs() >= 1) {
        final up = moverDelta > 0;
        final lastVal = lastByCat[moverName] ?? 0;
        final pct = lastVal > 0 ? (moverDelta.abs() / lastVal * 100).round() : null;
        insights.add(Insight(
          kind: up ? InsightKind.warning : InsightKind.positive,
          title: 'Biggest change vs last month',
          detail: '$moverName ${up ? 'rose' : 'fell'} by '
              '${money(moverDelta.abs())}${pct != null ? ' ($pct%)' : ''} '
              'compared to last month.',
          priority: 45,
        ));
      }
    }

    // --- Anomaly roll-up (this month) ---
    final anomalies = AnomalyEngine.detect(
      transactions: thisMonth.where((t) => t.type == 'expense').toList(),
      history: allTx,
    );
    if (anomalies.isNotEmpty) {
      insights.add(Insight(
        kind: InsightKind.warning,
        title: 'Unusual spending',
        detail: anomalies.length == 1
            ? '1 unusually large expense was flagged this month.'
            : '${anomalies.length} unusually large expenses were flagged this '
                'month.',
        priority: 60,
      ));
    }

    // --- Forecast roll-up (budgets projected to exceed) ---
    final budgets = await _repositories.budgets.getAllWithCategoryInfo();
    final activeBudgets = budgets.where((b) {
      return b.startDate.isBefore(today.add(const Duration(days: 1))) &&
          b.endDate.isAfter(today.subtract(const Duration(days: 1)));
    }).toList();
    var projectedExceed = 0;
    for (final b in activeBudgets) {
      final f = ForecastEngine.forecastBudget(
        budget: b,
        monthTransactions: thisMonth,
        recurring: recurring,
        now: today,
      );
      if (f.projectedToExceed) projectedExceed++;
    }
    if (projectedExceed > 0) {
      insights.add(Insight(
        kind: InsightKind.warning,
        title: 'Budget forecast',
        detail: projectedExceed == 1
            ? "You're on track to exceed 1 budget this month."
            : "You're on track to exceed $projectedExceed budgets this month.",
        priority: 70,
      ));
    }

    // Most important first.
    insights.sort((a, b) => b.priority.compareTo(a.priority));
    return insights;
  }

  /// Convenience: the single most important insight, or null.
  Future<Insight?> topInsight({
    DateTime? now,
    String currencySymbol = 'R',
  }) async {
    final all = await buildInsights(now: now, currencySymbol: currencySymbol);
    return all.isEmpty ? null : all.first;
  }

  static double _sum(List<Transaction> txs, String type) =>
      txs.where((t) => t.type == type).fold(0.0, (s, t) => s + t.amount);

  static Map<String, double> _expensesByCategoryName(List<Transaction> txs) {
    final map = <String, double>{};
    for (final t in txs.where((t) => t.type == 'expense')) {
      final name = t.categoryName ?? 'Uncategorised';
      map[name] = (map[name] ?? 0) + t.amount;
    }
    return map;
  }
}
