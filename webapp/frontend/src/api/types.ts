/**
 * TypeScript types mirroring the API resource JSON shapes defined in
 * webapp/.fanout/API-CONTRACT.md §2 and the analytics shapes in §4.
 * The frontend talks ONLY to the API; these are the wire contracts.
 */

export type TxType = "income" | "expense";
export type BudgetPeriod = "weekly" | "monthly" | "yearly";
export type Frequency = "daily" | "weekly" | "monthly" | "yearly";

export interface Category {
  id: number;
  name: string;
  type: TxType;
  color?: string | null;
  icon?: string | null;
  createdAt: string;
}

export interface Transaction {
  id: number;
  amount: number;
  description?: string | null;
  categoryId?: number | null;
  date: string;
  type: TxType;
  createdAt: string;
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
  period: BudgetPeriod;
  startDate: string;
  endDate: string;
  createdAt: string;
  description?: string | null;
  // JOINed read-only fields
  categoryName?: string | null;
  categoryIcon?: string | null;
  categoryColor?: string | null;
}

export interface Recurring {
  id: number;
  amount: number;
  description?: string | null;
  categoryId?: number | null;
  type: TxType;
  frequency: Frequency;
  startDate: string;
  endDate?: string | null;
  lastGeneratedDate?: string | null;
  createdAt: string;
}

// ---- Analytics / insights (§4) ----

export interface Summary {
  income: number;
  expenses: number;
  balance: number;
}

/** `{ "<categoryName>": amount, ... }` */
export type ExpensesByCategory = Record<string, number>;

export type InsightKind = "info" | "positive" | "warning";

export interface Insight {
  kind: InsightKind;
  title: string;
  detail: string;
  priority: number;
}

export interface SpendingAnomaly {
  transaction: Transaction;
  zScore: number;
  categoryMean: number;
  timesTypical: number;
}

export interface BudgetForecast {
  budget: Budget;
  spentSoFar: number;
  remainingRecurring: number;
  projectedDiscretionary: number;
  projectedTotal: number;
  projectedToExceed: boolean;
  projectedOverBy: number;
}

export interface MonthForecast {
  incomeSoFar: number;
  expensesSoFar: number;
  projectedIncome: number;
  projectedExpenses: number;
  projectedNet: number;
}

export interface ForecastResponse {
  month: MonthForecast;
  budgets: BudgetForecast[];
}

export interface CategorySuggestion {
  categoryId: number;
  reason: string;
  fromHistory: boolean;
}

// ---- Bridge (§2/§3) ----

export interface ImportResult {
  categoriesImported: number;
  transactionsImported: number;
  budgetsImported: number;
  recurringImported?: number;
}

/** The mobile-compatible backup document (schemaVersion 1). */
export interface BackupDocument {
  schemaVersion: 1;
  app: string;
  exportedAt: string;
  categories: unknown[];
  transactions: unknown[];
  budgets: unknown[];
  recurring?: unknown[];
}
