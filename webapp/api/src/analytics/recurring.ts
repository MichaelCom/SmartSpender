import { Frequency, RecurringTransaction } from "../types/models";

// Date-only (year/month/day at local midnight), mirroring Dart's
// `DateTime(d.year, d.month, d.day)`.
export function dateOnly(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

// Advances [d] by one period of [frequency], mirroring
// RecurringTransaction.advance in lib/models/recurring_transaction.dart.
// Monthly/yearly use Date-component arithmetic (JS Date normalises overflow
// the same way Dart's DateTime does, e.g. Jan 31 + 1 month -> Mar 3).
export function advance(frequency: Frequency, d: Date): Date {
  switch (frequency) {
    case "daily":
      return new Date(d.getTime() + 24 * 60 * 60 * 1000);
    case "weekly":
      return new Date(d.getTime() + 7 * 24 * 60 * 60 * 1000);
    case "monthly":
      return new Date(
        d.getFullYear(),
        d.getMonth() + 1,
        d.getDate(),
        d.getHours(),
        d.getMinutes(),
        d.getSeconds(),
        d.getMilliseconds()
      );
    case "yearly":
      return new Date(
        d.getFullYear() + 1,
        d.getMonth(),
        d.getDate(),
        d.getHours(),
        d.getMinutes(),
        d.getSeconds(),
        d.getMilliseconds()
      );
    default:
      return new Date(d.getTime() + 24 * 60 * 60 * 1000);
  }
}

export function isAfter(a: Date, b: Date): boolean {
  return a.getTime() > b.getTime();
}

export function isBefore(a: Date, b: Date): boolean {
  return a.getTime() < b.getTime();
}

// Mirrors advance() for a rule instance.
export function advanceRule(r: RecurringTransaction, d: Date): Date {
  return advance(r.frequency, d);
}
