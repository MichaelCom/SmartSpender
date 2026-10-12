import { useMemo, useState } from "react";
import type { Budget, BudgetPeriod, Category } from "../api/types";
import { AnalyticsApi, BudgetsApi, CategoriesApi } from "../api/client";
import { useAsync } from "../hooks/useAsync";
import { useSettings } from "../context/SettingsContext";
import { CurrencyFormatter } from "../lib/currency";
import { daysElapsedInMonth, toDateInput, fromDateInput } from "../lib/dates";
import { iconEmoji } from "../lib/icons";
import { Spinner, ErrorBanner, Empty } from "../components/common";
import { Modal } from "../components/Modal";

/** The month must have at least this many elapsed days before we show a
 *  forecast projection line (parity: run-rate is noisy very early in the month). */
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

  return (
    <>
      <div className="spread">
        <div>
          <h1 className="page-title">Budgets</h1>
          <p className="page-sub">Track spending against limits</p>
        </div>
        <button className="btn primary" onClick={() => setAdding(true)}>
          + Add
        </button>
      </div>

      <ErrorBanner message={budgets.error} />

      {budgets.loading ? (
        <Spinner />
      ) : (budgets.data ?? []).length === 0 ? (
        <div className="card">
          <Empty text="No budgets yet. Add one to track a category." />
        </div>
      ) : (
        <div className="list">
          {budgets.data!.map((b) => {
            const f = forecast.data?.budgets.find((x) => x.budget.id === b.id);
            const spent = f?.spentSoFar ?? 0;
            const pct = b.amount > 0 ? (spent / b.amount) * 100 : 0;
            const exceeded = spent > b.amount;
            const nearing = !exceeded && pct >= budgetAlertThreshold;
            const barColor = exceeded
              ? "var(--expense)"
              : nearing
                ? "var(--warning)"
                : "var(--income)";
            const projectedPct =
              f && b.amount > 0 ? (f.projectedTotal / b.amount) * 100 : null;
            const projectedToExceed = f?.projectedToExceed ?? false;

            return (
              <div className="card" key={b.id} style={{ marginTop: 12 }}>
                <div className="spread" style={{ marginBottom: 10 }}>
                  <div className="row">
                    <div
                      className="icon-chip"
                      style={{ background: b.categoryColor ?? "#888" }}
                    >
                      {iconEmoji(b.categoryIcon)}
                    </div>
                    <div>
                      <div className="title">{b.categoryName ?? "Budget"}</div>
                      <div className="sub">
                        {b.period} · {fmt(spent)} of {fmt(b.amount)}
                      </div>
                    </div>
                  </div>
                  <div className="row">
                    <span
                      className="badge"
                      style={{
                        color: exceeded
                          ? "var(--expense)"
                          : nearing
                            ? "var(--warning)"
                            : "var(--text-muted)",
                      }}
                    >
                      {exceeded ? "Over budget" : nearing ? "Nearing" : "On track"}
                    </span>
                    <button className="btn sm ghost" onClick={() => setEditing(b)}>
                      Edit
                    </button>
                    <button className="btn sm ghost" onClick={() => del(b)}>
                      🗑
                    </button>
                  </div>
                </div>

                <div className="progress">
                  <div
                    className="bar"
                    style={{
                      width: `${Math.min(pct, 100)}%`,
                      background: barColor,
                    }}
                  />
                  {showForecast && projectedPct != null && (
                    <div
                      className="forecast-marker"
                      style={{ left: `${Math.min(projectedPct, 100)}%` }}
                      title={`Projected: ${fmt(f!.projectedTotal)}`}
                    />
                  )}
                </div>

                <div className="spread" style={{ marginTop: 8, fontSize: 12 }}>
                  <span className="muted">{Math.round(pct)}% used</span>
                  {showForecast && f && (
                    <span
                      className="muted"
                      style={{
                        color: projectedToExceed ? "var(--warning)" : undefined,
                      }}
                    >
                      Projected {fmt(f.projectedTotal)}
                      {projectedToExceed
                        ? ` · over by ${fmt(f.projectedOverBy)}`
                        : ""}
                    </span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
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
      title={existing ? "Edit budget" : "Add budget"}
      onClose={onClose}
      footer={
        <div className="modal-actions">
          <button className="btn" onClick={onClose} disabled={saving}>
            Cancel
          </button>
          <button className="btn primary" onClick={submit} disabled={saving}>
            {saving ? "Saving…" : "Save"}
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
              {c.name}
            </option>
          ))}
        </select>
      </div>
      <div className="form-grid">
        <div className="form-row">
          <label>Amount</label>
          <input
            type="number"
            step="0.01"
            min="0"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
          />
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
          <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} />
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
