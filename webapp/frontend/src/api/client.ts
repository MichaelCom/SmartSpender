/**
 * API client. Talks ONLY to the backend at VITE_API_URL (no direct DB access).
 * All resources are camelCase JSON per API-CONTRACT §2.
 */
import type {
  Budget,
  BudgetPeriod,
  Category,
  CategorySuggestion,
  ExpensesByCategory,
  ForecastResponse,
  Frequency,
  ImportResult,
  Insight,
  Recurring,
  SpendingAnomaly,
  Summary,
  Transaction,
  TxType,
} from "./types";

const BASE_URL: string =
  (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/+$/, "") ??
  "http://localhost:4000";

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

function qs(params: Record<string, string | number | undefined | null>): string {
  const parts = Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== null && v !== "")
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`);
  return parts.length ? `?${parts.join("&")}` : "";
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${BASE_URL}${path}`, {
      headers: { "Content-Type": "application/json" },
      ...init,
    });
  } catch (e) {
    throw new ApiError(0, `Network error: ${(e as Error).message}`);
  }

  if (!res.ok) {
    let message = res.statusText;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* non-JSON error body */
    }
    throw new ApiError(res.status, message);
  }

  if (res.status === 204) return undefined as T;
  const text = await res.text();
  if (!text) return undefined as T;
  return JSON.parse(text) as T;
}

// ---- Categories ----
export const CategoriesApi = {
  list: (type?: TxType) =>
    request<Category[]>(`/categories${qs({ type })}`),
  create: (body: Omit<Category, "id" | "createdAt"> & { createdAt?: string }) =>
    request<Category>("/categories", { method: "POST", body: JSON.stringify(body) }),
  update: (id: number, body: Partial<Omit<Category, "id" | "createdAt">>) =>
    request<Category>(`/categories/${id}`, { method: "PATCH", body: JSON.stringify(body) }),
  remove: (id: number) =>
    request<void>(`/categories/${id}`, { method: "DELETE" }),
};

// ---- Transactions ----
export interface TransactionFilters {
  type?: TxType;
  categoryId?: number;
  from?: string;
  to?: string;
  search?: string;
}

export const TransactionsApi = {
  list: (filters: TransactionFilters = {}) =>
    request<Transaction[]>(`/transactions${qs({ ...filters })}`),
  get: (id: number) => request<Transaction>(`/transactions/${id}`),
  create: (
    body: Omit<
      Transaction,
      "id" | "createdAt" | "categoryName" | "categoryIcon" | "categoryColor"
    > & { createdAt?: string },
  ) => request<Transaction>("/transactions", { method: "POST", body: JSON.stringify(body) }),
  update: (
    id: number,
    body: Partial<
      Omit<Transaction, "id" | "createdAt" | "categoryName" | "categoryIcon" | "categoryColor">
    >,
  ) => request<Transaction>(`/transactions/${id}`, { method: "PATCH", body: JSON.stringify(body) }),
  remove: (id: number) => request<void>(`/transactions/${id}`, { method: "DELETE" }),
};

// ---- Budgets ----
export const BudgetsApi = {
  list: (categoryId?: number) =>
    request<Budget[]>(`/budgets${qs({ categoryId })}`),
  create: (
    body: Omit<Budget, "id" | "createdAt" | "categoryName" | "categoryIcon" | "categoryColor"> & {
      createdAt?: string;
    },
  ) => request<Budget>("/budgets", { method: "POST", body: JSON.stringify(body) }),
  update: (
    id: number,
    body: Partial<
      Omit<Budget, "id" | "createdAt" | "categoryName" | "categoryIcon" | "categoryColor">
    >,
  ) => request<Budget>(`/budgets/${id}`, { method: "PATCH", body: JSON.stringify(body) }),
  remove: (id: number) => request<void>(`/budgets/${id}`, { method: "DELETE" }),
};

// ---- Recurring ----
export const RecurringApi = {
  list: () => request<Recurring[]>("/recurring"),
  create: (body: Omit<Recurring, "id" | "createdAt" | "lastGeneratedDate"> & { createdAt?: string }) =>
    request<Recurring>("/recurring", { method: "POST", body: JSON.stringify(body) }),
  update: (id: number, body: Partial<Omit<Recurring, "id" | "createdAt">>) =>
    request<Recurring>(`/recurring/${id}`, { method: "PATCH", body: JSON.stringify(body) }),
  remove: (id: number) => request<void>(`/recurring/${id}`, { method: "DELETE" }),
  generate: () => request<{ created: number }>("/recurring/generate", { method: "POST" }),
};

// ---- Analytics ----
export const AnalyticsApi = {
  summary: (from?: string, to?: string) =>
    request<Summary>(`/analytics/summary${qs({ from, to })}`),
  expensesByCategory: (from?: string, to?: string) =>
    request<ExpensesByCategory>(`/analytics/expenses-by-category${qs({ from, to })}`),
  insights: () => request<Insight[]>("/insights"),
  topInsight: () => request<Insight | null>("/insights?top=1"),
  anomalies: () => request<SpendingAnomaly[]>("/anomalies"),
  forecast: () => request<ForecastResponse>("/forecast"),
  categorize: (description: string, type: TxType) =>
    request<CategorySuggestion | null>(
      `/categorize${qs({ description, type })}`,
    ),
};

// ---- Bridge ----
export const DataApi = {
  exportJson: () => request<unknown>("/export"),
  exportJsonUrl: () => `${BASE_URL}/export`,
  exportCsvUrl: () => `${BASE_URL}/export/transactions.csv`,
  import: (doc: unknown) =>
    request<ImportResult>("/import", { method: "POST", body: JSON.stringify(doc) }),
  clear: () => request<void>("/data", { method: "DELETE" }),
};

export { BASE_URL };
export type { BudgetPeriod, Frequency, TxType };
