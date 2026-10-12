import { useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { Insight, Transaction } from "../api/types";
import { AnalyticsApi, BudgetsApi, TransactionsApi } from "../api/client";
import { useAsync } from "../hooks/useAsync";
import { useSettings } from "../context/SettingsContext";
import { CurrencyFormatter } from "../lib/currency";
import { monthEnd, monthStart, toIso } from "../lib/dates";
import { iconEmoji } from "../lib/icons";
import { Spinner, ErrorBanner, Empty } from "../components/common";
import { InsightCard } from "../components/InsightCard";

type TabId = "overview" | "trends" | "categories" | "budget" | "insights";

const TABS: { id: TabId; label: string; icon: string }[] = [
  { id: "overview", label: "Overview", icon: "🥧" },
  { id: "trends", label: "Trends", icon: "📈" },
  { id: "categories", label: "Categories", icon: "🏷️" },
  { id: "budget", label: "Budget", icon: "🎯" },
  { id: "insights", label: "Insights", icon: "💡" },
];

const PIE_COLORS = [
  "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
  "#DDA0DD", "#98D8C8", "#F7DC6F", "#2ECC71", "#3498DB",
  "#9B59B6", "#E74C3C", "#F39C12", "#1ABC9C", "#34495E",
];

export function Reports() {
  const [params, setParams] = useSearchParams();
  const initialTab = (params.get("tab") as TabId) || "overview";
  const [tab, setTab] = useState<TabId>(
    TABS.some((t) => t.id === initialTab) ? initialTab : "overview",
  );

  const selectTab = (id: TabId) => {
    setTab(id);
    const next = new URLSearchParams(params);
    next.set("tab", id);
    setParams(next, { replace: true });
  };

  return (
    <>
      <h1 className="page-title">Reports</h1>
      <p className="page-sub">Insights into your spending</p>

      <div className="tabs">
        {TABS.map((t) => (
          <button
            key={t.id}
            className={`tab${tab === t.id ? " active" : ""}`}
            onClick={() => selectTab(t.id)}
          >
            {t.icon} {t.label}
          </button>
        ))}
      </div>

      {tab === "overview" && <OverviewTab />}
      {tab === "trends" && <TrendsTab />}
      {tab === "categories" && <CategoriesTab />}
      {tab === "budget" && <BudgetTab />}
      {tab === "insights" && <InsightsTab />}
    </>
  );
}

function useMonthByCategory() {
  const from = toIso(monthStart());
  const to = toIso(monthEnd());
  const summary = useAsync(() => AnalyticsApi.summary(from, to), [from, to]);
  const byCat = useAsync(() => AnalyticsApi.expensesByCategory(from, to), [from, to]);
  return { summary, byCat };
}

function OverviewTab() {
  const { currencySymbol } = useSettings();
  const { summary, byCat } = useMonthByCategory();
  const fmt = (n: number) => CurrencyFormatter.format(currencySymbol, n);

  if (summary.loading || byCat.loading) return <Spinner />;
  if (summary.error) return <ErrorBanner message={summary.error} />;

  const pieData = Object.entries(byCat.data ?? {})
    .filter(([, v]) => v > 0)
    .map(([name, value]) => ({ name, value }));

  const incomeVsExpense = [
    { name: "Income", value: summary.data?.income ?? 0 },
    { name: "Expenses", value: summary.data?.expenses ?? 0 },
  ];

  return (
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
        <div className="stat">
          <div className="label">Balance</div>
          <div className="value">{fmt(summary.data?.balance ?? 0)}</div>
        </div>
      </div>

      <div className="card section-gap">
        <h2 className="card-title">Income vs Expenses</h2>
        <ResponsiveContainer width="100%" height={240}>
          <BarChart data={incomeVsExpense}>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
            <XAxis dataKey="name" stroke="var(--text-muted)" />
            <YAxis
              stroke="var(--text-muted)"
              tickFormatter={(v) => CurrencyFormatter.formatCompact(currencySymbol, Number(v))}
            />
            <Tooltip formatter={(v) => fmt(Number(v))} />
            <Bar dataKey="value" radius={[6, 6, 0, 0]}>
              <Cell fill="var(--income)" />
              <Cell fill="var(--expense)" />
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div className="card section-gap">
        <h2 className="card-title">Expenses by category</h2>
        {pieData.length === 0 ? (
          <Empty text="No expenses this month." />
        ) : (
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={pieData}
                dataKey="value"
                nameKey="name"
                outerRadius={110}
                label={(e) => `${((e.percent ?? 0) * 100).toFixed(1)}%`}
              >
                {pieData.map((_, i) => (
                  <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                ))}
              </Pie>
              <Tooltip formatter={(v) => fmt(Number(v))} />
              <Legend />
            </PieChart>
          </ResponsiveContainer>
        )}
      </div>
    </>
  );
}

/** Groups transactions into the last 6 months of income/expense totals. */
function monthlyTrend(transactions: Transaction[]): {
  month: string;
  income: number;
  expenses: number;
}[] {
  const now = new Date();
  const buckets: { key: string; label: string; income: number; expenses: number }[] = [];
  for (let i = 5; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    buckets.push({
      key: `${d.getFullYear()}-${d.getMonth()}`,
      label: d.toLocaleString(undefined, { month: "short" }),
      income: 0,
      expenses: 0,
    });
  }
  const idx = new Map(buckets.map((b, i) => [b.key, i]));
  for (const t of transactions) {
    const d = new Date(t.date);
    const key = `${d.getFullYear()}-${d.getMonth()}`;
    const i = idx.get(key);
    if (i == null) continue;
    if (t.type === "income") buckets[i].income += t.amount;
    else buckets[i].expenses += t.amount;
  }
  return buckets.map((b) => ({ month: b.label, income: b.income, expenses: b.expenses }));
}

function TrendsTab() {
  const { currencySymbol } = useSettings();
  const from = toIso(new Date(new Date().getFullYear(), new Date().getMonth() - 5, 1));
  const to = toIso(monthEnd());
  const txns = useAsync(() => TransactionsApi.list({ from, to }), [from, to]);
  const fmt = (n: number) => CurrencyFormatter.format(currencySymbol, n);

  if (txns.loading) return <Spinner />;
  if (txns.error) return <ErrorBanner message={txns.error} />;

  const data = monthlyTrend(txns.data ?? []);
  const hasData = data.some((d) => d.income > 0 || d.expenses > 0);

  return (
    <div className="card">
      <h2 className="card-title">Last 6 months</h2>
      {!hasData ? (
        <Empty text="Not enough data to show trends." />
      ) : (
        <ResponsiveContainer width="100%" height={320}>
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
            <XAxis dataKey="month" stroke="var(--text-muted)" />
            <YAxis
              stroke="var(--text-muted)"
              tickFormatter={(v) => CurrencyFormatter.formatCompact(currencySymbol, Number(v))}
            />
            <Tooltip formatter={(v) => fmt(Number(v))} />
            <Legend />
            <Line type="monotone" dataKey="income" stroke="var(--income)" strokeWidth={2} name="Income" />
            <Line type="monotone" dataKey="expenses" stroke="var(--expense)" strokeWidth={2} name="Expenses" />
          </LineChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}

function CategoriesTab() {
  const { currencySymbol } = useSettings();
  const { byCat } = useMonthByCategory();
  const fmt = (n: number) => CurrencyFormatter.format(currencySymbol, n);

  const entries = useMemo(
    () =>
      Object.entries(byCat.data ?? {})
        .filter(([, v]) => v > 0)
        .sort((a, b) => b[1] - a[1]),
    [byCat.data],
  );
  const total = entries.reduce((s, [, v]) => s + v, 0);

  if (byCat.loading) return <Spinner />;
  if (byCat.error) return <ErrorBanner message={byCat.error} />;

  const pieData = entries.map(([name, value]) => ({ name, value }));

  return (
    <>
      <div className="card">
        <h2 className="card-title">Category breakdown</h2>
        {pieData.length === 0 ? (
          <Empty text="No expenses this month." />
        ) : (
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={pieData}
                dataKey="value"
                nameKey="name"
                outerRadius={110}
                label={(e) => `${((e.percent ?? 0) * 100).toFixed(1)}%`}
              >
                {pieData.map((_, i) => (
                  <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                ))}
              </Pie>
              <Tooltip formatter={(v) => fmt(Number(v))} />
            </PieChart>
          </ResponsiveContainer>
        )}
      </div>

      {entries.length > 0 && (
        <div className="card section-gap">
          <h2 className="card-title">Details</h2>
          <div className="list">
            {entries.map(([name, value], i) => (
              <div className="list-item" key={name}>
                <div
                  className="icon-chip"
                  style={{ background: PIE_COLORS[i % PIE_COLORS.length] }}
                >
                  {iconEmoji()}
                </div>
                <div className="grow">
                  <div className="title">{name}</div>
                  <div className="sub">
                    {total > 0 ? ((value / total) * 100).toFixed(1) : "0"}% of expenses
                  </div>
                </div>
                <div className="amount expense">{fmt(value)}</div>
              </div>
            ))}
          </div>
        </div>
      )}
    </>
  );
}

function BudgetTab() {
  const { currencySymbol } = useSettings();
  const budgets = useAsync(() => BudgetsApi.list(), []);
  const forecast = useAsync(() => AnalyticsApi.forecast(), []);
  const fmt = (n: number) => CurrencyFormatter.format(currencySymbol, n);

  if (budgets.loading) return <Spinner />;
  if (budgets.error) return <ErrorBanner message={budgets.error} />;
  if ((budgets.data ?? []).length === 0)
    return (
      <div className="card">
        <Empty text="No budgets to report on." />
      </div>
    );

  return (
    <div className="list">
      {budgets.data!.map((b) => {
        const f = forecast.data?.budgets.find((x) => x.budget.id === b.id);
        const spent = f?.spentSoFar ?? 0;
        const pct = b.amount > 0 ? (spent / b.amount) * 100 : 0;
        const over = spent > b.amount;
        return (
          <div className="card" key={b.id} style={{ marginTop: 12 }}>
            <div className="spread" style={{ marginBottom: 8 }}>
              <div className="title">{b.categoryName ?? "Budget"}</div>
              <div className={`amount ${over ? "expense" : "income"}`}>
                {fmt(spent)} / {fmt(b.amount)}
              </div>
            </div>
            <div className="progress">
              <div
                className="bar"
                style={{
                  width: `${Math.min(pct, 100)}%`,
                  background: over ? "var(--expense)" : "var(--income)",
                }}
              />
            </div>
            <div className="muted" style={{ marginTop: 6, fontSize: 12 }}>
              {Math.round(pct)}% used
            </div>
          </div>
        );
      })}
    </div>
  );
}

function InsightsTab() {
  const insights = useAsync(() => AnalyticsApi.insights(), []);

  if (insights.loading) return <Spinner />;
  if (insights.error) return <ErrorBanner message={insights.error} />;

  const list: Insight[] = insights.data ?? [];
  if (list.length === 0)
    return (
      <div className="card">
        <Empty text="No insights yet. Add more transactions to see insights." />
      </div>
    );

  return (
    <div className="list">
      {list.map((ins, i) => (
        <div key={i} style={{ marginBottom: 12 }}>
          <InsightCard insight={ins} />
        </div>
      ))}
    </div>
  );
}
