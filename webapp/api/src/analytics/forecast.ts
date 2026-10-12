import { Budget, RecurringTransaction, Transaction, TxType } from "../types/models";
import { advanceRule, dateOnly, isAfter, isBefore } from "./recurring";

// Ported from lib/services/insights/forecast_engine.dart (behavioural parity).

/** Projected end-of-month spend for a single category/budget. */
export interface BudgetForecast {
  budget: Budget;
  spentSoFar: number;
  /** Recurring expenses for this category still due before month end. */
  remainingRecurring: number;
  /** Projected discretionary (non-recurring) spend for the rest of the month. */
  projectedDiscretionary: number;
  /** spentSoFar + remainingRecurring + projectedDiscretionary. */
  projectedTotal: number;
  projectedToExceed: boolean;
  projectedOverBy: number;
}

/** Projected totals for the whole current month. */
export interface MonthForecast {
  incomeSoFar: number;
  expensesSoFar: number;
  projectedIncome: number;
  projectedExpenses: number;
  projectedNet: number;
}

/**
 * Counts occurrences of rule [r] strictly AFTER [from] through [monthEnd]
 * (inclusive), bounded by the rule's own start/end dates.
 * Mirrors ForecastEngine._occurrencesInRange.
 */
function occurrencesInRange(
  r: RecurringTransaction,
  from: Date,
  monthEnd: Date
): number {
  const start = dateOnly(r.startDate);
  const hardEnd = r.endDate == null ? monthEnd : dateOnly(r.endDate);
  const upper = isBefore(hardEnd, monthEnd) ? hardEnd : monthEnd;

  // First occurrence strictly after `from`.
  let occ = start;
  let guard = 0;
  while (!isAfter(occ, from) && guard < 100000) {
    occ = dateOnly(advanceRule(r, occ));
    guard++;
  }

  let count = 0;
  while (!isAfter(occ, upper) && guard < 100000) {
    if (!isBefore(occ, start)) count++;
    occ = dateOnly(advanceRule(r, occ));
    guard++;
  }
  return count;
}

function remainingRecurringForCategory(params: {
  recurring: RecurringTransaction[];
  categoryId: number;
  from: Date;
  monthEnd: Date;
}): number {
  const { recurring, categoryId, from, monthEnd } = params;
  let sum = 0;
  for (const r of recurring) {
    if (r.type !== "expense" || r.categoryId !== categoryId) continue;
    sum += occurrencesInRange(r, from, monthEnd) * r.amount;
  }
  return sum;
}

function remainingRecurring(
  recurring: RecurringTransaction[],
  type: TxType,
  from: Date,
  monthEnd: Date
): number {
  let sum = 0;
  for (const r of recurring) {
    if (r.type !== type) continue;
    sum += occurrencesInRange(r, from, monthEnd) * r.amount;
  }
  return sum;
}

/** Projects end-of-month spend for [budget]. */
export function forecastBudget(params: {
  budget: Budget;
  monthTransactions: Transaction[];
  recurring: RecurringTransaction[];
  now?: Date;
}): BudgetForecast {
  const { budget, monthTransactions, recurring } = params;
  const today = dateOnly(params.now ?? new Date());
  // DateTime(year, month+1, 0) => last day of current month.
  const monthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);
  const daysInMonth = monthEnd.getDate();
  const daysElapsed = today.getDate();

  const catTx = monthTransactions.filter(
    (t) => t.type === "expense" && t.categoryId === budget.categoryId
  );

  const spentSoFar = catTx.reduce((s, t) => s + t.amount, 0);
  const discretionarySoFar = catTx
    .filter((t) => t.recurringId == null)
    .reduce((s, t) => s + t.amount, 0);

  const remRecurring = remainingRecurringForCategory({
    recurring,
    categoryId: budget.categoryId,
    from: today,
    monthEnd,
  });

  const daysRemaining = daysInMonth - daysElapsed;
  const dailyDiscretionary =
    daysElapsed > 0 ? discretionarySoFar / daysElapsed : 0.0;
  const projectedDiscretionary = dailyDiscretionary * daysRemaining;

  const projectedTotal = spentSoFar + remRecurring + projectedDiscretionary;
  const projectedToExceed = projectedTotal > budget.amount;

  return {
    budget,
    spentSoFar,
    remainingRecurring: remRecurring,
    projectedDiscretionary,
    projectedTotal,
    projectedToExceed,
    projectedOverBy: projectedToExceed ? projectedTotal - budget.amount : 0,
  };
}

/** Projects whole-month income and expense totals. */
export function forecastMonth(params: {
  monthTransactions: Transaction[];
  recurring: RecurringTransaction[];
  now?: Date;
}): MonthForecast {
  const { monthTransactions, recurring } = params;
  const today = dateOnly(params.now ?? new Date());
  const monthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);
  const daysInMonth = monthEnd.getDate();
  const daysElapsed = today.getDate();
  const daysRemaining = daysInMonth - daysElapsed;

  const soFar = (
    type: TxType,
    opts: { recurringOnly?: boolean; discretionary?: boolean } = {}
  ): number => {
    const { recurringOnly = false, discretionary = false } = opts;
    return monthTransactions
      .filter(
        (t) =>
          t.type === type &&
          (!discretionary || t.recurringId == null) &&
          (!recurringOnly || t.recurringId != null)
      )
      .reduce((s, t) => s + t.amount, 0);
  };

  const incomeSoFar = soFar("income");
  const expensesSoFar = soFar("expense");

  const incomeDiscretionary = soFar("income", { discretionary: true });
  const expenseDiscretionary = soFar("expense", { discretionary: true });

  const remainingRecurringIncome = remainingRecurring(
    recurring,
    "income",
    today,
    monthEnd
  );
  const remainingRecurringExpense = remainingRecurring(
    recurring,
    "expense",
    today,
    monthEnd
  );

  const project = (discretionarySoFar: number): number =>
    daysElapsed > 0 ? (discretionarySoFar / daysElapsed) * daysRemaining : 0.0;

  const projectedIncome =
    incomeSoFar + remainingRecurringIncome + project(incomeDiscretionary);
  const projectedExpenses =
    expensesSoFar + remainingRecurringExpense + project(expenseDiscretionary);

  return {
    incomeSoFar,
    expensesSoFar,
    projectedIncome,
    projectedExpenses,
    projectedNet: projectedIncome - projectedExpenses,
  };
}
