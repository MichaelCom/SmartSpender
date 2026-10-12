import type { PoolClient } from "pg";

/** A backup document (schemaVersion 2) — the shared shape /import and /seed use. */
export interface BackupDoc {
  schemaVersion: number;
  categories: any[];
  transactions: any[];
  budgets: any[];
  recurring?: any[];
}

export interface ApplyResult {
  categoriesImported: number;
  transactionsImported: number;
  budgetsImported: number;
  recurringImported: number;
}

/**
 * REPLACE all data with the contents of [doc], within the caller's transaction.
 * Remaps old ids -> new ids so relationships survive. Shared by /import and
 * /seed. The caller is responsible for BEGIN/COMMIT/ROLLBACK and releasing the
 * client.
 */
export async function applyBackup(
  client: PoolClient,
  doc: BackupDoc
): Promise<ApplyResult> {
  const recurringIn = Array.isArray(doc.recurring) ? doc.recurring : [];

  // REPLACE: clear all tables (children first for FK safety).
  await client.query("DELETE FROM transactions");
  await client.query("DELETE FROM budgets");
  await client.query("DELETE FROM recurring_transactions");
  await client.query("DELETE FROM categories");

  const result: ApplyResult = {
    categoriesImported: 0,
    transactionsImported: 0,
    budgetsImported: 0,
    recurringImported: 0,
  };

  // Categories: insert + build old-id -> new-id map.
  const catMap = new Map<number, number>();
  for (const c of doc.categories) {
    if (c == null || typeof c !== "object") continue;
    const type = c.type === "income" ? "income" : "expense";
    const createdAt = c.createdAt ? new Date(c.createdAt) : new Date();
    const { rows } = await client.query(
      `INSERT INTO categories (name, type, color, icon, created_at)
       VALUES ($1,$2,$3,$4,$5) RETURNING id`,
      [c.name ?? "", type, c.color ?? null, c.icon ?? null, createdAt]
    );
    if (c.id != null) catMap.set(Number(c.id), rows[0].id);
    result.categoriesImported++;
  }

  // Recurring (insert before transactions so they can FK them).
  const recMap = new Map<number, number>();
  for (const r of recurringIn) {
    if (r == null || typeof r !== "object") continue;
    const type = r.type === "income" ? "income" : "expense";
    const freq = ["daily", "weekly", "monthly", "yearly"].includes(r.frequency)
      ? r.frequency
      : "monthly";
    const remappedCat =
      r.categoryId != null && catMap.has(Number(r.categoryId))
        ? catMap.get(Number(r.categoryId))
        : null;
    const { rows } = await client.query(
      `INSERT INTO recurring_transactions
         (amount, description, category_id, type, frequency, start_date,
          end_date, last_generated_date, created_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
      [
        Number(r.amount ?? 0),
        r.description ?? null,
        remappedCat,
        type,
        freq,
        r.startDate ? new Date(r.startDate) : new Date(),
        r.endDate ? new Date(r.endDate) : null,
        r.lastGeneratedDate ? new Date(r.lastGeneratedDate) : null,
        r.createdAt ? new Date(r.createdAt) : new Date(),
      ]
    );
    if (r.id != null) recMap.set(Number(r.id), rows[0].id);
    result.recurringImported++;
  }

  // Transactions: remap categoryId (unknown/absent -> null) and recurringId.
  for (const t of doc.transactions) {
    if (t == null || typeof t !== "object") continue;
    const type = t.type === "income" ? "income" : "expense";
    const catId =
      t.categoryId != null && catMap.has(Number(t.categoryId))
        ? catMap.get(Number(t.categoryId))!
        : null;
    const recId =
      t.recurringId != null && recMap.has(Number(t.recurringId))
        ? recMap.get(Number(t.recurringId))!
        : null;
    await client.query(
      `INSERT INTO transactions
         (amount, description, category_id, date, type, created_at, recurring_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [
        Number(t.amount ?? 0),
        t.description ?? null,
        catId,
        t.date ? new Date(t.date) : new Date(),
        type,
        t.createdAt ? new Date(t.createdAt) : new Date(),
        recId,
      ]
    );
    result.transactionsImported++;
  }

  // Budgets: skip those whose category is missing.
  for (const b of doc.budgets) {
    if (b == null || typeof b !== "object") continue;
    if (b.categoryId == null || !catMap.has(Number(b.categoryId))) continue;
    const period = ["weekly", "monthly", "yearly"].includes(b.period)
      ? b.period
      : "monthly";
    await client.query(
      `INSERT INTO budgets
         (category_id, amount, period, start_date, end_date, created_at, description)
       VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [
        catMap.get(Number(b.categoryId))!,
        Number(b.amount ?? 0),
        period,
        b.startDate ? new Date(b.startDate) : new Date(),
        b.endDate ? new Date(b.endDate) : new Date(),
        b.createdAt ? new Date(b.createdAt) : new Date(),
        b.description ?? null,
      ]
    );
    result.budgetsImported++;
  }

  return result;
}
