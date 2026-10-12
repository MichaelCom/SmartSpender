import { describe, expect, it } from "vitest";
import { suggestCategory } from "../src/analytics/categorization";
import { Category, Transaction, TxType } from "../src/types/models";

// Mirrors test/services/insights/categorization_engine_test.dart.

function cat(id: number, name: string, type: TxType = "expense"): Category {
  return { id, name, type, createdAt: new Date(2024, 0, 1), color: null, icon: null };
}

function tx(
  desc: string,
  categoryId: number | null,
  type: TxType = "expense"
): Transaction {
  return {
    id: Math.floor(Math.random() * 1e9),
    amount: 10,
    description: desc,
    categoryId,
    date: new Date(2024, 5, 1),
    type,
    createdAt: new Date(2024, 5, 1),
    recurringId: null,
  };
}

const categories = [
  cat(1, "Transportation"),
  cat(2, "Food & Dining"),
  cat(3, "Entertainment"),
  cat(10, "Salary", "income"),
];

describe("seed rules", () => {
  it("maps a known keyword to the matching category", () => {
    const s = suggestCategory({
      description: "Uber trip home",
      categories,
      history: [],
    });
    expect(s).not.toBeNull();
    expect(s!.categoryId).toBe(1);
    expect(s!.fromHistory).toBe(false);
  });

  it("longer keyword wins (uber eats -> Food, not Transport)", () => {
    const s = suggestCategory({
      description: "Uber Eats dinner",
      categories,
      history: [],
    });
    expect(s!.categoryId).toBe(2);
  });

  it("returns null when no keyword and no history match", () => {
    const s = suggestCategory({
      description: "xyzzy nothing here",
      categories,
      history: [],
    });
    expect(s).toBeNull();
  });

  it("skips a seed rule when no matching category exists", () => {
    const s = suggestCategory({
      description: "netflix subscription",
      categories: [cat(1, "Transportation")],
      history: [],
    });
    expect(s).toBeNull();
  });

  it("empty description yields null", () => {
    const s = suggestCategory({
      description: "   ",
      categories,
      history: [],
    });
    expect(s).toBeNull();
  });
});

describe("history learning", () => {
  it("history overrides seed rules once confident", () => {
    const history = [tx("uber ride", 3), tx("uber ride", 3)];
    const s = suggestCategory({
      description: "uber ride again",
      categories,
      history,
    });
    expect(s!.categoryId).toBe(3);
    expect(s!.fromHistory).toBe(true);
  });

  it("below the min-match threshold falls back to seed rule", () => {
    const history = [tx("uber ride", 3)];
    const s = suggestCategory({
      description: "uber ride",
      categories,
      history,
    });
    expect(s!.categoryId).toBe(1);
    expect(s!.fromHistory).toBe(false);
  });

  it("type filter restricts suggestions to that type", () => {
    const s = suggestCategory({
      description: "salary payment",
      categories,
      history: [],
      type: "income",
    });
    expect(s!.categoryId).toBe(10);

    const s2 = suggestCategory({
      description: "salary payment",
      categories,
      history: [],
      type: "expense",
    });
    expect(s2).toBeNull();
  });

  it("ignores history pointing at a deleted/unknown category", () => {
    const history = [tx("coffee shop", 999), tx("coffee shop", 999)];
    const s = suggestCategory({
      description: "coffee shop morning",
      categories,
      history,
    });
    expect(s!.categoryId).toBe(2);
    expect(s!.fromHistory).toBe(false);
  });
});
