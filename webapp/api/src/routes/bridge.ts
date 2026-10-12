import { Router } from "express";
import { pool } from "../db/pool";
import {
  loadAllBudgets,
  loadAllCategories,
  loadAllRecurring,
  loadAllTransactions,
} from "../db/loaders";
import {
  budgetJson,
  categoryJson,
  recurringJson,
  transactionJson,
} from "../db/mappers";
import { badRequest, wrap } from "../http";

export const bridgeRouter = Router();

function isArray(v: unknown): v is any[] {
  return Array.isArray(v);
}

// POST /import -> REPLACE all data, remap IDs.
// Accepts the EXACT mobile backup JSON (schemaVersion 1) from §3. The optional
// web-extension "recurring" array is also imported when present.
bridgeRouter.post(
  "/import",
  wrap(async (req, res) => {
    const body = req.body;
    if (body == null || typeof body !== "object" || Array.isArray(body)) {
      throw badRequest("Backup must be a JSON object");
    }
    if (body.schemaVersion !== 1) {
      throw badRequest("Unsupported or missing schemaVersion (expected 1)");
    }
    if (
      !isArray(body.categories) ||
      !isArray(body.transactions) ||
      !isArray(body.budgets)
    ) {
      throw badRequest(
        "categories, transactions and budgets must all be arrays"
      );
    }
    const recurringIn = isArray(body.recurring) ? body.recurring : [];

    const client = await pool.connect();
    let categoriesImported = 0;
    let transactionsImported = 0;
    let budgetsImported = 0;
    try {
      await client.query("BEGIN");

      // REPLACE: clear all tables. Order respects FKs (children first).
      await client.query("DELETE FROM transactions");
      await client.query("DELETE FROM budgets");
      await client.query("DELETE FROM recurring_transactions");
      await client.query("DELETE FROM categories");

      // --- Categories: insert and build old-id -> new-id map ---
      const catMap = new Map<number, number>();
      for (const c of body.categories) {
        if (c == null || typeof c !== "object") continue;
        const type = c.type === "income" ? "income" : "expense";
        const createdAt = c.createdAt ? new Date(c.createdAt) : new Date();
        const { rows } = await client.query(
          `INSERT INTO categories (name, type, color, icon, created_at)
           VALUES ($1,$2,$3,$4,$5) RETURNING id`,
          [c.name ?? "", type, c.color ?? null, c.icon ?? null, createdAt]
        );
        if (c.id != null) catMap.set(Number(c.id), rows[0].id);
        categoriesImported++;
      }

      // --- Recurring (web extension): insert first so txns can FK them ---
      // Mobile v1 backups never contain this; absent => simply skipped.
      const recMap = new Map<number, number>();
      for (const r of recurringIn) {
        if (r == null || typeof r !== "object") continue;
        const type = r.type === "income" ? "income" : "expense";
        const freq = ["daily", "weekly", "monthly", "yearly"].includes(
          r.frequency
        )
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
      }

      // --- Transactions: remap categoryId (unknown/absent -> null) ---
      for (const t of body.transactions) {
        if (t == null || typeof t !== "object") continue;
        const type = t.type === "income" ? "income" : "expense";
        let catId: number | null = null;
        if (t.categoryId != null && catMap.has(Number(t.categoryId))) {
          catId = catMap.get(Number(t.categoryId))!;
        }
        let recId: number | null = null;
        if (t.recurringId != null && recMap.has(Number(t.recurringId))) {
          recId = recMap.get(Number(t.recurringId))!;
        }
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
        transactionsImported++;
      }

      // --- Budgets: skip those whose category is missing ---
      for (const b of body.budgets) {
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
        budgetsImported++;
      }

      await client.query("COMMIT");
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }

    res.json({ categoriesImported, transactionsImported, budgetsImported });
  })
);

// GET /export -> schemaVersion 1 document + optional "recurring" (web extension)
bridgeRouter.get(
  "/export",
  wrap(async (_req, res) => {
    const [categories, transactions, budgets, recurring] = await Promise.all([
      loadAllCategories(),
      loadAllTransactions(),
      loadAllBudgets(),
      loadAllRecurring(),
    ]);

    const doc = {
      schemaVersion: 1,
      app: "SmartSpender",
      exportedAt: new Date().toISOString(),
      categories: categories.map((c) => {
        const j = categoryJson(c);
        return {
          id: j.id,
          name: j.name,
          type: j.type,
          color: j.color,
          icon: j.icon,
          createdAt: j.createdAt,
        };
      }),
      transactions: transactions.map((t) => {
        const j = transactionJson(t);
        return {
          id: j.id,
          amount: j.amount,
          description: j.description,
          categoryId: j.categoryId,
          date: j.date,
          type: j.type,
          createdAt: j.createdAt,
        };
      }),
      budgets: budgets.map((b) => {
        const j = budgetJson(b);
        return {
          id: j.id,
          categoryId: j.categoryId,
          amount: j.amount,
          period: j.period,
          startDate: j.startDate,
          endDate: j.endDate,
          createdAt: j.createdAt,
          description: j.description,
        };
      }),
      // Web extension (ignored by a mobile import of unknown keys).
      recurring: recurring.map((r) => {
        const j = recurringJson(r);
        return {
          id: j.id,
          amount: j.amount,
          description: j.description,
          categoryId: j.categoryId,
          type: j.type,
          frequency: j.frequency,
          startDate: j.startDate,
          endDate: j.endDate,
          lastGeneratedDate: j.lastGeneratedDate,
          createdAt: j.createdAt,
        };
      }),
    };
    res.json(doc);
  })
);

// RFC-4180 CSV field escaping.
function csvField(v: string): string {
  if (/[",\r\n]/.test(v)) {
    return `"${v.replace(/"/g, '""')}"`;
  }
  return v;
}

// GET /export/transactions.csv
//   columns: date(YYYY-MM-DD),type,amount(2dp),category,description
bridgeRouter.get(
  "/export/transactions.csv",
  wrap(async (_req, res) => {
    const txs = await loadAllTransactions();
    const lines: string[] = ["date,type,amount,category,description"];
    for (const t of txs) {
      const date = t.date.toISOString().slice(0, 10); // YYYY-MM-DD
      const category = t.categoryName ?? "Uncategorised";
      const description = t.description ?? "";
      lines.push(
        [
          csvField(date),
          csvField(t.type),
          csvField(t.amount.toFixed(2)),
          csvField(category),
          csvField(description),
        ].join(",")
      );
    }
    const body = lines.join("\r\n");
    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader(
      "Content-Disposition",
      'attachment; filename="transactions.csv"'
    );
    res.send(body);
  })
);

// DELETE /data -> clear ALL data (parity with mobile "Clear All Data")
bridgeRouter.delete(
  "/data",
  wrap(async (_req, res) => {
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("DELETE FROM transactions");
      await client.query("DELETE FROM budgets");
      await client.query("DELETE FROM recurring_transactions");
      await client.query("DELETE FROM categories");
      await client.query("COMMIT");
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
    res.status(204).end();
  })
);
