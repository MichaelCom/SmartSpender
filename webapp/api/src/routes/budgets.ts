import { Router } from "express";
import { pool } from "../db/pool";
import { budgetJson, mapBudget } from "../db/mappers";
import {
  badRequest,
  parseDate,
  parseId,
  parsePeriod,
  requireNumber,
  wrap,
} from "../http";

export const budgetsRouter = Router();

const SELECT_BUDGET = `
  SELECT b.*, c.name AS category_name, c.icon AS category_icon,
         c.color AS category_color
  FROM budgets b
  LEFT JOIN categories c ON c.id = b.category_id
`;

async function reload(id: number) {
  const { rows } = await pool.query(`${SELECT_BUDGET} WHERE b.id = $1`, [id]);
  return budgetJson(mapBudget(rows[0]));
}

// GET /budgets (?categoryId=)
budgetsRouter.get(
  "/",
  wrap(async (req, res) => {
    const params: any[] = [];
    let sql = SELECT_BUDGET;
    if (req.query.categoryId != null && req.query.categoryId !== "") {
      params.push(parseId(String(req.query.categoryId)));
      sql += ` WHERE b.category_id = $${params.length}`;
    }
    sql += " ORDER BY b.start_date DESC, b.id DESC";
    const { rows } = await pool.query(sql, params);
    res.json(rows.map(mapBudget).map(budgetJson));
  })
);

// POST /budgets
budgetsRouter.post(
  "/",
  wrap(async (req, res) => {
    const body = req.body ?? {};
    if (body.categoryId == null) throw badRequest("categoryId is required");
    const categoryId = parseId(String(body.categoryId));
    const amount = requireNumber(body.amount, "amount");
    const period = parsePeriod(body.period);
    const startDate = parseDate(body.startDate, "startDate");
    const endDate = parseDate(body.endDate, "endDate");
    const createdAt = body.createdAt ? new Date(body.createdAt) : new Date();
    const { rows } = await pool.query(
      `INSERT INTO budgets
         (category_id, amount, period, start_date, end_date, created_at, description)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
      [categoryId, amount, period, startDate, endDate, createdAt, body.description ?? null]
    );
    res.status(201).json(await reload(rows[0].id));
  })
);

// PATCH /budgets/:id
budgetsRouter.patch(
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
    if (body.categoryId !== undefined) set("category_id", parseId(String(body.categoryId)));
    if (body.amount !== undefined) set("amount", requireNumber(body.amount, "amount"));
    if (body.period !== undefined) set("period", parsePeriod(body.period));
    if (body.startDate !== undefined) set("start_date", parseDate(body.startDate, "startDate"));
    if (body.endDate !== undefined) set("end_date", parseDate(body.endDate, "endDate"));
    if (body.description !== undefined) set("description", body.description ?? null);
    if (fields.length === 0) throw badRequest("No fields to update");
    values.push(id);
    const { rowCount } = await pool.query(
      `UPDATE budgets SET ${fields.join(", ")} WHERE id = $${i}`,
      values
    );
    if (rowCount === 0) {
      res.status(404).json({ error: "Budget not found" });
      return;
    }
    res.json(await reload(id));
  })
);

// DELETE /budgets/:id
budgetsRouter.delete(
  "/:id",
  wrap(async (req, res) => {
    const id = parseId(req.params.id);
    const { rowCount } = await pool.query("DELETE FROM budgets WHERE id = $1", [
      id,
    ]);
    if (rowCount === 0) {
      res.status(404).json({ error: "Budget not found" });
      return;
    }
    res.status(204).end();
  })
);

export { SELECT_BUDGET };
