import { Router } from "express";
import { pool } from "../db/pool";
import { mapRecurring, recurringJson } from "../db/mappers";
import { advance } from "../analytics/recurring";
import {
  badRequest,
  parseDate,
  parseFrequency,
  parseId,
  parseOptionalDate,
  parseType,
  requireNumber,
  wrap,
} from "../http";
import { Frequency } from "../types/models";

export const recurringRouter = Router();

const SELECT_RECURRING = `
  SELECT r.*, c.name AS category_name, c.icon AS category_icon,
         c.color AS category_color
  FROM recurring_transactions r
  LEFT JOIN categories c ON c.id = r.category_id
`;

async function reload(id: number) {
  const { rows } = await pool.query(`${SELECT_RECURRING} WHERE r.id = $1`, [id]);
  return recurringJson(mapRecurring(rows[0]));
}

// GET /recurring
recurringRouter.get(
  "/",
  wrap(async (_req, res) => {
    const { rows } = await pool.query(
      `${SELECT_RECURRING} ORDER BY r.start_date DESC, r.id DESC`
    );
    res.json(rows.map(mapRecurring).map(recurringJson));
  })
);

// POST /recurring
recurringRouter.post(
  "/",
  wrap(async (req, res) => {
    const body = req.body ?? {};
    const amount = requireNumber(body.amount, "amount");
    const t = parseType(body.type);
    if (!t) throw badRequest("type is required (income|expense)");
    const frequency = parseFrequency(body.frequency);
    const startDate = parseDate(body.startDate, "startDate");
    const endDate = parseOptionalDate(body.endDate, "endDate");
    const lastGenerated = parseOptionalDate(
      body.lastGeneratedDate,
      "lastGeneratedDate"
    );
    const createdAt = body.createdAt ? new Date(body.createdAt) : new Date();
    const { rows } = await pool.query(
      `INSERT INTO recurring_transactions
         (amount, description, category_id, type, frequency, start_date,
          end_date, last_generated_date, created_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
      [
        amount,
        body.description ?? null,
        body.categoryId ?? null,
        t,
        frequency,
        startDate,
        endDate,
        lastGenerated,
        createdAt,
      ]
    );
    res.status(201).json(await reload(rows[0].id));
  })
);

// PATCH /recurring/:id
recurringRouter.patch(
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
    if (body.type !== undefined) set("type", parseType(body.type));
    if (body.frequency !== undefined) set("frequency", parseFrequency(body.frequency));
    if (body.startDate !== undefined) set("start_date", parseDate(body.startDate, "startDate"));
    if (body.endDate !== undefined) set("end_date", parseOptionalDate(body.endDate, "endDate"));
    if (body.lastGeneratedDate !== undefined)
      set("last_generated_date", parseOptionalDate(body.lastGeneratedDate, "lastGeneratedDate"));
    if (fields.length === 0) throw badRequest("No fields to update");
    values.push(id);
    const { rowCount } = await pool.query(
      `UPDATE recurring_transactions SET ${fields.join(", ")} WHERE id = $${i}`,
      values
    );
    if (rowCount === 0) {
      res.status(404).json({ error: "Recurring rule not found" });
      return;
    }
    res.json(await reload(id));
  })
);

// DELETE /recurring/:id
recurringRouter.delete(
  "/:id",
  wrap(async (req, res) => {
    const id = parseId(req.params.id);
    const { rowCount } = await pool.query(
      "DELETE FROM recurring_transactions WHERE id = $1",
      [id]
    );
    if (rowCount === 0) {
      res.status(404).json({ error: "Recurring rule not found" });
      return;
    }
    res.status(204).end();
  })
);

// POST /recurring/generate -> { created: <int> }
// On-demand catch-up: for each rule, materialise concrete transactions for every
// due date from the last-generated point up to (and including) today, bounded
// by the rule's start/end window. Updates last_generated_date per rule.
recurringRouter.post(
  "/generate",
  wrap(async (_req, res) => {
    const now = new Date();
    const client = await pool.connect();
    let created = 0;
    try {
      await client.query("BEGIN");
      const { rows } = await client.query(
        "SELECT * FROM recurring_transactions"
      );
      for (const row of rows) {
        const rule = mapRecurring(row);
        const freq: Frequency = rule.frequency;
        const start = rule.startDate;
        const end = rule.endDate;
        // Begin at the first un-generated occurrence.
        let occ = rule.lastGeneratedDate
          ? advance(freq, rule.lastGeneratedDate)
          : start;
        let lastGen = rule.lastGeneratedDate ?? null;
        let guard = 0;
        while (occ.getTime() <= now.getTime() && guard < 100000) {
          guard++;
          // Respect the rule window.
          if (occ.getTime() < start.getTime()) {
            occ = advance(freq, occ);
            continue;
          }
          if (end != null && occ.getTime() > end.getTime()) break;
          await client.query(
            `INSERT INTO transactions
               (amount, description, category_id, date, type, created_at, recurring_id)
             VALUES ($1,$2,$3,$4,$5,$6,$7)`,
            [
              rule.amount,
              rule.description ?? null,
              rule.categoryId ?? null,
              occ,
              rule.type,
              now,
              rule.id,
            ]
          );
          created++;
          lastGen = occ;
          occ = advance(freq, occ);
        }
        if (lastGen != null && lastGen !== rule.lastGeneratedDate) {
          await client.query(
            "UPDATE recurring_transactions SET last_generated_date = $1 WHERE id = $2",
            [lastGen, rule.id]
          );
        }
      }
      await client.query("COMMIT");
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
    res.json({ created });
  })
);

export { SELECT_RECURRING };
