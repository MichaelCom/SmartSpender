/**
 * Direct TypeScript port of lib/utils/currency.dart — EXACT same symbols and
 * formatting as the mobile app. NO FX conversion is ever performed; changing
 * currency only relabels the symbol.
 */

/** A single selectable currency, used by the settings picker and formatters. */
export interface CurrencyOption {
  /** e.g. 'ZAR' */
  readonly code: string;
  /** e.g. 'R' */
  readonly symbol: string;
  /** e.g. 'South African Rand' */
  readonly name: string;
}

/**
 * Curated, fixed list of supported currencies plus lookup helpers.
 *
 * ZAR is first and is the app default. The list intentionally only carries a
 * display symbol — changing currency relabels the symbol and does NOT perform
 * any FX conversion of stored amounts.
 */
export const AppCurrencies = {
  /** Curated list of supported currencies. ZAR MUST remain first (default). */
  all: [
    { code: "ZAR", symbol: "R", name: "South African Rand" },
    { code: "USD", symbol: "$", name: "US Dollar" },
    { code: "EUR", symbol: "€", name: "Euro" },
    { code: "GBP", symbol: "£", name: "British Pound" },
    { code: "AUD", symbol: "A$", name: "Australian Dollar" },
    { code: "CAD", symbol: "C$", name: "Canadian Dollar" },
    { code: "JPY", symbol: "¥", name: "Japanese Yen" },
    { code: "INR", symbol: "₹", name: "Indian Rupee" },
  ] as const satisfies readonly CurrencyOption[],

  /** Returns the symbol for `code`, or `code` itself when unknown. */
  symbolFor(code: string): string {
    const option = AppCurrencies.byCode(code);
    return option?.symbol ?? code;
  },

  /** Returns the matching CurrencyOption, or null when `code` is unknown. */
  byCode(code: string): CurrencyOption | null {
    for (const option of AppCurrencies.all) {
      if (option.code === code) return option;
    }
    return null;
  },
};

/** Grouped number formatting mirroring Dart's `NumberFormat('#,##0.00')`. */
function grouped(amount: number): string {
  return amount.toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

/** Grouped integer formatting mirroring Dart's `NumberFormat('#,##0')`. */
function groupedWhole(amount: number): string {
  return amount.toLocaleString("en-US", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  });
}

/** Formats a scaled compact value, dropping a trailing `.0`. */
function trim(value: number): string {
  const rounded = Math.round(value * 10) / 10;
  if (rounded === Math.round(rounded)) {
    return rounded.toFixed(0);
  }
  return rounded.toFixed(1);
}

/**
 * Pure formatting helper. Has NO dependency on settings state — callers obtain
 * the symbol and pass it in.
 */
export const CurrencyFormatter = {
  /**
   * Formats a non-signed amount with grouping + 2 decimals, prefixed by
   * `symbol`. A negative amount keeps a leading `-` before the symbol; a
   * positive amount is rendered without a sign.
   *
   * `format('R', 1234.5)`  => `'R1,234.50'`
   * `format('R', -1234.5)` => `'-R1,234.50'`
   */
  format(symbol: string, amount: number): string {
    const sign = amount < 0 ? "-" : "";
    return `${sign}${symbol}${grouped(Math.abs(amount))}`;
  },

  /**
   * Signed variant for income(+)/expense(-) display. The magnitude of `amount`
   * is formatted and prefixed with the sign + symbol.
   *
   * `formatSigned('R', 1234.5, true)`  => `'+R1,234.50'`
   * `formatSigned('R', 1234.5, false)` => `'-R1,234.50'`
   */
  formatSigned(symbol: string, amount: number, isIncome: boolean): string {
    const sign = isIncome ? "+" : "-";
    return `${sign}${symbol}${grouped(Math.abs(amount))}`;
  },

  /**
   * Compact form for chart axis labels.
   *
   * `formatCompact('R', 12000)` => `'R12k'`
   * `formatCompact('R', 1500000)` => `'R1.5M'`
   */
  formatCompact(symbol: string, amount: number): string {
    const value = Math.abs(amount);
    const sign = amount < 0 ? "-" : "";

    if (value >= 1000000000) {
      return `${sign}${symbol}${trim(value / 1000000000)}B`;
    }
    if (value >= 1000000) {
      return `${sign}${symbol}${trim(value / 1000000)}M`;
    }
    if (value >= 1000) {
      return `${sign}${symbol}${trim(value / 1000)}k`;
    }
    return `${sign}${symbol}${groupedWhole(value)}`;
  },
};
