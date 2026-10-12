import { useMemo, useState } from "react";
import type { Category, TxType } from "../api/types";
import { CategoriesApi, TransactionsApi } from "../api/client";
import { useAsync } from "../hooks/useAsync";
import { useSettings } from "../context/SettingsContext";
import { CurrencyFormatter } from "../lib/currency";
import { Spinner, ErrorBanner, Empty } from "../components/common";
import { Modal } from "../components/Modal";
import {
  COLOR_OPTIONS,
  DEFAULT_COLOR,
  DEFAULT_ICON,
  ICON_OPTIONS,
  iconEmoji,
} from "../lib/icons";

export function Categories() {
  const { currencySymbol } = useSettings();
  const [reloadKey, setReloadKey] = useState(0);
  const [editing, setEditing] = useState<Category | null>(null);
  const [adding, setAdding] = useState(false);

  const categories = useAsync(() => CategoriesApi.list(), [reloadKey]);
  const txns = useAsync(() => TransactionsApi.list(), [reloadKey]);

  const fmt = (n: number) => CurrencyFormatter.format(currencySymbol, n);
  const refresh = () => setReloadKey((k) => k + 1);

  // Aggregate transaction count + total per category (read-only).
  const stats = useMemo(() => {
    const m = new Map<number, { count: number; total: number }>();
    for (const t of txns.data ?? []) {
      if (t.categoryId == null) continue;
      const s = m.get(t.categoryId) ?? { count: 0, total: 0 };
      s.count += 1;
      s.total += t.amount;
      m.set(t.categoryId, s);
    }
    return m;
  }, [txns.data]);

  const del = async (c: Category) => {
    if (
      !confirm(
        `Delete "${c.name}"? Transactions keep their data but become uncategorised; any budgets for this category are removed.`,
      )
    )
      return;
    await CategoriesApi.remove(c.id);
    refresh();
  };

  const list = categories.data ?? [];

  return (
    <>
      <div className="spread">
        <div>
          <h1 className="page-title">Categories</h1>
          <p className="page-sub">
            {list.length} {list.length === 1 ? "category" : "categories"} · tap to
            edit colour & icon
          </p>
        </div>
        <button className="btn primary" onClick={() => setAdding(true)}>
          ＋ New category
        </button>
      </div>

      <ErrorBanner message={categories.error} />

      {categories.loading ? (
        <div className="card section-gap">
          <Spinner />
        </div>
      ) : list.length === 0 ? (
        <div className="card section-gap">
          <Empty text="No categories yet. Add one to get started." />
        </div>
      ) : (
        <div
          className="section-gap"
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fill,minmax(300px,1fr))",
            gap: 16,
          }}
        >
          {list.map((c) => {
            const s = stats.get(c.id);
            const count = s?.count ?? 0;
            return (
              <div
                className="card"
                key={c.id}
                style={{ display: "flex", alignItems: "center", gap: 14 }}
              >
                <span
                  className="chip-ic"
                  style={{
                    background: c.color ?? DEFAULT_COLOR,
                    width: 46,
                    height: 46,
                    fontSize: 21,
                  }}
                >
                  {iconEmoji(c.icon)}
                </span>
                <div className="grow">
                  <div className="t" style={{ fontWeight: 800 }}>
                    {c.name}
                  </div>
                  <div className="sub muted" style={{ fontSize: 12 }}>
                    {count} {count === 1 ? "transaction" : "transactions"}
                  </div>
                </div>
                <div style={{ textAlign: "right" }}>
                  <div className="amount" style={{ fontSize: 15 }}>
                    {fmt(s?.total ?? 0)}
                  </div>
                  <div style={{ display: "flex", gap: 6, marginTop: 4 }}>
                    <button
                      className="btn ghost sm"
                      onClick={() => setEditing(c)}
                    >
                      Edit
                    </button>
                    <button className="btn ghost sm" onClick={() => del(c)}>
                      🗑
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {(adding || editing) && (
        <CategoryForm
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

function CategoryForm({
  existing,
  onClose,
  onSaved,
}: {
  existing?: Category | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [name, setName] = useState(existing?.name ?? "");
  const [type, setType] = useState<TxType>(existing?.type ?? "expense");
  const [color, setColor] = useState(existing?.color ?? DEFAULT_COLOR);
  const [icon, setIcon] = useState(existing?.icon ?? DEFAULT_ICON);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    setError(null);
    if (!name.trim()) {
      setError("Name is required.");
      return;
    }
    setSaving(true);
    const body = { name: name.trim(), type, color, icon };
    try {
      if (existing) {
        await CategoriesApi.update(existing.id, body);
      } else {
        await CategoriesApi.create(body);
      }
      onSaved();
    } catch (e) {
      setError((e as Error).message);
      setSaving(false);
    }
  };

  return (
    <Modal
      title={existing ? "Edit category" : "New category"}
      subtitle="Choose a name, type, colour and icon"
      onClose={onClose}
      footer={
        <div className="modal-actions">
          <button className="btn ghost" onClick={onClose} disabled={saving}>
            Cancel
          </button>
          <button className="btn primary" onClick={submit} disabled={saving}>
            {saving ? "Saving…" : "Save category"}
          </button>
        </div>
      }
    >
      <ErrorBanner message={error} />
      <div className="form-row">
        <label>Name</label>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="e.g. Groceries"
        />
      </div>
      <div className="form-row">
        <label>Type</label>
        <div className="seg">
          <button
            type="button"
            className={type === "expense" ? "on-exp" : ""}
            onClick={() => setType("expense")}
          >
            − Expense
          </button>
          <button
            type="button"
            className={type === "income" ? "on-inc" : ""}
            onClick={() => setType("income")}
          >
            ＋ Income
          </button>
        </div>
      </div>
      <div className="form-row">
        <label>Colour</label>
        <div className="swatch-grid">
          {COLOR_OPTIONS.map((c) => (
            <button
              key={c}
              type="button"
              className={`swatch${color === c ? " sel" : ""}`}
              style={{ background: c }}
              onClick={() => setColor(c)}
              aria-label={c}
            />
          ))}
        </div>
      </div>
      <div className="form-row">
        <label>Icon</label>
        <div className="icon-grid">
          {ICON_OPTIONS.map((o) => (
            <button
              key={o.name}
              type="button"
              className={`icon-pick${icon === o.name ? " sel" : ""}`}
              onClick={() => setIcon(o.name)}
              aria-label={o.name}
            >
              {o.emoji}
            </button>
          ))}
        </div>
      </div>
    </Modal>
  );
}
