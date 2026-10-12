import { Router } from "express";
import { pool } from "../db/pool";
import { mapTransaction, transactionJson } from "../db/mappers";
import {
  badRequest,
  parseDate,
  parseId,
  parseType,
  queryDate,
  requireNumber,
  wrap,
} from "../http";

export const transactionsRouter = Router();

// SELECT with the JOINed category read-only fields.
const SELECT_TX = `
  SELECT t.*, c.name AS category_name, c.icon AS category_icon,
         c.color AS category_color
  FROM transactions t
  LEFT JOIN categories c ON c.id = t.category_id
`;

// GET /transactions (?type= &categoryId= &from=ISO &to=ISO &search=)
transactionsRouter.get(
  "/",
  wrap(async (req, res) => {
    const type = parseType(req.query.type);
    const from = queryDate(req.query.from);
    const to = queryDate(req.query.to);
    const search =
      typeof req.query.search === "string" && req.query.search.trim() !== ""
        ? req.query.search.trim()
        : undefined;
    const categoryId =
      req.query.categoryId != null && req.query.categoryId !== ""
        ? parseId(String(req.query.categoryId))
        : undefined;

    const where: string[] = [];
    const params: any[] = [];
    if (type) {
      params.push(type);
      where.push(`t.type = $${params.length}`);
    }
    if (categoryId !== undefined) {
      params.push(categoryId);
      where.push(`t.category_id = $${params.length}`);
    }
    if (from) {
      params.push(from);
      where.push(`t.date >= $${params.length}`);
    }
    if (to) {
      params.push(to);
      where.push(`t.date <= $${params.length}`);
    }
    if (search) {
      params.push(`%${search}%`);
      where.push(`t.description ILIKE $${params.length}`);
    }
    let sql = SELECT_TX;
    if (where.length) sql += ` WHERE ${where.join(" AND ")}`;
    sql += " ORDER BY t.date DESC, t.id DESC";
    const { rows } = await pool.query(sql, params);
    res.json(rows.map(mapTransaction).map(transactionJson));
  })
);

// GET /transactions/:id
transactionsRouter.get(
  "/:id",
  wrap(async (req, res) => {
    const id = parseId(req.params.id);
    const { rows } = await pool.query(`${SELECT_TX} WHERE t.id = $1`, [id]);
    if (rows.length === 0) {
      res.status(404).json({ error: "Transaction not found" });
      return;
    }
    res.json(transactionJson(mapTransaction(rows[0])));
  })
);

async function reloadWithJoin(id: number) {
  const { rows } = await pool.query(`${SELECT_TX} WHERE t.id = $1`, [id]);
  return transactionJson(mapTransaction(rows[0]));
}

// POST /transactions
transactionsRouter.post(
  "/",
  wrap(async (req, res) => {
    const body = req.body ?? {};
    const amount = requireNumber(body.amount, "amount");
    const t = parseType(body.type);
    if (!t) throw badRequest("type is required (income|expense)");
    const date = parseDate(body.date, "date");
    const createdAt = body.createdAt ? new Date(body.createdAt) : new Date();
    const { rows } = await pool.query(
      `INSERT INTO transactions
         (amount, description, category_id, date, type, created_at, recurring_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
      [
        amount,
        body.description ?? null,
        body.categoryId ?? null,
        date,
        t,
        createdAt,
        body.recurringId ?? null,
      ]
    );
    res.status(201).json(await reloadWithJoin(rows[0].id));
  })
);

// PATCH /transactions/:id
transactionsRouter.patch(
  "/:id",
  wrap(async (req, res) => {
    const id = parseId(req.params.id);
    const body = req.body ?? {};
    const fields: string[] = [];
    const values: any[] = [];
    let i = 1;
    const set = (col: string, val: any) => {
      fields.push(`${col} = $${i++}`);
      values.push(val);
    };
    if (body.amount !== undefined) set("amount", requireNumber(body.amount, "amount"));
    if (body.description !== undefined) set("description", body.description ?? null);
    if (body.categoryId !== undefined) set("category_id", body.categoryId ?? null);
    if (body.date !== undefined) set("date", parseDate(body.date, "date"));
    if (body.type !== undefined) set("type", parseType(body.type));
    if (body.recurringId !== undefined) set("recurring_id", body.recurringId ?? null);
    if (fields.length === 0) throw badRequest("No fields to update");
    values.push(id);
    const { rowCount } = await pool.query(
      `UPDATE transactions SET ${fields.join(", ")} WHERE id = $${i}`,
      values
    );
    if (rowCount === 0) {
      res.status(404).json({ error: "Transaction not found" });
      return;
    }
    res.json(await reloadWithJoin(id));
  })
);

// DELETE /transactions/:id
transactionsRouter.delete(
  "/:id",
  wrap(async (req, res) => {
    const id = parseId(req.params.id);
    const { rowCount } = await pool.query(
      "DELETE FROM transactions WHERE id = $1",
      [id]
    );
    if (rowCount === 0) {
      res.status(404).json({ error: "Transaction not found" });
      return;
    }
    res.status(204).end();
  })
);

export { SELECT_TX };
