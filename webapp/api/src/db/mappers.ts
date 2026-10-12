import {
  Budget,
  Category,
  RecurringTransaction,
  Transaction,
} from "../types/models";

// Row <-> domain mappers. pg returns TIMESTAMPTZ columns as JS Date objects
// and DOUBLE PRECISION as numbers, so most of this is key renaming + null
// normalisation.

function toDate(v: unknown): Date {
  if (v instanceof Date) return v;
  return new Date(v as string);
}
function toDateOrNull(v: unknown): Date | null {
  if (v == null) return null;
  return toDate(v);
}

export function mapCategory(r: any): Category {
  return {
    id: r.id,
    name: r.name,
    type: r.type,
    color: r.color ?? null,
    icon: r.icon ?? null,
    createdAt: toDate(r.created_at),
  };
}

export function mapTransaction(r: any): Transaction {
  return {
    id: r.id,
    amount: Number(r.amount),
    description: r.description ?? null,
    categoryId: r.category_id ?? null,
    date: toDate(r.date),
    type: r.type,
    createdAt: toDate(r.created_at),
    recurringId: r.recurring_id ?? null,
    categoryName: r.category_name ?? null,
    categoryIcon: r.category_icon ?? null,
    categoryColor: r.category_color ?? null,
  };
}

export function mapBudget(r: any): Budget {
  return {
    id: r.id,
    categoryId: r.category_id,
    amount: Number(r.amount),
    period: r.period,
    startDate: toDate(r.start_date),
    endDate: toDate(r.end_date),
    createdAt: toDate(r.created_at),
    description: r.description ?? null,
    categoryName: r.category_name ?? null,
    categoryIcon: r.category_icon ?? null,
    categoryColor: r.category_color ?? null,
  };
}

export function mapRecurring(r: any): RecurringTransaction {
  return {
    id: r.id,
    amount: Number(r.amount),
    description: r.description ?? null,
    categoryId: r.category_id ?? null,
    type: r.type,
    frequency: r.frequency,
    startDate: toDate(r.start_date),
    endDate: toDateOrNull(r.end_date),
    lastGeneratedDate: toDateOrNull(r.last_generated_date),
    createdAt: toDate(r.created_at),
    categoryName: r.category_name ?? null,
    categoryIcon: r.category_icon ?? null,
    categoryColor: r.category_color ?? null,
  };
}

// Serialize domain objects to the camelCase JSON wire shape (ISO dates).
function iso(d: Date | null | undefined): string | null {
  return d == null ? null : d.toISOString();
}

export function categoryJson(c: Category) {
  return {
    id: c.id,
    name: c.name,
    type: c.type,
    color: c.color ?? null,
    icon: c.icon ?? null,
    createdAt: iso(c.createdAt),
  };
}

export function transactionJson(t: Transaction) {
  return {
    id: t.id,
    amount: t.amount,
    description: t.description ?? null,
    categoryId: t.categoryId ?? null,
    date: iso(t.date),
    type: t.type,
    createdAt: iso(t.createdAt),
    recurringId: t.recurringId ?? null,
    categoryName: t.categoryName ?? null,
    categoryIcon: t.categoryIcon ?? null,
    categoryColor: t.categoryColor ?? null,
  };
}

export function budgetJson(b: Budget) {
  return {
    id: b.id,
    categoryId: b.categoryId,
    amount: b.amount,
    period: b.period,
    startDate: iso(b.startDate),
    endDate: iso(b.endDate),
    createdAt: iso(b.createdAt),
    description: b.description ?? null,
    categoryName: b.categoryName ?? null,
    categoryIcon: b.categoryIcon ?? null,
    categoryColor: b.categoryColor ?? null,
  };
}

export function recurringJson(r: RecurringTransaction) {
  return {
    id: r.id,
    amount: r.amount,
    description: r.description ?? null,
    categoryId: r.categoryId ?? null,
    type: r.type,
    frequency: r.frequency,
    startDate: iso(r.startDate),
    endDate: iso(r.endDate),
    lastGeneratedDate: iso(r.lastGeneratedDate),
    createdAt: iso(r.createdAt),
    categoryName: r.categoryName ?? null,
    categoryIcon: r.categoryIcon ?? null,
    categoryColor: r.categoryColor ?? null,
  };
}
