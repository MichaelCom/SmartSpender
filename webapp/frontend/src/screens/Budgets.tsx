import { useMemo, useState } from "react";
import type { Budget, BudgetPeriod, Category } from "../api/types";
import { AnalyticsApi, BudgetsApi, CategoriesApi } from "../api/client";
import { useAsync } from "../hooks/useAsync";
import { useSettings } from "../context/SettingsContext";
import { CurrencyFormatter } from "../lib/currency";
import { daysElapsedInMonth, toDateInput, fromDateInput } from "../lib/dates";
import { iconEmoji } from "../lib/icons";
import {
  Spinner,
  ErrorBanner,
  Empty,
  ProgressBar,
  Badge,
} from "../components/common";
import { Modal } from "../components/Modal";

/** The month must have at least this many elapsed days before we show a
 *  forecast projection (parity: run-rate is noisy very early in the month). */
const FORECAST_MIN_DAYS = 4;

export function Budgets() {
  const { currencySymbol, budgetAlertThreshold } = useSettings();
  const [reloadKey, setReloadKey] = useState(0);
  const [editing, setEditing] = useState<Budget | null>(null);
  const [adding, setAdding] = useState(false);

  const budgets = useAsync(() => BudgetsApi.list(), [reloadKey]);
  const categories = useAsync(() => CategoriesApi.list("expense"), []);
  const forecast = useAsync(() => AnalyticsApi.forecast(), [reloadKey]);

  const fmt = (n: number) => CurrencyFormatter.format(currencySymbol, n);
  const showForecast = daysElapsedInMonth() >= FORECAST_MIN_DAYS;
  const refresh = () => setReloadKey((k) => k + 1);

  const del = async (b: Budget) => {
    if (!confirm("Delete this budget?")) return;
    await BudgetsApi.remove(b.id);
    refresh();
  };

  const rows = useMemo(
    () =>
      (budgets.data ?? []).map((b) => {
        const f = forecast.data?.budgets.find((x) => x.budget.id === b.id);
        const spent = f?.spentSoFar ?? 0;
        const pct = b.amount > 0 ? (spent / b.amount) * 100 : 0;
        const exceeded = spent > b.amount;
        const nearing = !exceeded && pct >= budgetAlertThreshold;
        const remaining = b.amount - spent;
        return { budget: b, forecast: f, spent, pct, exceeded, nearing, remaining };
      }),
    [budgets.data, forecast.data, budgetAlertThreshold],
  );

  const totals = useMemo(() => {
    const budgeted = rows.reduce((s, r) => s + r.budget.amount, 0);
    const spent = rows.reduce((s, r) => s + r.spent, 0);
    return { budgeted, spent, remaining: budgeted - spent };
  }, [rows]);

  return (
    <>
      <div className="spread">
        <div>
          <h1 className="page-title">Budgets</h1>
          <p className="page-sub">
            {rows.length} active {rows.length === 1 ? "budget" : "budgets"}
          </p>
        </div>
        <button className="btn primary" onClick={() => setAdding(true)}>
          ＋ New budget
        </button>
      </div>

      <ErrorBanner message={budgets.error} />

      {budgets.loading ? (
        <div className="card section-gap">
          <Spinner />
        </div>
      ) : rows.length === 0 ? (
        <div className="card section-gap">
          <Empty text="No budgets yet. Add one to track a category." />
        </div>
      ) : (
        <>
          {/* Summary row */}
          <div className="section-gap stat-grid">
            <div className="card">
              <div className="muted" style={{ fontSize: 13, fontWeight: 600 }}>
                Total budgeted
              </div>
              <div style={{ fontSize: 26, fontWeight: 800, marginTop: 8 }}>
                {fmt(totals.budgeted)}
              </div>
            </div>
            <div className="card">
              <div className="muted" style={{ fontSize: 13, fontWeight: 600 }}>
                Spent so far
              </div>
              <div
                style={{
                  fontSize: 26,
                  fontWeight: 800,
                  marginTop: 8,
                  color: "var(--expense)",
                }}
              >
                {fmt(totals.spent)}
              </div>
            </div>
            <div className="card">
              <div className="muted" style={{ fontSize: 13, fontWeight: 600 }}>
                Remaining
              </div>
              <div
                style={{
                  fontSize: 26,
                  fontWeight: 800,
                  marginTop: 8,
                  color:
                    totals.remaining >= 0 ? "var(--income)" : "var(--expense)",
                }}
              >
                {fmt(totals.remaining)}
              </div>
            </div>
          </div>

          {/* Per-budget progress cards */}
          <div
            className="section-gap"
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fill,minmax(330px,1fr))",
              gap: 16,
            }}
          >
            {rows.map(
              ({ budget: b, forecast: f, spent, pct, exceeded, nearing, remaining }) => {
                const state = exceeded ? "over" : nearing ? "near" : "ok";
                const projectedToExceed = f?.projectedToExceed ?? false;
                return (
                  <div className="card" key={b.id}>
                    <div
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: 12,
                        marginBottom: 12,
                      }}
                    >
                      <span
                        className="chip-ic"
                        style={{ background: b.categoryColor ?? "#64748b" }}
                      >
                        {iconEmoji(b.categoryIcon)}
                      </span>
                      <div className="grow">
                        <div className="t" style={{ fontWeight: 800, fontSize: 15 }}>
                          {b.categoryName ?? "Budget"}
                        </div>
                        <div className="sub muted" style={{ fontSize: 12 }}>
                          {fmt(spent)} of {fmt(b.amount)}
                          {b.period ? ` · ${b.period}` : ""}
                        </div>
                      </div>
                      <Badge kind={state}>
                        {exceeded ? "Over" : nearing ? "Nearing" : "On track"}
                      </Badge>
                    </div>

                    <ProgressBar value={spent} max={b.amount} state={state} />

                    <div
                      className="muted"
                      style={{
                        display: "flex",
                        justifyContent: "space-between",
                        marginTop: 8,
                        fontSize: 12,
                      }}
                    >
                      <span>{Math.round(pct)}% used</span>
                      <span>
                        {remaining >= 0
                          ? `${fmt(remaining)} left`
                          : `${fmt(Math.abs(remaining))} over`}
                      </span>
                    </div>

                    {showForecast && f && (
                      <div
                        className="muted"
                        style={{
                          marginTop: 6,
                          fontSize: 12,
                          color: projectedToExceed ? "var(--warning)" : undefined,
                        }}
                      >
                        Projected {fmt(f.projectedTotal)}
                        {projectedToExceed
                          ? ` · over by ${fmt(f.projectedOverBy)}`
                          : ""}
                      </div>
                    )}

                    <div
                      style={{
                        display: "flex",
                        gap: 6,
                        marginTop: 12,
                        justifyContent: "flex-end",
                      }}
                    >
                      <button className="btn ghost sm" onClick={() => setEditing(b)}>
                        Edit
                      </button>
                      <button className="btn ghost sm" onClick={() => del(b)}>
                        🗑
                      </button>
                    </div>
                  </div>
                );
              },
            )}
          </div>
        </>
      )}

      {(adding || editing) && categories.data && (
        <BudgetForm
          categories={categories.data}
          existing={editing}
          onClose={() => {
            setAdding(false);
            setEditing(null);
          }}
          onSaved={() => {
            setAdding(false);
            setEditing(null);
            refresh();
          }}
        />
      )}
    </>
  );
}

