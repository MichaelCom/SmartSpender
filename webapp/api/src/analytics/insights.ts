import { Budget, RecurringTransaction, Transaction } from "../types/models";
import { detectAnomalies } from "./anomaly";
import { forecastBudget } from "./forecast";

// Ported from lib/services/insights/insights_engine.dart (parity).

export type InsightKind = "info" | "positive" | "warning";

/** A single templated, human-readable insight. */
export interface Insight {
  kind: InsightKind;
  title: string;
  detail: string;
  /** Higher = more important. Used to pick the single highlight insight. */
  priority: number;
}

function sum(txs: Transaction[], type: string): number {
  return txs.filter((t) => t.type === type).reduce((s, t) => s + t.amount, 0);
}

function expensesByCategoryName(txs: Transaction[]): Map<string, number> {
  const map = new Map<string, number>();
  for (const t of txs) {
    if (t.type !== "expense") continue;
    const name = t.categoryName ?? "Uncategorised";
    map.set(name, (map.get(name) ?? 0) + t.amount);
  }
  return map;
}

// Dart's num.round(): rounds half away from zero.
function dartRound(v: number): number {
  return v < 0 ? -Math.round(-v) : Math.round(v);
}

function money(currencySymbol: string, v: number): string {
  return `${currencySymbol}${v.toFixed(2)}`;
}

/**
 * Builds all applicable insights for the month containing [now]. Pure given the
 * supplied data; the route layer loads transactions/recurring/budgets and
 * injects them (the Dart version pulls from repositories).
 *
 * [allTransactions] must carry categoryName for category grouping (JOINed).
 */
export function buildInsights(params: {
  allTransactions: Transaction[];
  recurring: RecurringTransaction[];
  budgets: Budget[];
  now?: Date;
  currencySymbol?: string;
}): Insight[] {
  const {
    allTransactions,
    recurring,
    budgets,
    now,
    currencySymbol = "R",
  } = params;

  const today = now ?? new Date();
  const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
  const monthEnd = new Date(
    today.getFullYear(),
    today.getMonth() + 1,
    0,
    23,
    59,
    59
  );
  const prevStart = new Date(today.getFullYear(), today.getMonth() - 1, 1);
  const prevEnd = new Date(today.getFullYear(), today.getMonth(), 0, 23, 59, 59);

  const notBefore = (d: Date, bound: Date) => d.getTime() >= bound.getTime();
  const notAfter = (d: Date, bound: Date) => d.getTime() <= bound.getTime();

  const thisMonth = allTransactions.filter(
    (t) => notBefore(t.date, monthStart) && notAfter(t.date, monthEnd)
  );
  const lastMonth = allTransactions.filter(
    (t) => notBefore(t.date, prevStart) && notAfter(t.date, prevEnd)
  );

  const insights: Insight[] = [];

  // --- Savings rate (this month) ---
  const income = sum(thisMonth, "income");
  const expenses = sum(thisMonth, "expense");
  if (income > 0) {
    const rate = dartRound(((income - expenses) / income) * 100);
    if (rate >= 0) {
      insights.push({
        kind: rate >= 20 ? "positive" : "info",
        title: "Savings rate",
        detail: `You saved ${rate}% of your income this month.`,
        priority: rate >= 20 ? 50 : 30,
      });
    } else {
      insights.push({
        kind: "warning",
        title: "Spending exceeds income",
        detail: `You spent ${money(
          currencySymbol,
          expenses - income
        )} more than you earned this month.`,
        priority: 80,
      });
    }
  }

  // --- Biggest category (this month) ---
  const byCat = expensesByCategoryName(thisMonth);
  if (byCat.size > 0 && expenses > 0) {
    // reduce((a,b) => a.value >= b.value ? a : b): ties keep first-seen.
    let top: { key: string; value: number } | null = null;
    for (const [key, value] of byCat) {
      if (top == null) top = { key, value };
      else if (!(top.value >= value)) top = { key, value };
    }
    if (top != null) {
      const pct = dartRound((top.value / expenses) * 100);
      insights.push({
        kind: "info",
        title: "Biggest expense category",
        detail: `${top.key} was your largest expense this month (${money(
          currencySymbol,
          top.value
        )}, ${pct}% of spending).`,
        priority: 40,
      });
    }
  }

  // --- Top mover (month-over-month category change) ---
  if (lastMonth.length > 0) {
    const thisByCat = expensesByCategoryName(thisMonth);
    const lastByCat = expensesByCategoryName(lastMonth);
    let moverName: string | null = null;
    let moverDelta = 0;
    const names = new Set<string>([...thisByCat.keys(), ...lastByCat.keys()]);
    for (const name of names) {
      const delta = (thisByCat.get(name) ?? 0) - (lastByCat.get(name) ?? 0);
      if (Math.abs(delta) > Math.abs(moverDelta)) {
        moverDelta = delta;
        moverName = name;
      }
    }
    if (moverName != null && Math.abs(moverDelta) >= 1) {
      const up = moverDelta > 0;
      const lastVal = lastByCat.get(moverName) ?? 0;
      const pct =
        lastVal > 0 ? dartRound((Math.abs(moverDelta) / lastVal) * 100) : null;
      insights.push({
        kind: up ? "warning" : "positive",
        title: "Biggest change vs last month",
        detail: `${moverName} ${up ? "rose" : "fell"} by ${money(
          currencySymbol,
          Math.abs(moverDelta)
        )}${pct != null ? ` (${pct}%)` : ""} compared to last month.`,
        priority: 45,
      });
    }
  }

  // --- Anomaly roll-up (this month) ---
  const anomalies = detectAnomalies({
    transactions: thisMonth.filter((t) => t.type === "expense"),
    history: allTransactions,
  });
  if (anomalies.length > 0) {
    insights.push({
      kind: "warning",
      title: "Unusual spending",
      detail:
        anomalies.length === 1
          ? "1 unusually large expense was flagged this month."
          : `${anomalies.length} unusually large expenses were flagged this month.`,
      priority: 60,
    });
  }

  // --- Forecast roll-up (budgets projected to exceed) ---
  const oneDay = 24 * 60 * 60 * 1000;
  const activeBudgets = budgets.filter((b) => {
    return (
      b.startDate.getTime() < today.getTime() + oneDay &&
      b.endDate.getTime() > today.getTime() - oneDay
    );
  });
  let projectedExceed = 0;
  for (const b of activeBudgets) {
    const f = forecastBudget({
      budget: b,
      monthTransactions: thisMonth,
      recurring,
      now: today,
    });
    if (f.projectedToExceed) projectedExceed++;
  }
  if (projectedExceed > 0) {
    insights.push({
      kind: "warning",
      title: "Budget forecast",
      detail:
        projectedExceed === 1
          ? "You're on track to exceed 1 budget this month."
          : `You're on track to exceed ${projectedExceed} budgets this month.`,
      priority: 70,
    });
  }

  // Most important first.
  insights.sort((a, b) => b.priority - a.priority);
  return insights;
}

/** The single most important insight, or null. */
export function topInsight(params: {
  allTransactions: Transaction[];
  recurring: RecurringTransaction[];
  budgets: Budget[];
  now?: Date;
  currencySymbol?: string;
}): Insight | null {
  const all = buildInsights(params);
  return all.length === 0 ? null : all[0];
}
