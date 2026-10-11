/// Pure budget-alert computation logic.
///
/// Intentionally has NO dependency on widgets or settings state. Callers pass
/// in the already-resolved threshold (e.g. from
/// `SettingsController.budgetAlertThreshold`) and the spent/limit figures.
library;

/// How urgently a budget needs attention.
enum BudgetAlertLevel {
  /// Within the configured threshold.
  ok,

  /// At or above the threshold but not yet over the limit.
  nearing,

  /// Spending has exceeded the limit.
  exceeded,
}

/// Immutable result of evaluating a single budget against its spending.
class BudgetAlertStatus {
  /// The classified alert level.
  final BudgetAlertLevel level;

  /// Amount spent within the budget period.
  final double spent;

  /// The budget limit (i.e. `budget.amount`).
  final double limit;

  /// `spent / limit`. NOT clamped — can exceed 1.0 when over budget. Zero when
  /// [limit] is non-positive.
  final double progress;

  const BudgetAlertStatus({
    required this.level,
    required this.spent,
    required this.limit,
    required this.progress,
  });

  /// Whether this budget is comfortably within its threshold.
  bool get isOk => level == BudgetAlertLevel.ok;

  /// Whether spending is at/above the threshold but not yet over the limit.
  bool get isNearing => level == BudgetAlertLevel.nearing;

  /// Whether spending has exceeded the limit.
  bool get isExceeded => level == BudgetAlertLevel.exceeded;

  /// Amount over the limit when [isExceeded]; otherwise 0.
  double get overBy => spent > limit ? spent - limit : 0.0;
}

/// Stateless evaluator mapping spent/limit/threshold to a [BudgetAlertStatus].
class BudgetAlerts {
  const BudgetAlerts._();

  /// Classifies a budget's spending.
  ///
  /// - `exceeded`: `spent > limit`.
  /// - `nearing`:  `progress * 100 >= thresholdPercent` and not exceeded.
  /// - `ok`:       otherwise.
  ///
  /// [progress] is `spent / limit`, unclamped, or `0` when [limit] <= 0.
  static BudgetAlertStatus evaluate({
    required double spent,
    required double limit,
    required int thresholdPercent,
  }) {
    final progress = limit > 0 ? spent / limit : 0.0;

    final BudgetAlertLevel level;
    if (spent > limit) {
      level = BudgetAlertLevel.exceeded;
    } else if (progress * 100 >= thresholdPercent) {
      level = BudgetAlertLevel.nearing;
    } else {
      level = BudgetAlertLevel.ok;
    }

    return BudgetAlertStatus(
      level: level,
      spent: spent,
      limit: limit,
      progress: progress,
    );
  }
}