function periodBounds(period: BudgetPeriod, start: Date): { start: Date; end: Date } {
  const s = new Date(start.getFullYear(), start.getMonth(), start.getDate());
  const e = new Date(s);
  if (period === "weekly") e.setDate(e.getDate() + 7);
  else if (period === "monthly") e.setMonth(e.getMonth() + 1);
  else e.setFullYear(e.getFullYear() + 1);
  e.setDate(e.getDate() - 1);
  e.setHours(23, 59, 59, 999);
  return { start: s, end: e };
}

function BudgetForm({
  categories,
  existing,
  onClose,
  onSaved,
}: {
  categories: Category[];
  existing?: Budget | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [categoryId, setCategoryId] = useState<number | "">(existing?.categoryId ?? "");
  const [amount, setAmount] = useState(existing ? String(existing.amount) : "");
  const [period, setPeriod] = useState<BudgetPeriod>(existing?.period ?? "monthly");
  const [startDate, setStartDate] = useState(
    toDateInput(existing ? new Date(existing.startDate) : new Date()),
  );
  const [description, setDescription] = useState(existing?.description ?? "");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const { currencySymbol } = useSettings();

  const computedEnd = useMemo(
    () => periodBounds(period, fromDateInput(startDate)).end,
    [period, startDate],
  );

  const submit = async () => {
    setError(null);
    const amt = Number(amount);
    if (categoryId === "") {
      setError("Choose a category.");
      return;
    }
    if (!Number.isFinite(amt) || amt <= 0) {
      setError("Enter a valid amount greater than 0.");
      return;
    }
    setSaving(true);
    const { start, end } = periodBounds(period, fromDateInput(startDate));
    const body = {
      categoryId: categoryId as number,
      amount: amt,
      period,
      startDate: start.toISOString(),
      endDate: end.toISOString(),
      description: description.trim() || null,
    };
    try {
      if (existing) {
        await BudgetsApi.update(existing.id, body);
      } else {
        await BudgetsApi.create(body);
      }
      onSaved();
    } catch (e) {
      setError((e as Error).message);
      setSaving(false);
    }
  };

  return (
    <Modal
      title={existing ? "Edit budget" : "New budget"}
      subtitle="Set a spending limit for a category"
      onClose={onClose}
      footer={
        <div className="modal-actions">
          <button className="btn ghost" onClick={onClose} disabled={saving}>
            Cancel
          </button>
          <button className="btn primary" onClick={submit} disabled={saving}>
            {saving ? "Saving…" : "Save budget"}
          </button>
        </div>
      }
    >
      <ErrorBanner message={error} />
      <div className="form-row">
        <label>Category</label>
        <select
          value={categoryId}
          onChange={(e) => setCategoryId(e.target.value ? Number(e.target.value) : "")}
        >
          <option value="">Select…</option>
          {categories.map((c) => (
            <option key={c.id} value={c.id}>
              {iconEmoji(c.icon)} {c.name}
            </option>
          ))}
        </select>
      </div>
      <div className="form-grid">
        <div className="form-row">
          <label>Amount</label>
          <div style={{ position: "relative" }}>
            <span
              style={{
                position: "absolute",
                left: 13,
                top: "50%",
                transform: "translateY(-50%)",
                fontWeight: 800,
                color: "var(--text-muted)",
              }}
            >
              {currencySymbol}
            </span>
            <input
              type="number"
              step="0.01"
              min="0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              style={{ paddingLeft: 30 }}
            />
          </div>
        </div>
        <div className="form-row">
          <label>Period</label>
          <select value={period} onChange={(e) => setPeriod(e.target.value as BudgetPeriod)}>
            <option value="weekly">Weekly</option>
            <option value="monthly">Monthly</option>
            <option value="yearly">Yearly</option>
          </select>
        </div>
      </div>
      <div className="form-grid">
        <div className="form-row">
          <label>Start date</label>
          <input
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
          />
        </div>
        <div className="form-row">
          <label>End date (auto)</label>
          <input type="date" value={toDateInput(computedEnd)} disabled />
        </div>
      </div>
      <div className="form-row">
        <label>Description (optional)</label>
        <input value={description} onChange={(e) => setDescription(e.target.value)} />
      </div>
    </Modal>
  );
}
