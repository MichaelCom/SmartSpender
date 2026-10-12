import { useMemo, useState } from "react";
import type { Transaction, TxType } from "../api/types";
import {
  CategoriesApi,
  TransactionsApi,
  type TransactionFilters,
} from "../api/client";
import { useAsync } from "../hooks/useAsync";
import { useSettings } from "../context/SettingsContext";
import { CurrencyFormatter } from "../lib/currency";
import { iconEmoji } from "../lib/icons";
import { Spinner, ErrorBanner, Empty } from "../components/common";
import { TransactionForm } from "../components/TransactionForm";

const PAGE_SIZE = 15;

type QuickFilter = "all" | "income" | "expense";

/** Month key + label for grouping (e.g. "2026-9" -> "October 2026"). */
function monthKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth()}`;
}
function monthLabel(d: Date): string {
  return d.toLocaleDateString(undefined, { month: "long", year: "numeric" });
}

export function Transactions() {
  const { currencySymbol } = useSettings();
  const [filterType, setFilterType] = useState<"" | TxType>("");
  const [filterCategory, setFilterCategory] = useState<"" | number>("");
  const [search, setSearch] = useState("");
  const [quick, setQuick] = useState<QuickFilter | number>("all");
  const [page, setPage] = useState(0);
  const [reloadKey, setReloadKey] = useState(0);
  const [editing, setEditing] = useState<Transaction | null>(null);
  const [adding, setAdding] = useState(false);
  const [menuFor, setMenuFor] = useState<number | null>(null);

  const filters: TransactionFilters = useMemo(
    () => ({
      type: filterType || undefined,
      categoryId: filterCategory === "" ? undefined : filterCategory,
      search: search.trim() || undefined,
    }),
    [filterType, filterCategory, search],
  );

  const txns = useAsync(() => TransactionsApi.list(filters), [filters, reloadKey]);
  const categories = useAsync(() => CategoriesApi.list(), []);

  const fmtSigned = (n: number, income: boolean) =>
    CurrencyFormatter.formatSigned(currencySymbol, n, income);
  const fmt = (n: number) => CurrencyFormatter.format(currencySymbol, n);

  const refresh = () => setReloadKey((k) => k + 1);

  const del = async (id: number) => {
    if (!confirm("Delete this transaction?")) return;
    await TransactionsApi.remove(id);
    setMenuFor(null);
    refresh();
  };

  // Apply the quick-filter chips on top of the server-side filters.
  const quickFiltered = useMemo(() => {
    const all = (txns.data ?? [])
      .slice()
      .sort((a, b) => +new Date(b.date) - +new Date(a.date));
    if (quick === "all") return all;
    if (quick === "income") return all.filter((t) => t.type === "income");
    if (quick === "expense") return all.filter((t) => t.type === "expense");
    return all.filter((t) => t.categoryId === quick);
  }, [txns.data, quick]);

  const totalPages = Math.max(1, Math.ceil(quickFiltered.length / PAGE_SIZE));
  const clampedPage = Math.min(page, totalPages - 1);
  const pageItems = quickFiltered.slice(
    clampedPage * PAGE_SIZE,
    clampedPage * PAGE_SIZE + PAGE_SIZE,
  );

  // Group the current page's items by month.
  const groups = useMemo(() => {
    const map = new Map<string, { label: string; items: Transaction[]; net: number }>();
    for (const t of pageItems) {
      const d = new Date(t.date);
      const key = monthKey(d);
      if (!map.has(key)) {
        map.set(key, { label: monthLabel(d), items: [], net: 0 });
      }
      const g = map.get(key)!;
      g.items.push(t);
      g.net += t.type === "income" ? t.amount : -t.amount;
    }
    return Array.from(map.values());
  }, [pageItems]);

  const expenseCategories = (categories.data ?? []).filter(
    (c) => c.type === "expense",
  );

  return (
    <>
      <div className="spread">
        <div>
          <h1 className="page-title">Transactions</h1>
          <p className="page-sub">{quickFiltered.length} total</p>
        </div>
        <div className="header-actions">
          <button className="btn primary" onClick={() => setAdding(true)}>
            ＋ Add transaction
          </button>
        </div>
      </div>

      {/* Filters card */}
      <div className="card section-gap">
        <div className="toolbar">
          <div className="field grow">
            <label>Search</label>
            <div className="search">
              <span className="mag">🔍</span>
              <input
                value={search}
                onChange={(e) => {
                  setSearch(e.target.value);
                  setPage(0);
                }}
                placeholder="Search description, merchant…"
              />
            </div>
          </div>
          <div className="field">
            <label>Type</label>
            <select
              value={filterType}
              onChange={(e) => {
                setFilterType(e.target.value as "" | TxType);
                setPage(0);
              }}
            >
              <option value="">All types</option>
              <option value="income">Income</option>
              <option value="expense">Expense</option>
            </select>
          </div>
          <div className="field">
            <label>Category</label>
            <select
              value={filterCategory}
              onChange={(e) => {
                setFilterCategory(e.target.value ? Number(e.target.value) : "");
                setPage(0);
              }}
            >
              <option value="">All categories</option>
              {(categories.data ?? []).map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 4 }}>
          <button
            className={`chip${quick === "all" ? " on" : ""}`}
            onClick={() => {
              setQuick("all");
              setPage(0);
            }}
          >
            All
          </button>
          <button
            className={`chip${quick === "income" ? " on" : ""}`}
            onClick={() => {
              setQuick("income");
              setPage(0);
            }}
          >
            Income
          </button>
          <button
            className={`chip${quick === "expense" ? " on" : ""}`}
            onClick={() => {
              setQuick("expense");
              setPage(0);
            }}
          >
            Expenses
          </button>
          {expenseCategories.slice(0, 5).map((c) => (
            <button
              key={c.id}
              className={`chip${quick === c.id ? " on" : ""}`}
              onClick={() => {
                setQuick(c.id);
                setPage(0);
              }}
            >
              {iconEmoji(c.icon)} {c.name}
            </button>
          ))}
        </div>
      </div>

      <ErrorBanner message={txns.error} />

      {txns.loading ? (
        <div className="card section-gap">
          <Spinner />
        </div>
      ) : quickFiltered.length === 0 ? (
        <div className="card section-gap">
          <Empty text="No transactions match these filters." />
        </div>
      ) : (
        <>
          {groups.map((g) => (
            <div className="card section-gap" key={g.label}>
              <div className="card-head">
                <h2 className="card-title">{g.label}</h2>
                <span className="muted" style={{ fontSize: 13 }}>
                  Net {g.net >= 0 ? "＋" : "−"}
                  {fmt(Math.abs(g.net))}
                </span>
              </div>
              <div className="list">
                {g.items.map((t) => (
                  <div className="row" key={t.id} style={{ position: "relative" }}>
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
                        {t.recurringId != null ? " · recurring" : ""}
                      </div>
                    </div>
                    <span className={`amount ${t.type}`}>
                      {fmtSigned(t.amount, t.type === "income")}
                    </span>
                    <button
                      className="btn ghost sm"
                      onClick={() => setMenuFor(menuFor === t.id ? null : t.id)}
                      aria-label="Actions"
                    >
                      ⋯
                    </button>
                    {menuFor === t.id && (
                      <div
                        style={{
                          position: "absolute",
                          right: 0,
                          top: "100%",
                          zIndex: 5,
                          background: "var(--surface)",
                          border: "1px solid var(--border)",
                          borderRadius: "var(--radius-sm)",
                          boxShadow: "var(--shadow-lg)",
                          padding: 6,
                          display: "flex",
                          flexDirection: "column",
                          gap: 4,
                          minWidth: 120,
                        }}
                      >
                        <button
                          className="btn ghost sm"
                          onClick={() => {
                            setEditing(t);
                            setMenuFor(null);
                          }}
                        >
                          ✏️ Edit
                        </button>
                        <button
                          className="btn ghost sm"
                          onClick={() => del(t.id)}
                        >
                          🗑 Delete
                        </button>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          ))}

          <div
            className="card section-gap"
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
            }}
          >
            <span className="muted" style={{ fontSize: 13 }}>
              Showing {clampedPage * PAGE_SIZE + 1}–
              {clampedPage * PAGE_SIZE + pageItems.length} of {quickFiltered.length}
            </span>
            <div style={{ display: "flex", gap: 8 }}>
              <button
                className="btn sm"
                disabled={clampedPage === 0}
                onClick={() => setPage((p) => Math.max(0, p - 1))}
              >
                ← Prev
              </button>
              <button
                className="btn sm"
                disabled={clampedPage >= totalPages - 1}
                onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
              >
                Next →
              </button>
            </div>
          </div>
        </>
      )}

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
