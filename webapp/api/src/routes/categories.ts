import { Router } from "express";
import { pool } from "../db/pool";
import { categoryJson, mapCategory } from "../db/mappers";
import {
  badRequest,
  parseId,
  parseType,
  wrap,
} from "../http";

export const categoriesRouter = Router();

// GET /categories (?type=income|expense)
categoriesRouter.get(
  "/",
  wrap(async (req, res) => {
    const type = parseType(req.query.type);
    const params: any[] = [];
    let sql = "SELECT * FROM categories";
    if (type) {
      params.push(type);
      sql += " WHERE type = $1";
    }
    sql += " ORDER BY name ASC";
    const { rows } = await pool.query(sql, params);
    res.json(rows.map(mapCategory).map(categoryJson));
  })
);

// POST /categories
categoriesRouter.post(
  "/",
  wrap(async (req, res) => {
    const { name, type, color, icon } = req.body ?? {};
    if (typeof name !== "string" || name.trim() === "") {
      throw badRequest("name is required");
    }
    const t = parseType(type);
    if (!t) throw badRequest("type is required (income|expense)");
    const createdAt = req.body?.createdAt
      ? new Date(req.body.createdAt)
      : new Date();
    const { rows } = await pool.query(
      `INSERT INTO categories (name, type, color, icon, created_at)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [name, t, color ?? null, icon ?? null, createdAt]
    );
    res.status(201).json(categoryJson(mapCategory(rows[0])));
  })
);

// PATCH /categories/:id
categoriesRouter.patch(
  "/:id",
  wrap(async (req, res) => {
    const id = parseId(req.params.id);
    const fields: string[] = [];
    const values: any[] = [];
    let i = 1;
    const body = req.body ?? {};
    if (body.name !== undefined) {
      if (typeof body.name !== "string" || body.name.trim() === "") {
        throw badRequest("name must be a non-empty string");
      }
      fields.push(`name = $${i++}`);
      values.push(body.name);
    }
    if (body.type !== undefined) {
      const t = parseType(body.type);
      fields.push(`type = $${i++}`);
      values.push(t);
    }
    if (body.color !== undefined) {
      fields.push(`color = $${i++}`);
      values.push(body.color ?? null);
    }
    if (body.icon !== undefined) {
      fields.push(`icon = $${i++}`);
      values.push(body.icon ?? null);
    }
    if (fields.length === 0) throw badRequest("No fields to update");
    values.push(id);
    const { rows } = await pool.query(
      `UPDATE categories SET ${fields.join(", ")} WHERE id = $${i} RETURNING *`,
      values
    );
    if (rows.length === 0) {
      res.status(404).json({ error: "Category not found" });
      return;
    }
    res.json(categoryJson(mapCategory(rows[0])));
  })
);

// DELETE /categories/:id (SET NULL on txns/recurring, CASCADE budgets via FK)
categoriesRouter.delete(
  "/:id",
  wrap(async (req, res) => {
    const id = parseId(req.params.id);
    const { rowCount } = await pool.query(
      "DELETE FROM categories WHERE id = $1",
      [id]
    );
    if (rowCount === 0) {
      res.status(404).json({ error: "Category not found" });
      return;
    }
    res.status(204).end();
  })
);
