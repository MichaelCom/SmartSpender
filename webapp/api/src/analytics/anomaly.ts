import { Transaction } from "../types/models";

// Ported from lib/services/insights/anomaly_engine.dart (behavioural parity).

/** An expense flagged as unusually large for its category. */
export interface SpendingAnomaly {
  transaction: Transaction;
  /** How many standard deviations above the category mean. */
  zScore: number;
  /** The category's historical mean expense amount (excluding this tx). */
  categoryMean: number;
  /** Human-readable multiple, e.g. 3 for "~3x your usual". */
  timesTypical: number;
}

/** Minimum number of prior expenses in a category before we judge anomalies. */
export const MIN_SAMPLES = 6;
/** z-score at or above which an expense is flagged. */
export const Z_THRESHOLD = 2.0;

function mean(xs: number[]): number {
  return xs.length === 0 ? 0 : xs.reduce((a, b) => a + b, 0) / xs.length;
}

function stdDev(xs: number[], m: number): number {
  if (xs.length < 2) return 0;
  const variance =
    xs.map((x) => (x - m) ** 2).reduce((a, b) => a + b, 0) / (xs.length - 1);
  return Math.sqrt(variance);
}

/**
 * Returns anomalies among [transactions] (typically a recent window), judged
 * against the full [history] of the same categories. The evaluated tx is
 * excluded from its own baseline. Only flags above-mean expenses in categories
 * with enough history.
 */
export function detectAnomalies(params: {
  transactions: Transaction[];
  history: Transaction[];
}): SpendingAnomaly[] {
  const { transactions, history } = params;

  // Group expense history by category.
  const byCategory = new Map<number, number[]>();
  for (const t of history) {
    if (t.type !== "expense" || t.categoryId == null) continue;
    const list = byCategory.get(t.categoryId) ?? [];
    list.push(t.amount);
    byCategory.set(t.categoryId, list);
  }

  const anomalies: SpendingAnomaly[] = [];
  for (const tx of transactions) {
    if (tx.type !== "expense" || tx.categoryId == null) continue;
    const all = byCategory.get(tx.categoryId);
    if (all == null) continue;

    // Baseline excludes the transaction under evaluation.
    // Dart's List.remove removes the FIRST matching element only.
    const baseline = [...all];
    const idx = baseline.indexOf(tx.amount);
    if (idx !== -1) baseline.splice(idx, 1);
    if (baseline.length < MIN_SAMPLES) continue;

    const m = mean(baseline);
    const sd = stdDev(baseline, m);
    if (sd <= 0) continue; // perfectly uniform history -> nothing to flag
    if (tx.amount <= m) continue; // only above-average spend

    const z = (tx.amount - m) / sd;
    if (z >= Z_THRESHOLD) {
      anomalies.push({
        transaction: tx,
        zScore: z,
        categoryMean: m,
        timesTypical: m > 0 ? tx.amount / m : 0,
      });
    }
  }

  // Most extreme first.
  anomalies.sort((a, b) => b.zScore - a.zScore);
  return anomalies;
}
