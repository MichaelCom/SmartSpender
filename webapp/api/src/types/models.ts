// Domain types mirroring the Flutter models (lib/models/*) and the API contract
// (§2). Over the wire these are camelCase JSON; dates are ISO-8601 strings.
// Inside the engines we work with Date objects for correct arithmetic.

export type TxType = "income" | "expense";
export type Frequency = "daily" | "weekly" | "monthly" | "yearly";
export type Period = "weekly" | "monthly" | "yearly";

export interface Category {
  id: number;
  name: string;
  type: TxType;
  color?: string | null;
  icon?: string | null;
  createdAt: Date;
}

export interface Transaction {
  id: number;
  amount: number;
  description?: string | null;
  categoryId?: number | null;
  date: Date;
  type: TxType;
  createdAt: Date;
  recurringId?: number | null;
  // JOINed read-only fields
  categoryName?: string | null;
  categoryIcon?: string | null;
  categoryColor?: string | null;
}

export interface Budget {
  id: number;
  categoryId: number;
  amount: number;
  period: Period;
  startDate: Date;
  endDate: Date;
  createdAt: Date;
  description?: string | null;
  categoryName?: string | null;
  categoryIcon?: string | null;
  categoryColor?: string | null;
}

export interface RecurringTransaction {
  id: number;
  amount: number;
  description?: string | null;
  categoryId?: number | null;
  type: TxType;
  frequency: Frequency;
  startDate: Date;
  endDate?: Date | null;
  lastGeneratedDate?: Date | null;
  createdAt: Date;
  categoryName?: string | null;
  categoryIcon?: string | null;
  categoryColor?: string | null;
}
