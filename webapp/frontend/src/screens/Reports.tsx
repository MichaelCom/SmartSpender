import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
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
import { Spinner, ErrorBanner, Empty, Donut } from "../components/common";
import { InsightCard } from "../components/InsightCard";

type TabId = "overview" | "trends" | "categories" | "budget" | "insights";

const TABS: { id: TabId; label: string; icon: string }[] = [
  { id: "overview", label: "Overview", icon: "🥝" },
  { id: "trends", label: "Trends", icon: "📈" },
  { id: "categories", label: "Categories", icon: "🏷️" },
  { id: "budget", label: "Budget", icon: "🎯" },
  { id: "insights", label: "Insights", icon: "💡" },
];

/** Fixed category colour ramp (contract §CHARTS). */
const CAT_COLORS = ["#10b981", "#3b82f6", "#f59e0b", "#8b5cf6", "#64748b"];

/**
 * Resolves theme tokens to concrete colours at render, re-resolving whenever
 * the palette or mode changes so charts re-theme. Reads from the <html>
 * computed style the same way the mockup does.
 */
function useChartColors() {
  const { palette, themeMode } = useSettings();
  const [tick, setTick] = useState(0);

  // Re-resolve shortly after a theme/palette change (CSS vars settle sync, but
  // a microtask guards against transition timing).
  useEffect(() => {
    const id = window.setTimeout(() => setTick((t) => t + 1), 20);
    return () => window.clearTimeout(id);
  }, [palette, themeMode]);

  return useMemo(() => {
    const get = (v: string) =>
      getComputedStyle(document.documentElement).getPropertyValue(v).trim();
    return {
      primary: get("--primary") || "#10b981",
      income: get("--income") || "#16b364",
      expense: get("--expense") || "#ef4444",
      warning: get("--warning") || "#f59e0b",
      border: get("--border") || "#e4e8ef",
      textMuted: get("--text-muted") || "#64748b",
      text: get("--text") || "#0f172a",
      surface: get("--surface") || "#fff",
      surface3: get("--surface-3") || "#e9edf3",
      cats: CAT_COLORS,
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [palette, themeMode, tick]);
}

type ChartColors = ReturnType<typeof useChartColors>;
type TooltipRow = { name?: string; value?: number; dataKey?: string; payload?: any };

/**
 * Builds a Recharts custom tooltip whose values are coloured by semantic
 * meaning. `colorFor(row, c)` returns the colour for each row's value; return
 * null to use the default text colour.
 */
function makeSemanticTooltip(
  c: ChartColors,
  fmt: (n: number) => string,
  colorFor: (row: TooltipRow, c: ChartColors) => string | null,
) {
  return function SemanticTooltip({ active, payload, label }: any) {
    if (!active || !payload || payload.length === 0) return null;
    return (
      <div
        style={{
          background: c.surface,
          border: `1px solid ${c.border}`,
          borderRadius: 10,
          padding: "8px 11px",
          boxShadow: "0 6px 20px rgba(0,0,0,.12)",
          fontSize: 13,
        }}
      >
        {label != null && (
          <div style={{ color: c.text, fontWeight: 700, marginBottom: 4 }}>
            {label}
          </div>
        )}
        {(payload as TooltipRow[]).map((row, i) => (
          <div
            key={i}
            style={{
              display: "flex",
              justifyContent: "space-between",
              gap: 16,
              color: c.text,
            }}
          >
            <span style={{ color: c.textMuted }}>{row.name}</span>
            <span
              style={{
                fontWeight: 700,
                fontVariantNumeric: "tabular-nums",
                color: colorFor(row, c) ?? c.text,
              }}
            >
              {fmt(Number(row.value ?? 0))}
            </span>
          </div>
        ))}
      </div>
    );
  };
}

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

function useLast6Months() {
  const from = toIso(new Date(new Date().getFullYear(), new Date().getMonth() - 5, 1));
  const to = toIso(monthEnd());
  return useAsync(() => TransactionsApi.list({ from, to }), [from, to]);
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

function useMonthByCategory() {
  const from = toIso(monthStart());
  const to = toIso(monthEnd());
  const summary = useAsync(() => AnalyticsApi.summary(from, to), [from, to]);
  const byCat = useAsync(() => AnalyticsApi.expensesByCategory(from, to), [from, to]);
  return { summary, byCat };
}

function ChartBox({ children }: { children: React.ReactNode }) {
  return (
    <div className="chart-box">
      <ResponsiveContainer width="100%" height={300}>
        {children as React.ReactElement}
      </ResponsiveContainer>
    </div>
  );
}

function OverviewTab() {
  const { currencySymbol } = useSettings();
  const c = useChartColors();
  const txns = useLast6Months();
  const { summary } = useMonthByCategory();
  const { byCat: byCatMonth } = useMonthByCategoryMemo();
  const fmt = (n: number) => CurrencyFormatter.format(currencySymbol, n);

  if (txns.loading || summary.loading) return <Spinner />;
  if (txns.error) return <ErrorBanner message={txns.error} />;

  const data = monthlyTrend(txns.data ?? []);
  const months = data.filter((d) => d.income > 0 || d.expenses > 0).length;
  const totalExpenses = data.reduce((s, d) => s + d.expenses, 0);
  const avgSpend = months > 0 ? totalExpenses / months : 0;
  const totalIncome = data.reduce((s, d) => s + d.income, 0);
  const avgSavings =
    totalIncome > 0 ? ((totalIncome - totalExpenses) / totalIncome) * 100 : 0;

  // Highest category this month.
  const highest =
    Object.entries(byCatMonth).sort((a, b) => b[1] - a[1])[0]?.[0] ?? "—";

  const hasData = data.some((d) => d.income > 0 || d.expenses > 0);

  return (
    <>
      <div className="stat-grid">
        <div className="card">
          <div className="muted" style={{ fontSize: 13, fontWeight: 600 }}>
            Avg monthly spend
          </div>
          <div style={{ fontSize: 24, fontWeight: 800, marginTop: 8 }}>
            {fmt(avgSpend)}
          </div>
        </div>
        <div className="card">
          <div className="muted" style={{ fontSize: 13, fontWeight: 600 }}>
            Highest category
          </div>
          <div style={{ fontSize: 24, fontWeight: 800, marginTop: 8 }}>
            {highest}
          </div>
        </div>
        <div className="card">
          <div className="muted" style={{ fontSize: 13, fontWeight: 600 }}>
            Avg savings rate
          </div>
          <div
            style={{
              fontSize: 24,
              fontWeight: 800,
              marginTop: 8,
              color: "var(--income)",
            }}
          >
            {avgSavings.toFixed(0)}%
          </div>
        </div>
      </div>

      <div className="card section-gap">
        <div className="card-head">
          <h2 className="card-title">Income vs expenses</h2>
          <span className="muted" style={{ fontSize: 12 }}>
            Last 6 months
          </span>
        </div>
        {!hasData ? (
          <Empty text="Not enough data to show a chart." />
        ) : (
          <ChartBox>
            <BarChart data={data}>
              <CartesianGrid strokeDasharray="3 3" stroke={c.border} />
              <XAxis dataKey="month" stroke={c.textMuted} />
              <YAxis
                stroke={c.textMuted}
                tickFormatter={(v) =>
                  CurrencyFormatter.formatCompact(currencySymbol, Number(v))
                }
              />
              <Tooltip
                content={makeSemanticTooltip(c, fmt, (row) =>
                  row.dataKey === "income" ? c.income : c.expense
                )}
              />
              <Legend />
              <Bar dataKey="income" name="Income" fill={c.income} radius={[5, 5, 0, 0]} />
              <Bar
                dataKey="expenses"
                name="Expenses"
                fill={c.expense}
                radius={[5, 5, 0, 0]}
              />
            </BarChart>
          </ChartBox>
        )}
      </div>
    </>
  );
}

/** Current-month expenses-by-category as a plain object (for the overview stat). */
function useMonthByCategoryMemo(): { byCat: Record<string, number> } {
  const from = toIso(monthStart());
  const to = toIso(monthEnd());
  const byCat = useAsync(() => AnalyticsApi.expensesByCategory(from, to), [from, to]);
  return { byCat: byCat.data ?? {} };
}

function dailySpend(transactions: Transaction[]): { day: string; spend: number }[] {
  const days = monthEnd().getDate();
  const buckets = new Array(days).fill(0);
  const ms = monthStart();
  const me = monthEnd();
  for (const t of transactions) {
    if (t.type !== "expense") continue;
    const d = new Date(t.date);
    if (d < ms || d > me) continue;
    const idx = d.getDate() - 1;
    if (idx >= 0 && idx < days) buckets[idx] += t.amount;
  }
  return buckets.map((spend, i) => ({ day: String(i + 1), spend }));
}

function TrendsTab() {
  const { currencySymbol } = useSettings();
  const c = useChartColors();
  const txns = useLast6Months();
  const fmt = (n: number) => CurrencyFormatter.format(currencySymbol, n);

  if (txns.loading) return <Spinner />;
  if (txns.error) return <ErrorBanner message={txns.error} />;

  const trend = monthlyTrend(txns.data ?? []);
  // 3-month trailing average of spending.
  const withAvg = trend.map((d, i) => {
    if (i < 2) return { ...d, avg: null as number | null };
    const avg = (trend[i].expenses + trend[i - 1].expenses + trend[i - 2].expenses) / 3;
    return { ...d, avg };
  });
  const hasData = trend.some((d) => d.income > 0 || d.expenses > 0);
  const daily = dailySpend(txns.data ?? []);
  const hasDaily = daily.some((d) => d.spend > 0);

  return (
    <>
      <div className="card">
        <div className="card-head">
          <h2 className="card-title">Monthly spending trend</h2>
          <span className="muted" style={{ fontSize: 12 }}>
            with 3-month average
          </span>
        </div>
        {!hasData ? (
          <Empty text="Not enough data to show trends." />
        ) : (
          <ChartBox>
            <AreaChart data={withAvg}>
              <CartesianGrid strokeDasharray="3 3" stroke={c.border} />
              <XAxis dataKey="month" stroke={c.textMuted} />
              <YAxis
                stroke={c.textMuted}
                tickFormatter={(v) =>
                  CurrencyFormatter.formatCompact(currencySymbol, Number(v))
                }
              />
              <Tooltip
                content={makeSemanticTooltip(c, fmt, () => c.expense)}
              />
              <Legend />
              <Area
                type="monotone"
                dataKey="expenses"
                name="Spending"
                stroke={c.primary}
                fill={c.primary}
                fillOpacity={0.18}
                strokeWidth={2}
              />
              <Line
                type="monotone"
                dataKey="avg"
                name="3-mo avg"
                stroke={c.warning}
                strokeDasharray="5 4"
                strokeWidth={2}
                dot={false}
                connectNulls
              />
            </AreaChart>
          </ChartBox>
        )}
      </div>

      <div className="card section-gap">
        <div className="card-head">
          <h2 className="card-title">Daily spend — this month</h2>
        </div>
        {!hasDaily ? (
          <Empty text="No spending recorded this month yet." />
        ) : (
          <ChartBox>
            <BarChart data={daily}>
              <CartesianGrid strokeDasharray="3 3" stroke={c.border} />
              <XAxis dataKey="day" stroke={c.textMuted} />
              <YAxis
                stroke={c.textMuted}
                tickFormatter={(v) =>
                  CurrencyFormatter.formatCompact(currencySymbol, Number(v))
                }
              />
              <Tooltip
                content={makeSemanticTooltip(c, fmt, () => c.expense)}
              />
              <Bar dataKey="spend" name="Spend" fill={c.primary} radius={[3, 3, 0, 0]} />
            </BarChart>
          </ChartBox>
        )}
      </div>
    </>
  );
}

function CategoriesTab() {
  const { currencySymbol } = useSettings();
  const c = useChartColors();
  const { byCat } = useMonthByCategory();
  const fmt = (n: number) => CurrencyFormatter.format(currencySymbol, n);

  const entries = useMemo(
    () =>
      Object.entries(byCat.data ?? {})
        .filter(([, v]) => v > 0)
        .sort((a, b) => b[1] - a[1]),
    [byCat.data],
  );

  if (byCat.loading) return <Spinner />;
  if (byCat.error) return <ErrorBanner message={byCat.error} />;

  const top = entries.slice(0, 5);
  const otherTotal = entries.slice(5).reduce((s, [, v]) => s + v, 0);
  const donutData = top.map(([label, value], i) => ({
    label,
    value,
    color: c.cats[i % c.cats.length],
  }));
  if (otherTotal > 0) donutData.push({ label: "Other", value: otherTotal, color: "#64748b" });

  const barData = top.map(([name, value]) => ({ name, value }));

  if (entries.length === 0) {
    return (
      <div className="card">
        <Empty text="No expenses this month." />
      </div>
    );
  }

  return (
    <div className="grid-2">
      <div className="card">
        <div className="card-head">
          <h2 className="card-title">Spending by category</h2>
        </div>
        <div className="donut-total">
          <span className="s">Total</span>
          <span className="b">{fmt(donutData.reduce((s, d) => s + d.value, 0))}</span>
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
      </div>
      <div className="card">
        <div className="card-head">
          <h2 className="card-title">Top categories</h2>
        </div>
        <ChartBox>
          <BarChart data={barData} layout="vertical">
            <CartesianGrid strokeDasharray="3 3" stroke={c.border} />
            <XAxis
              type="number"
              stroke={c.textMuted}
              tickFormatter={(v) =>
                CurrencyFormatter.formatCompact(currencySymbol, Number(v))
              }
            />
            <YAxis type="category" dataKey="name" stroke={c.textMuted} width={90} />
            <Tooltip
              content={makeSemanticTooltip(c, fmt, () => c.expense)}
            />
            <Bar dataKey="value" name="Spend" radius={[0, 4, 4, 0]}>
              {barData.map((_, i) => (
                <Cell key={i} fill={c.cats[i % c.cats.length]} />
              ))}
            </Bar>
          </BarChart>
        </ChartBox>
      </div>
    </div>
  );
}

function BudgetTab() {
  const { currencySymbol } = useSettings();
  const c = useChartColors();
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

  const data = (budgets.data ?? []).map((b) => {
    const f = forecast.data?.budgets.find((x) => x.budget.id === b.id);
    return {
      name: b.categoryName ?? "Budget",
      budget: b.amount,
      actual: f?.spentSoFar ?? 0,
    };
  });

  return (
    <div className="card">
      <div className="card-head">
        <h2 className="card-title">Budget vs actual</h2>
      </div>
      <ChartBox>
        <BarChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke={c.border} />
          <XAxis dataKey="name" stroke={c.textMuted} />
          <YAxis
            stroke={c.textMuted}
            tickFormatter={(v) =>
              CurrencyFormatter.formatCompact(currencySymbol, Number(v))
            }
          />
          <Tooltip
            content={makeSemanticTooltip(c, fmt, (row) => {
              if (row.dataKey === "budget") return c.text;
              const bud = Number(row.payload?.budget ?? 0);
              const act = Number(row.value ?? 0);
              return act > bud ? c.expense : c.income;
            })}
          />
          <Legend />
          <Bar dataKey="budget" name="Budget" fill={c.surface3} radius={[4, 4, 0, 0]} />
          <Bar dataKey="actual" name="Actual" fill={c.primary} radius={[4, 4, 0, 0]} />
        </BarChart>
      </ChartBox>
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
    <div>
      {list.map((ins, i) => (
        <div key={i} className={i > 0 ? "section-gap" : undefined}>
          <InsightCard insight={ins} />
        </div>
      ))}
    </div>
  );
}
