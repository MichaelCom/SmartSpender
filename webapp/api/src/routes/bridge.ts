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
import { applyBackup, type BackupDoc } from "../db/apply-backup";
import { buildDemoBackup } from "../demo/demo-data";

export const bridgeRouter = Router();

function isArray(v: unknown): v is any[] {
  return Array.isArray(v);
}

// POST /import -> REPLACE all data, remap IDs.
// Accepts the mobile backup JSON (schemaVersion 1 or 2) from §3. The optional
// web-extension "recurring" array is also imported when present.
bridgeRouter.post(
  "/import",
  wrap(async (req, res) => {
    const body = req.body;
    if (body == null || typeof body !== "object" || Array.isArray(body)) {
      throw badRequest("Backup must be a JSON object");
    }
    if (body.schemaVersion !== 1 && body.schemaVersion !== 2) {
      throw badRequest(
        "Unsupported or missing schemaVersion (expected 1 or 2)"
      );
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

    const result = await replaceAll(body as BackupDoc);
    res.json({
      categoriesImported: result.categoriesImported,
      transactionsImported: result.transactionsImported,
      budgetsImported: result.budgetsImported,
      recurringImported: result.recurringImported,
    });
  })
);

// POST /seed -> REPLACE all data with generated demo data (dev/demo helper).
bridgeRouter.post(
  "/seed",
  wrap(async (_req, res) => {
    const doc = buildDemoBackup();
    const result = await replaceAll(doc);
    res.json(result);
  })
);

// Shared: run applyBackup inside a transaction with rollback on error.
async function replaceAll(doc: BackupDoc) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await applyBackup(client, doc);
    await client.query("COMMIT");
    return result;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

// GET /export -> schemaVersion 2 document + optional "recurring" (web extension)
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
      schemaVersion: 2,
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
