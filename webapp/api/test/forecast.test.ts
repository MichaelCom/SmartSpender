import { describe, expect, it } from "vitest";
import { forecastBudget, forecastMonth } from "../src/analytics/forecast";
import {
  Budget,
  RecurringTransaction,
  Transaction,
  TxType,
} from "../src/types/models";

// Mirrors test/services/insights/forecast_engine_test.dart.

function budget(categoryId: number, amount: number): Budget {
  return {
    id: 1,
    categoryId,
    amount,
    period: "monthly",
    startDate: new Date(2024, 5, 1),
    endDate: new Date(2024, 5, 30),
    createdAt: new Date(2024, 5, 1),
  };
}

function tx(
  amount: number,
  date: Date,
  opts: { categoryId?: number; type?: TxType; recurringId?: number | null } = {}
): Transaction {
  const { categoryId = 1, type = "expense", recurringId = null } = opts;
  return {
    id: Math.floor(Math.random() * 1e9),
    amount,
    description: "tx",
    categoryId,
    date,
    type,
    createdAt: date,
    recurringId,
  };
}

// "today" is June 10 (10 of 30 days elapsed, 20 remaining).
const now = new Date(2024, 5, 10);

describe("forecastBudget", () => {
  it("simple run-rate on discretionary spend", () => {
    const txs = [tx(500, new Date(2024, 5, 5))];
    const f = forecastBudget({
      budget: budget(1, 2000),
      monthTransactions: txs,
      recurring: [],
      now,
    });
    expect(f.spentSoFar).toBe(500);
    expect(f.projectedDiscretionary).toBeCloseTo(1000, 3);
    expect(f.projectedTotal).toBeCloseTo(1500, 3);
    expect(f.projectedToExceed).toBe(false);
  });

  it("recurring spend is counted exactly, not run-rated", () => {
    const txs = [tx(500, new Date(2024, 5, 1), { recurringId: 7 })];
    const rule: RecurringTransaction = {
      id: 7,
      amount: 500,
      categoryId: 1,
      type: "expense",
      frequency: "monthly",
      startDate: new Date(2024, 5, 1),
      createdAt: new Date(2024, 5, 1),
      description: null,
      endDate: null,
      lastGeneratedDate: null,
    };
    const f = forecastBudget({
      budget: budget(1, 2000),
      monthTransactions: txs,
      recurring: [rule],
      now,
    });
    expect(f.projectedDiscretionary).toBe(0);
    expect(f.remainingRecurring).toBe(0);
    expect(f.projectedTotal).toBeCloseTo(500, 3);
  });

  it("adds remaining recurring occurrences before month end", () => {
    // Weekly R100 from June 1: occurrences 1,8,15,22,29. today=June 10 ->
    // remaining: 15,22,29 = 300.
    const rule: RecurringTransaction = {
      id: 7,
      amount: 100,
      categoryId: 1,
      type: "expense",
      frequency: "weekly",
      startDate: new Date(2024, 5, 1),
      createdAt: new Date(2024, 5, 1),
      description: null,
      endDate: null,
      lastGeneratedDate: null,
    };
    const f = forecastBudget({
      budget: budget(1, 1000),
      monthTransactions: [],
      recurring: [rule],
      now,
    });
    expect(f.remainingRecurring).toBeCloseTo(300, 3);
  });

  it("flags projected overspend", () => {
    const txs = [tx(900, new Date(2024, 5, 5))];
    const f = forecastBudget({
      budget: budget(1, 2000),
      monthTransactions: txs,
      recurring: [],
      now,
    });
    expect(f.projectedToExceed).toBe(true);
    expect(f.projectedOverBy).toBeGreaterThan(0);
  });
});

describe("forecastMonth", () => {
  it("projects income and expenses with run-rate", () => {
    const txs = [
      tx(1000, new Date(2024, 5, 2), { type: "income" }),
      tx(300, new Date(2024, 5, 3), { type: "expense" }),
    ];
    const f = forecastMonth({ monthTransactions: txs, recurring: [], now });
    expect(f.incomeSoFar).toBe(1000);
    expect(f.expensesSoFar).toBe(300);
    expect(f.projectedIncome).toBeCloseTo(3000, 3);
    expect(f.projectedExpenses).toBeCloseTo(900, 3);
    expect(f.projectedNet).toBeCloseTo(2100, 3);
  });
});
