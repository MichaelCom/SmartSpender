import { pool } from "./pool";
import {
  mapBudget,
  mapCategory,
  mapRecurring,
  mapTransaction,
} from "./mappers";
import { Budget, Category, RecurringTransaction, Transaction } from "../types/models";

// Shared data loaders used by the analytics routes. They return domain objects
// (Date objects, camelCase) so the ported engines can run unchanged.

const TX_WITH_CAT = `
  SELECT t.*, c.name AS category_name, c.icon AS category_icon,
         c.color AS category_color
  FROM transactions t
  LEFT JOIN categories c ON c.id = t.category_id
`;

export async function loadAllTransactions(): Promise<Transaction[]> {
  const { rows } = await pool.query(`${TX_WITH_CAT} ORDER BY t.date ASC, t.id ASC`);
  return rows.map(mapTransaction);
}

export async function loadAllCategories(): Promise<Category[]> {
  const { rows } = await pool.query("SELECT * FROM categories ORDER BY id ASC");
  return rows.map(mapCategory);
}

export async function loadAllRecurring(): Promise<RecurringTransaction[]> {
  const { rows } = await pool.query(
    "SELECT * FROM recurring_transactions ORDER BY id ASC"
  );
  return rows.map(mapRecurring);
}

export async function loadAllBudgets(): Promise<Budget[]> {
  const { rows } = await pool.query(
    `SELECT b.*, c.name AS category_name, c.icon AS category_icon,
            c.color AS category_color
     FROM budgets b LEFT JOIN categories c ON c.id = b.category_id
     ORDER BY b.id ASC`
  );
  return rows.map(mapBudget);
}
