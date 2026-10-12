import { describe, expect, it } from "vitest";
import { detectAnomalies } from "../src/analytics/anomaly";
import { Transaction } from "../src/types/models";

// Mirrors test/services/insights/anomaly_engine_test.dart.

function tx(
  amount: number,
  opts: { categoryId?: number; type?: "income" | "expense" } = {}
): Transaction {
  const { categoryId = 1, type = "expense" } = opts;
  return {
    id: Math.floor(Math.random() * 1e9),
    amount,
    description: "tx",
    categoryId,
    date: new Date(2024, 5, 1),
    type,
    createdAt: new Date(2024, 5, 1),
    recurringId: null,
  };
}

describe("AnomalyEngine", () => {
  it("flags an expense well above the category mean", () => {
    const history = [100, 110, 90, 105, 95, 100, 102].map((a) => tx(a));
    const outlier = tx(1000);
    const result = detectAnomalies({
      transactions: [outlier],
      history: [...history, outlier],
    });
    expect(result).toHaveLength(1);
    expect(result[0].transaction.amount).toBe(1000);
    expect(result[0].zScore).toBeGreaterThan(2.0);
    expect(result[0].timesTypical).toBeGreaterThan(5);
  });

  it("does not flag when below the minimum sample count", () => {
    const history = [100, 110, 90].map((a) => tx(a)); // <6
    const outlier = tx(1000);
    const result = detectAnomalies({
      transactions: [outlier],
      history: [...history, outlier],
    });
    expect(result).toEqual([]);
  });

  it("does not flag below-average spend", () => {
    const history = [100, 110, 90, 105, 95, 100, 102].map((a) => tx(a));
    const low = tx(5);
    const result = detectAnomalies({
      transactions: [low],
      history: [...history, low],
    });
    expect(result).toEqual([]);
  });

  it("does not flag a value within normal variance", () => {
    const history = [100, 110, 90, 105, 95, 100, 102].map((a) => tx(a));
    const normal = tx(107);
    const result = detectAnomalies({
      transactions: [normal],
      history: [...history, normal],
    });
    expect(result).toEqual([]);
  });

  it("judges each category independently", () => {
    const catA = [100, 110, 90, 105, 95, 100].map((a) =>
      tx(a, { categoryId: 1 })
    );
    const catB = [1000, 1100, 900, 1050, 950, 1000].map((a) =>
      tx(a, { categoryId: 2 })
    );
    const txA = tx(500, { categoryId: 1 });
    const txB = tx(500, { categoryId: 2 });
    const result = detectAnomalies({
      transactions: [txA, txB],
      history: [...catA, ...catB, txA, txB],
    });
    const cats = result.map((a) => a.transaction.categoryId);
    expect(cats).toContain(1);
    expect(cats).not.toContain(2);
  });

  it("ignores income transactions", () => {
    const history = [100, 110, 90, 105, 95, 100, 102].map((a) =>
      tx(a, { type: "income" })
    );
    const outlier = tx(1000, { type: "income" });
    const result = detectAnomalies({
      transactions: [outlier],
      history: [...history, outlier],
    });
    expect(result).toEqual([]);
  });

  it("sorts most extreme first", () => {
    const history = [100, 110, 90, 105, 95, 100, 102].map((a) => tx(a));
    const big = tx(1000);
    const bigger = tx(2000);
    const result = detectAnomalies({
      transactions: [big, bigger],
      history: [...history, big, bigger],
    });
    expect(result[0].transaction.amount).toBe(2000);
  });
});
