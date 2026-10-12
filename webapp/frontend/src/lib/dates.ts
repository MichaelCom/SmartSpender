/** Date/time helpers for the current month window and display formatting. */

/** ISO string for the first instant of the current month (local). */
export function monthStart(now = new Date()): Date {
  return new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
}

/** Date for the last instant of the current month (local). */
export function monthEnd(now = new Date()): Date {
  return new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
}

export function toIso(d: Date): string {
  return d.toISOString();
}

/** Number of days elapsed in the current month (1-based, i.e. the day number). */
export function daysElapsedInMonth(now = new Date()): number {
  return now.getDate();
}

/** YYYY-MM-DD for a date input value (local). */
export function toDateInput(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

/** Parse a YYYY-MM-DD date input into a local Date at midnight. */
export function fromDateInput(value: string): Date {
  const [y, m, d] = value.split("-").map(Number);
  return new Date(y, (m ?? 1) - 1, d ?? 1);
}

const DATE_FMT = new Intl.DateTimeFormat(undefined, {
  year: "numeric",
  month: "short",
  day: "numeric",
});

export function formatDate(iso: string): string {
  return DATE_FMT.format(new Date(iso));
}

const MONTH_FMT = new Intl.DateTimeFormat(undefined, {
  year: "numeric",
  month: "long",
});

export function formatMonth(d: Date): string {
  return MONTH_FMT.format(d);
}
