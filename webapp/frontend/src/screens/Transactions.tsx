import { useMemo, useState } from "react";
import type { SpendingAnomaly, Transaction, TxType } from "../api/types";
import {
  AnalyticsApi,
  CategoriesApi,
  TransactionsApi,
  type TransactionFilters,
} from "../api/client";
import { useAsync } from "../hooks/useAsync";
import { useSettings } from "../context/SettingsContext";
import { CurrencyFormatter } from "../lib/currency";
import { formatDate } from "../lib/dates";
import { iconEmoji } from "../lib/icons";
import { Spinner, ErrorBanner, Empty } from "../components/common";
import { TransactionForm } from "../components/TransactionForm";

export function Transactions() {
  const { currencySymbol } = useSettings();
  const [filterType, setFilterType] = useState<"" | TxType>("");
  const [filterCategory, setFilterCategory] = useState<"" | number>("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [search, setSearch] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const [editing, setEditing] = useState<Transaction | null>(null);
  const [adding, setAdding] = useState(false);

  const filters: TransactionFilters = useMemo(
    () => ({
      type: filterType || undefined,
      categoryId: filterCategory === "" ? undefined : filterCategory,
      from: from ? new Date(from).toISOString() : undefined,
      to: to ? new Date(`${to}T23:59:59`).toISOString() : undefined,
      search: search.trim() || undefined,
    }),
    [filterType, filterCategory, from, to, search],
  );

  const txns = useAsync(() => TransactionsApi.list(filters), [filters, reloadKey]);
  const categories = useAsync(() => CategoriesApi.list(), []);
  const anomalies = useAsync(() => AnalyticsApi.anomalies(), [reloadKey]);

  const anomalyById = useMemo(() => {
    const m = new Map<number, SpendingAnomaly>();
    (anomalies.data ?? []).forEach((a) => {
      if (a.transaction?.id != null) m.set(a.transaction.id, a);
    });
    return m;
  }, [anomalies.data]);

  const fmt = (n: number, income: boolean) =>
    CurrencyFormatter.formatSigned(currencySymbol, n, income);

  const refresh = () => setReloadKey((k) => k + 1);

  const del = async (id: number) => {
    if (!confirm("Delete this transaction?")) return;
    await TransactionsApi.remove(id);
    refresh();
  };

  return (
    <>
      <div className="spread">
        <div>
          <h1 className="page-title">Transactions</h1>
          <p className="page-sub">Track income and expenses</p>
        </div>
        <button className="btn primary" onClick={() => setAdding(true)}>
          + Add
        </button>
      </div>

      <div className="toolbar">
        <div className="field">
          <label>Type</label>
          <select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value as "" | TxType)}
          >
            <option value="">All</option>
            <option value="income">Income</option>
            <option value="expense">Expense</option>
          </select>
        </div>
        <div className="field">
          <label>Category</label>
          <select
            value={filterCategory}
            onChange={(e) =>
              setFilterCategory(e.target.value ? Number(e.target.value) : "")
            }
          >
            <option value="">All</option>
            {(categories.data ?? []).map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label>From</label>
          <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        </div>
        <div className="field">
          <label>To</label>
          <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        </div>
        <div className="field grow">
          <label>Search</label>
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search description…"
          />
        </div>
      </div>

      <ErrorBanner message={txns.error} />

      <div className="card">
        {txns.loading ? (
          <Spinner />
        ) : (txns.data ?? []).length === 0 ? (
          <Empty text="No transactions match these filters." />
        ) : (
          <div className="list">
            {txns.data!.map((t) => {
              const anomaly = t.type === "expense" ? anomalyById.get(t.id) : undefined;
              return (
                <div className="list-item" key={t.id}>
                  <div
                    className="icon-chip"
                    style={{ background: t.categoryColor ?? "#888" }}
                  >
                    {iconEmoji(t.categoryIcon)}
                  </div>
                  <div className="grow">
                    <div className="title">
                      {t.description?.trim() || t.categoryName || "Transaction"}
                    </div>
                    <div className="sub">
                      {t.categoryName ?? "Uncategorised"} · {formatDate(t.date)}
                      {t.recurringId != null ? " · recurring" : ""}
                    </div>
                    {anomaly && (
                      <div style={{ marginTop: 6 }}>
                        <span className="chip anomaly" title={`z-score ${anomaly.zScore.toFixed(2)}`}>
                          ⚠️ Unusually large — {anomaly.timesTypical.toFixed(1)}× your
                          usual {t.categoryName ?? "spend"}
                        </span>
                      </div>
                    )}
                  </div>
                  <div className={`amount ${t.type}`}>
                    {fmt(t.amount, t.type === "income")}
                  </div>
                  <div className="row">
                    <button className="btn sm ghost" onClick={() => setEditing(t)}>
                      Edit
                    </button>
                    <button className="btn sm ghost" onClick={() => del(t.id)}>
                      🗑
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {(adding || editing) && categories.data && (
        <TransactionForm
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
