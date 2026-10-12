import { describe, expect, it } from "vitest";
import { AppCurrencies, CurrencyFormatter } from "../lib/currency";

/**
 * These mirror the dartdoc examples in lib/utils/currency.dart to guarantee
 * EXACT formatting parity with the mobile app.
 */
describe("AppCurrencies", () => {
  it("has ZAR first as the default", () => {
    expect(AppCurrencies.all[0].code).toBe("ZAR");
    expect(AppCurrencies.all[0].symbol).toBe("R");
  });

  it("resolves symbols and falls back to the code", () => {
    expect(AppCurrencies.symbolFor("USD")).toBe("$");
    expect(AppCurrencies.symbolFor("EUR")).toBe("€");
    expect(AppCurrencies.symbolFor("JPY")).toBe("¥");
    expect(AppCurrencies.symbolFor("XXX")).toBe("XXX");
  });

  it("byCode returns null for unknown", () => {
    expect(AppCurrencies.byCode("ZZZ")).toBeNull();
    expect(AppCurrencies.byCode("GBP")?.symbol).toBe("£");
  });

  it("carries all 8 curated currencies", () => {
    expect(AppCurrencies.all.map((c) => c.code)).toEqual([
      "ZAR", "USD", "EUR", "GBP", "AUD", "CAD", "JPY", "INR",
    ]);
  });
});

describe("CurrencyFormatter.format", () => {
  it("formats positive without a sign", () => {
    expect(CurrencyFormatter.format("R", 1234.5)).toBe("R1,234.50");
  });
  it("keeps a leading minus before the symbol", () => {
    expect(CurrencyFormatter.format("R", -1234.5)).toBe("-R1,234.50");
  });
  it("always shows two decimals", () => {
    expect(CurrencyFormatter.format("$", 0)).toBe("$0.00");
    expect(CurrencyFormatter.format("$", 5)).toBe("$5.00");
  });
});

describe("CurrencyFormatter.formatSigned", () => {
  it("prefixes + for income", () => {
    expect(CurrencyFormatter.formatSigned("R", 1234.5, true)).toBe("+R1,234.50");
  });
  it("prefixes - for expense", () => {
    expect(CurrencyFormatter.formatSigned("R", 1234.5, false)).toBe("-R1,234.50");
  });
});

describe("CurrencyFormatter.formatCompact", () => {
  it("formats thousands with k", () => {
    expect(CurrencyFormatter.formatCompact("R", 12000)).toBe("R12k");
  });
  it("formats millions with M and one decimal", () => {
    expect(CurrencyFormatter.formatCompact("R", 1500000)).toBe("R1.5M");
  });
  it("drops a trailing .0", () => {
    expect(CurrencyFormatter.formatCompact("R", 2000000)).toBe("R2M");
  });
  it("formats billions with B", () => {
    expect(CurrencyFormatter.formatCompact("R", 3000000000)).toBe("R3B");
  });
  it("formats sub-thousand as a whole grouped number", () => {
    expect(CurrencyFormatter.formatCompact("R", 999)).toBe("R999");
  });
  it("keeps the sign for negatives", () => {
    expect(CurrencyFormatter.formatCompact("R", -12000)).toBe("-R12k");
  });
});
