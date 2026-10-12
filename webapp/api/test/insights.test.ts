import { describe, expect, it } from "vitest";
import { buildInsights, topInsight } from "../src/analytics/insights";
import { Transaction, TxType } from "../src/types/models";

// Mirrors test/services/insights/insights_engine_test.dart. The Dart test seeds
// a repository; our port is pure, so we build the (JOINed) transactions
// directly. categoryName is required for category grouping (it comes from the
// JOIN in the real loaders).

let nextId = 1;
function tx(params: {
  type: TxType;
  amount: number;
  categoryName: string;
  date: Date;
}): Transaction {
  return {
    id: nextId++,
    amount: params.amount,
    description: "tx",
    categoryId: 1,
    date: params.date,
    type: params.type,
    createdAt: params.date,
    recurringId: null,
    categoryName: params.categoryName,
  };
}

// Fixed "today" mid-month for deterministic run-rate.
const now = new Date(2024, 5, 15);

describe("buildInsights", () => {
  it("empty data produces no insights", () => {
    const insights = buildInsights({
      allTransactions: [],
      recurring: [],
      budgets: [],
      now,
    });
    expect(insights).toEqual([]);
  });

  it("savings-rate insight when income exceeds expenses", () => {
    const insights = buildInsights({
      allTransactions: [
        tx({ type: "income", amount: 1000, categoryName: "Salary", date: new Date(2024, 5, 5) }),
        tx({ type: "expense", amount: 200, categoryName: "Food", date: new Date(2024, 5, 6) }),
      ],
      recurring: [],
      budgets: [],
      now,
    });
    expect(insights.some((i) => i.title === "Savings rate")).toBe(true);
  });

  it("warns when spending exceeds income", () => {
    const insights = buildInsights({
      allTransactions: [
        tx({ type: "income", amount: 200, categoryName: "Salary", date: new Date(2024, 5, 5) }),
        tx({ type: "expense", amount: 500, categoryName: "Food", date: new Date(2024, 5, 6) }),
      ],
      recurring: [],
      budgets: [],
      now,
    });
    expect(insights.some((i) => i.title === "Spending exceeds income")).toBe(true);
  });

  it("biggest-category insight names the top expense category", () => {
    const insights = buildInsights({
      allTransactions: [
        tx({ type: "expense", amount: 800, categoryName: "Food", date: new Date(2024, 5, 5) }),
        tx({ type: "expense", amount: 100, categoryName: "Transport", date: new Date(2024, 5, 6) }),
      ],
      recurring: [],
      budgets: [],
      now,
    });
    const biggest = insights.find((i) => i.title === "Biggest expense category");
    expect(biggest).toBeDefined();
    expect(biggest!.detail).toContain("Food");
  });

  it("top-mover insight compares against last month", () => {
    const insights = buildInsights({
      allTransactions: [
        tx({ type: "expense", amount: 100, categoryName: "Food", date: new Date(2024, 4, 10) }),
        tx({ type: "expense", amount: 400, categoryName: "Food", date: new Date(2024, 5, 10) }),
      ],
      recurring: [],
      budgets: [],
      now,
    });
    const mover = insights.find((i) => i.title === "Biggest change vs last month");
    expect(mover).toBeDefined();
    expect(mover!.detail).toContain("Food");
    expect(mover!.detail.toLowerCase()).toContain("rose");
  });

  it("topInsight returns the highest-priority insight", () => {
    const top = topInsight({
      allTransactions: [
        tx({ type: "income", amount: 100, categoryName: "Salary", date: new Date(2024, 5, 5) }),
        tx({ type: "expense", amount: 900, categoryName: "Food", date: new Date(2024, 5, 6) }),
      ],
      recurring: [],
      budgets: [],
      now,
    });
    expect(top).not.toBeNull();
    expect(top!.title).toBe("Spending exceeds income");
  });

  it("currency symbol is used in amount strings", () => {
    const insights = buildInsights({
      allTransactions: [
        tx({ type: "income", amount: 100, categoryName: "Salary", date: new Date(2024, 5, 5) }),
        tx({ type: "expense", amount: 500, categoryName: "Food", date: new Date(2024, 5, 6) }),
      ],
      recurring: [],
      budgets: [],
      now,
      currencySymbol: "$",
    });
    const overspend = insights.find((i) => i.title === "Spending exceeds income");
    expect(overspend!.detail).toContain("$");
  });
});
