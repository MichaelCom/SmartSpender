import { Router } from "express";
import { pool } from "../db/pool";
import {
  loadAllBudgets,
  loadAllCategories,
  loadAllRecurring,
  loadAllTransactions,
} from "../db/loaders";
import { budgetJson, transactionJson } from "../db/mappers";
import { detectAnomalies } from "../analytics/anomaly";
import { suggestCategory } from "../analytics/categorization";
import { forecastBudget, forecastMonth } from "../analytics/forecast";
import { buildInsights, topInsight } from "../analytics/insights";
import { parseType, queryDate, wrap } from "../http";

export const analyticsRouter = Router();

// GET /analytics/summary (?from= &to=) -> { income, expenses, balance }
analyticsRouter.get(
  "/analytics/summary",
  wrap(async (req, res) => {
    const from = queryDate(req.query.from);
    const to = queryDate(req.query.to);
    const where: string[] = [];
    const params: any[] = [];
    if (from) {
      params.push(from);
      where.push(`date >= $${params.length}`);
    }
    if (to) {
      params.push(to);
      where.push(`date <= $${params.length}`);
    }
    const whereSql = where.length ? ` WHERE ${where.join(" AND ")}` : "";
    const { rows } = await pool.query(
      `SELECT type, COALESCE(SUM(amount),0) AS total
       FROM transactions${whereSql} GROUP BY type`,
      params
    );
    let income = 0;
    let expenses = 0;
    for (const r of rows) {
      if (r.type === "income") income = Number(r.total);
      else if (r.type === "expense") expenses = Number(r.total);
    }
    res.json({ income, expenses, balance: income - expenses });
  })
);

// GET /analytics/expenses-by-category (?from= &to=)
//   -> { "<categoryName>": amount, ... }
analyticsRouter.get(
  "/analytics/expenses-by-category",
  wrap(async (req, res) => {
    const from = queryDate(req.query.from);
    const to = queryDate(req.query.to);
    const where: string[] = [`t.type = 'expense'`];
    const params: any[] = [];
    if (from) {
      params.push(from);
      where.push(`t.date >= $${params.length}`);
    }
    if (to) {
      params.push(to);
      where.push(`t.date <= $${params.length}`);
    }
    const { rows } = await pool.query(
      `SELECT COALESCE(c.name, 'Uncategorised') AS name,
              COALESCE(SUM(t.amount),0) AS total
       FROM transactions t
       LEFT JOIN categories c ON c.id = t.category_id
       WHERE ${where.join(" AND ")}
       GROUP BY COALESCE(c.name, 'Uncategorised')`,
      params
    );
    const out: Record<string, number> = {};
    for (const r of rows) out[r.name] = Number(r.total);
    res.json(out);
  })
);

// GET /insights (?top=1 for single) -> Insight[] | Insight|null
analyticsRouter.get(
  "/insights",
  wrap(async (req, res) => {
    const [allTransactions, recurring, budgets] = await Promise.all([
      loadAllTransactions(),
      loadAllRecurring(),
      loadAllBudgets(),
    ]);
    const currencySymbol =
      typeof req.query.currencySymbol === "string"
        ? req.query.currencySymbol
        : "R";
    const params = { allTransactions, recurring, budgets, currencySymbol };
    if (req.query.top === "1") {
      res.json(topInsight(params));
      return;
    }
    res.json(buildInsights(params));
  })
);

// GET /anomalies -> SpendingAnomaly[]
analyticsRouter.get(
  "/anomalies",
  wrap(async (_req, res) => {
    const all = await loadAllTransactions();
    const anomalies = detectAnomalies({
      transactions: all.filter((t) => t.type === "expense"),
      history: all,
    });
    res.json(
      anomalies.map((a) => ({
        transaction: transactionJson(a.transaction),
        zScore: a.zScore,
        categoryMean: a.categoryMean,
        timesTypical: a.timesTypical,
      }))
    );
  })
);

// GET /forecast -> { month: MonthForecast, budgets: BudgetForecast[] }
analyticsRouter.get(
  "/forecast",
  wrap(async (_req, res) => {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const monthEnd = new Date(
      now.getFullYear(),
      now.getMonth() + 1,
      0,
      23,
      59,
      59
    );
    const [all, recurring, budgets] = await Promise.all([
      loadAllTransactions(),
      loadAllRecurring(),
      loadAllBudgets(),
    ]);
    const monthTransactions = all.filter(
      (t) =>
        t.date.getTime() >= monthStart.getTime() &&
        t.date.getTime() <= monthEnd.getTime()
    );
    const month = forecastMonth({ monthTransactions, recurring, now });
    const budgetForecasts = budgets.map((b) => {
      const f = forecastBudget({
        budget: b,
        monthTransactions,
        recurring,
        now,
      });
      return {
        budget: budgetJson(f.budget),
        spentSoFar: f.spentSoFar,
        remainingRecurring: f.remainingRecurring,
        projectedDiscretionary: f.projectedDiscretionary,
        projectedTotal: f.projectedTotal,
        projectedToExceed: f.projectedToExceed,
        projectedOverBy: f.projectedOverBy,
      };
    });
    res.json({ month, budgets: budgetForecasts });
  })
);

// GET /categorize?description=&type= -> CategorySuggestion | null
analyticsRouter.get(
  "/categorize",
  wrap(async (req, res) => {
    const description =
      typeof req.query.description === "string" ? req.query.description : "";
    const type = parseType(req.query.type) ?? null;
    const [categories, history] = await Promise.all([
      loadAllCategories(),
      loadAllTransactions(),
    ]);
    const suggestion = suggestCategory({
      description,
      categories,
      history,
      type,
    });
    res.json(suggestion);
  })
);
