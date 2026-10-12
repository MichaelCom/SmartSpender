import cors from "cors";
import express from "express";
import { analyticsRouter } from "./routes/analytics";
import { bridgeRouter } from "./routes/bridge";
import { budgetsRouter } from "./routes/budgets";
import { categoriesRouter } from "./routes/categories";
import { recurringRouter } from "./routes/recurring";
import { transactionsRouter } from "./routes/transactions";

export function createApp() {
  const app = express();

  // CORS: allow the frontend origin (configurable; defaults to the Vite dev
  // server). Set CORS_ORIGIN=* to allow any origin.
  const origin = process.env.CORS_ORIGIN ?? "http://localhost:5173";
  app.use(
    cors({
      origin: origin === "*" ? true : origin.split(",").map((s) => s.trim()),
    })
  );

  app.use(express.json({ limit: "25mb" }));

  app.get("/health", (_req, res) => {
    res.json({ status: "ok" });
  });

  app.use("/categories", categoriesRouter);
  app.use("/transactions", transactionsRouter);
  app.use("/budgets", budgetsRouter);
  app.use("/recurring", recurringRouter);
  // analytics + bridge mount their own full paths at the root.
  app.use("/", analyticsRouter);
  app.use("/", bridgeRouter);

  // Unknown route -> JSON 404.
  app.use((_req, res) => {
    res.status(404).json({ error: "Not found" });
  });

  return app;
}
