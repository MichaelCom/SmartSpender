import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { AnalyticsApi, BudgetsApi, CategoriesApi } from "../api/client";
import { useAsync } from "../hooks/useAsync";
import { useSettings } from "../context/SettingsContext";
import { CurrencyFormatter } from "../lib/currency";
import { monthStart, monthEnd, toIso, formatMonth } from "../lib/dates";
import { iconEmoji } from "../lib/icons";
import { Spinner, ErrorBanner, Empty } from "../components/common";
import { InsightCard } from "../components/InsightCard";
import { TransactionForm } from "../components/TransactionForm";

export function Dashboard() {
  const { currencySymbol, budgetAlertThreshold } = useSettings();
  const navigate = useNavigate();
  const [showAdd, setShowAdd] = useState(false);
  const [reloadKey, setReloadKey] = useState(0);

  const from = toIso(monthStart());
  const to = toIso(monthEnd());

  const summary = useAsync(() => AnalyticsApi.summary(from, to), [from, to, reloadKey]);
  const byCat = useAsync(
    () => AnalyticsApi.expensesByCategory(from, to),
    [from, to, reloadKey],
  );
  const topInsight = useAsync(() => AnalyticsApi.topInsight(), [reloadKey]);
  const budgets = useAsync(() => BudgetsApi.list(), [reloadKey]);
  const forecast = useAsync(() => AnalyticsApi.forecast(), [reloadKey]);
  const categories = useAsync(() => CategoriesApi.list(), []);

  const fmt = (n: number) => CurrencyFormatter.format(currencySymbol, n);

  const topCategories = Object.entries(byCat.data ?? {})
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5);

  const budgetAlerts = (budgets.data ?? [])
    .map((b) => {
      const f = forecast.data?.budgets.find((x) => x.budget.id === b.id);
      const spent = f?.spentSoFar ?? 0;
      const pct = b.amount > 0 ? (spent / b.amount) * 100 : 0;
      return { budget: b, spent, pct, exceeded: spent > b.amount };
    })
    .filter((x) => x.exceeded || x.pct >= budgetAlertThreshold)
    .sort((a, b) => b.pct - a.pct);

  const loading = summary.loading || byCat.loading;

  return (
    <>
      <div className="spread">
        <div>
          <h1 className="page-title">Dashboard</h1>
          <p className="page-sub">{formatMonth(new Date())}</p>
        </div>
        <button className="btn primary" onClick={() => setShowAdd(true)}>
          + Quick add
        </button>
      </div>

      <ErrorBanner message={summary.error || byCat.error} />

      {loading ? (
        <Spinner />
      ) : (
        <>
          <div className="stat-grid">
            <div className="stat">
              <div className="label">Income</div>
              <div className="value income">{fmt(summary.data?.income ?? 0)}</div>
            </div>
            <div className="stat">
              <div className="label">Expenses</div>
              <div className="value expense">{fmt(summary.data?.expenses ?? 0)}</div>
            </div>
            <div className="stat hero">
              <div className="label">Balance</div>
              <div className="value">{fmt(summary.data?.balance ?? 0)}</div>
            </div>
          </div>

          {topInsight.data && (
            <div className="section-gap">
              <InsightCard
                insight={topInsight.data}
                onClick={() => navigate("/reports?tab=insights")}
              />
            </div>
          )}

          <div className="grid-2 section-gap">
            <div className="card">
              <h2 className="card-title">Top categories</h2>
              {topCategories.length === 0 ? (
                <Empty text="No expenses this month." />
              ) : (
                <div className="list">
                  {topCategories.map(([name, amount]) => (
                    <div className="list-item" key={name}>
                      <div className="grow">
                        <div className="title">{name}</div>
                      </div>
                      <div className="amount expense">{fmt(amount)}</div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="card">
              <h2 className="card-title">Budget alerts</h2>
              {budgets.loading ? (
                <Spinner />
              ) : budgetAlerts.length === 0 ? (
                <Empty text="All budgets on track." />
              ) : (
                <div className="list">
                  {budgetAlerts.map(({ budget, spent, pct, exceeded }) => (
                    <div className="list-item" key={budget.id}>
                      <div
                        className="icon-chip"
                        style={{ background: budget.categoryColor ?? "#888" }}
                      >
                        {iconEmoji(budget.categoryIcon)}
                      </div>
                      <div className="grow">
                        <div className="title">{budget.categoryName ?? "Budget"}</div>
                        <div className="sub">
                          {fmt(spent)} / {fmt(budget.amount)} ({Math.round(pct)}%)
                        </div>
                      </div>
                      <span className={`badge`} style={{ color: exceeded ? "var(--expense)" : "var(--warning)" }}>
                        {exceeded ? "Over" : "Nearing"}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </>
      )}

      {showAdd && categories.data && (
        <TransactionForm
          categories={categories.data}
          onClose={() => setShowAdd(false)}
          onSaved={() => {
            setShowAdd(false);
            setReloadKey((k) => k + 1);
          }}
        />
      )}
    </>
  );
}
