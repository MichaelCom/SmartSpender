import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { AnalyticsApi, BudgetsApi, CategoriesApi, TransactionsApi } from "../api/client";
import { useAsync } from "../hooks/useAsync";
import { useSettings } from "../context/SettingsContext";
import { CurrencyFormatter } from "../lib/currency";
import { monthStart, monthEnd, toIso, formatMonth } from "../lib/dates";
import { iconEmoji } from "../lib/icons";
import {
  Spinner,
  ErrorBanner,
  Empty,
  Donut,
  Sparkline,
  StatTile,
  ProgressBar,
  Badge,
} from "../components/common";
import { InsightCard } from "../components/InsightCard";
import { TransactionForm } from "../components/TransactionForm";

/** Legend/donut colours — resolved via tokens by the shared Donut, but the
 *  category series uses this fixed ramp (contract §CHARTS). */
const CAT_COLORS = ["#10b981", "#3b82f6", "#f59e0b", "#8b5cf6", "#64748b"];

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
  const recent = useAsync(
    () => TransactionsApi.list({ from, to }),
    [from, to, reloadKey],
  );

  const fmt = (n: number) => CurrencyFormatter.format(currencySymbol, n);
  const fmtSigned = (n: number, income: boolean) =>
    CurrencyFormatter.formatSigned(currencySymbol, n, income);

  const income = summary.data?.income ?? 0;
  const expenses = summary.data?.expenses ?? 0;
  const balance = summary.data?.balance ?? 0;
  const savingsRate = income > 0 ? (balance / income) * 100 : 0;

  // Donut data — top 5 categories + "Other".
  const donutData = useMemo(() => {
    const entries = Object.entries(byCat.data ?? {})
      .filter(([, v]) => v > 0)
      .sort((a, b) => b[1] - a[1]);
    const top = entries.slice(0, 5);
    const otherTotal = entries.slice(5).reduce((s, [, v]) => s + v, 0);
    const data = top.map(([label, value], i) => ({
      label,
      value,
      color: CAT_COLORS[i % CAT_COLORS.length],
    }));
    if (otherTotal > 0) {
      data.push({ label: "Other", value: otherTotal, color: "#64748b" });
    }
    return data;
  }, [byCat.data]);

  // 30-day spend flow for the hero sparkline (bucketed by day of month).
  const sparkValues = useMemo(() => {
    const days = monthEnd().getDate();
    const buckets = new Array(days).fill(0);
    for (const t of recent.data ?? []) {
      if (t.type !== "expense") continue;
      const d = new Date(t.date).getDate() - 1;
      if (d >= 0 && d < days) buckets[d] += t.amount;
    }
    return buckets;
  }, [recent.data]);

  const budgetAlerts = (budgets.data ?? [])
    .map((b) => {
      const f = forecast.data?.budgets.find((x) => x.budget.id === b.id);
      const spent = f?.spentSoFar ?? 0;
      const pct = b.amount > 0 ? (spent / b.amount) * 100 : 0;
      const exceeded = spent > b.amount;
      const nearing = !exceeded && pct >= budgetAlertThreshold;
      return { budget: b, spent, pct, exceeded, nearing };
    })
    .filter((x) => x.exceeded || x.nearing)
    .sort((a, b) => b.pct - a.pct)
    .slice(0, 4);

  const recentRows = (recent.data ?? [])
    .slice()
    .sort((a, b) => +new Date(b.date) - +new Date(a.date))
    .slice(0, 6);

  const loading = summary.loading || byCat.loading;

  return (
    <>
      <div className="spread">
        <div>
          <h1 className="page-title">Dashboard</h1>
          <p className="page-sub">{formatMonth(new Date())} · Overview</p>
        </div>
        <div className="header-actions">
          <button className="btn primary" onClick={() => setShowAdd(true)}>
            ＋ Quick add
          </button>
        </div>
      </div>

      <ErrorBanner message={summary.error || byCat.error} />

      {loading ? (
        <Spinner />
      ) : (
        <>
          {/* Hero balance */}
          <section className="hero">
            <div className="inner">
              <div>
                <div className="lbl">Balance remaining</div>
                <div className="bal">{fmt(balance)}</div>
                <span className="delta">
                  {balance >= 0 ? "▲" : "▼"}{" "}
                  {income > 0 ? Math.round((balance / income) * 100) : 0}% of income kept
                </span>
              </div>
              <div className="hero-split">
                <div className="hero-mini">
                  <div className="lbl">Income</div>
                  <div className="v">{fmt(income)}</div>
                </div>
                <div className="hero-mini">
                  <div className="lbl">Spent</div>
                  <div className="v">{fmt(expenses)}</div>
                </div>
                <div className="hero-mini">
                  <div className="lbl">30-day flow</div>
                  <Sparkline values={sparkValues} />
                </div>
              </div>
            </div>
          </section>

          {/* Stat tiles */}
          <div className="stat-grid">
            <StatTile label="Income" value={fmt(income)} icon="↓" iconKind="inc" />
            <StatTile label="Expenses" value={fmt(expenses)} icon="↑" iconKind="exp" />
            <StatTile
              label="Savings rate"
              value={`${savingsRate.toFixed(1)}%`}
              icon="◎"
              iconKind="sav"
            />
            <StatTile
              label="Balance"
              value={fmt(balance)}
              icon="∑"
              iconKind="info"
            />
          </div>

          {topInsight.data && (
            <InsightCard
              insight={topInsight.data}
              onClick={() => navigate("/reports?tab=insights")}
            />
          )}

          {/* Two-column: donut + budget alerts */}
          <div className="grid-2">
            <div className="card dash-donut-card">
              <div className="card-head">
                <h2 className="card-title">Spending by category</h2>
                <a className="link" onClick={() => navigate("/reports")}>
                  View report →
                </a>
              </div>
              {donutData.length === 0 ? (
                <Empty text="No expenses this month." />
              ) : (
                <>
                  <div className="donut-total">
                    <span className="s">Total spent</span>
                    <span className="b">{fmt(expenses)}</span>
                  </div>
                  <div className="donut-wrap">
                    <Donut data={donutData} formatValue={fmt} size={170} />
                    <div className="legend">
                      {donutData.map((d) => (
                        <div className="leg" key={d.label}>
                          <span className="dot" style={{ background: d.color }} />
                          <span className="nm">{d.label}</span>
                          <span className="vl">{fmt(d.value)}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                </>
              )}
            </div>

            <div className="card">
              <div className="card-head">
                <h2 className="card-title">Budget alerts</h2>
                <a className="link" onClick={() => navigate("/budgets")}>
                  Manage →
                </a>
              </div>
              {budgets.loading ? (
                <Spinner />
              ) : budgetAlerts.length === 0 ? (
                <Empty text="All budgets on track." />
              ) : (
                <div className="list">
                  {budgetAlerts.map(({ budget, spent, pct, exceeded, nearing }) => (
                    <div className="bud" key={budget.id}>
                      <div className="line">
                        <span
                          className="chip-ic"
                          style={{
                            background: budget.categoryColor ?? "#888",
                            width: 28,
                            height: 28,
                            fontSize: 14,
                          }}
                        >
                          {iconEmoji(budget.categoryIcon)}
                        </span>
                        <span className="nm">{budget.categoryName ?? "Budget"}</span>
                        <Badge kind={exceeded ? "over" : nearing ? "near" : "ok"}>
                          {exceeded ? "Over" : nearing ? "Nearing" : "On track"}
                        </Badge>
                      </div>
                      <ProgressBar
                        value={spent}
                        max={budget.amount}
                        state={exceeded ? "over" : nearing ? "near" : "ok"}
                      />
                      <div className="meta">
                        <span>
                          {fmt(spent)} / {fmt(budget.amount)}
                        </span>
                        <span>{Math.round(pct)}%</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Recent transactions */}
          <div className="card" style={{ marginTop: 18 }}>
            <div className="card-head">
              <h2 className="card-title">Recent transactions</h2>
              <a className="link" onClick={() => navigate("/transactions")}>
                See all →
              </a>
            </div>
            {recent.loading ? (
              <Spinner />
            ) : recentRows.length === 0 ? (
              <Empty text="No transactions this month." />
            ) : (
              <div className="list">
                {recentRows.map((t) => (
                  <div className="row" key={t.id}>
                    <span
                      className="chip-ic"
                      style={{ background: t.categoryColor ?? "#64748b" }}
                    >
                      {iconEmoji(t.categoryIcon)}
                    </span>
                    <div className="grow">
                      <div className="t">
                        {t.description?.trim() || t.categoryName || "Transaction"}
                      </div>
                      <div className="sub">
                        {t.categoryName ?? "Uncategorised"} ·{" "}
                        {new Date(t.date).toLocaleDateString(undefined, {
                          day: "numeric",
                          month: "short",
                        })}
                      </div>
                    </div>
                    <span className={`amount ${t.type}`}>
                      {fmtSigned(t.amount, t.type === "income")}
                    </span>
                  </div>
                ))}
              </div>
            )}
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
