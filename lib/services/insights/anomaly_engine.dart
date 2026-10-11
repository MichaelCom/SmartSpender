import 'dart:math';

import '../../models/transaction.dart';

/// An expense flagged as unusually large for its category.
class SpendingAnomaly {
  final Transaction transaction;

  /// How many standard deviations above the category mean.
  final double zScore;

  /// The category's historical mean expense amount (excluding this tx).
  final double categoryMean;

  /// Human-readable multiple, e.g. 3 for "~3x your usual".
  final double timesTypical;

  const SpendingAnomaly({
    required this.transaction,
    required this.zScore,
    required this.categoryMean,
    required this.timesTypical,
  });
}

/// Offline anomaly detection via a per-category z-score on expense amounts.
///
/// Pure/stateless. Only flags expenses that are ABOVE the mean (an unusually
/// cheap expense is not interesting), and only for categories with enough
/// history to make the statistic meaningful.
class AnomalyEngine {
  /// Minimum number of prior expenses in a category before we judge anomalies.
  static const int minSamples = 6;

  /// z-score at or above which an expense is flagged.
  static const double zThreshold = 2.0;

  /// Returns anomalies among [transactions] (typically a recent window),
  /// judged against the full [history] of the same categories.
  ///
  /// [transactions] is the set to evaluate (e.g. this month's expenses);
  /// [history] is the full population used to compute each category's baseline
  /// (it may include [transactions]; the evaluated tx is excluded from its own
  /// baseline).
  static List<SpendingAnomaly> detect({
    required List<Transaction> transactions,
    required List<Transaction> history,
  }) {
    // Group expense history by category.
    final byCategory = <int, List<double>>{};
    for (final t in history) {
      if (t.type != 'expense' || t.categoryId == null) continue;
      byCategory.putIfAbsent(t.categoryId!, () => []).add(t.amount);
    }

    final anomalies = <SpendingAnomaly>[];
    for (final tx in transactions) {
      if (tx.type != 'expense' || tx.categoryId == null) continue;
      final all = byCategory[tx.categoryId!];
      if (all == null) continue;

      // Baseline excludes the transaction under evaluation.
      final baseline = List<double>.from(all)..remove(tx.amount);
      if (baseline.length < minSamples) continue;

      final mean = _mean(baseline);
      final sd = _stdDev(baseline, mean);
      if (sd <= 0) continue; // perfectly uniform history → nothing to flag
      if (tx.amount <= mean) continue; // only above-average spend

      final z = (tx.amount - mean) / sd;
      if (z >= zThreshold) {
        anomalies.add(SpendingAnomaly(
          transaction: tx,
          zScore: z,
          categoryMean: mean,
          timesTypical: mean > 0 ? tx.amount / mean : 0,
        ));
      }
    }

    // Most extreme first.
    anomalies.sort((a, b) => b.zScore.compareTo(a.zScore));
    return anomalies;
  }

  static double _mean(List<double> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  static double _stdDev(List<double> xs, double mean) {
    if (xs.length < 2) return 0;
    final variance =
        xs.map((x) => pow(x - mean, 2).toDouble()).reduce((a, b) => a + b) /
            (xs.length - 1);
    return sqrt(variance);
  }
}
