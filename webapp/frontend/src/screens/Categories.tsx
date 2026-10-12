import { useState } from "react";
import type { Category, TxType } from "../api/types";
import { CategoriesApi } from "../api/client";
import { useAsync } from "../hooks/useAsync";
import { Spinner, ErrorBanner, Empty } from "../components/common";
import { Modal } from "../components/Modal";
import { COLOR_OPTIONS, DEFAULT_COLOR, DEFAULT_ICON, ICON_OPTIONS, iconEmoji } from "../lib/icons";

export function Categories() {
  const [filterType, setFilterType] = useState<"" | TxType>("");
  const [reloadKey, setReloadKey] = useState(0);
  const [editing, setEditing] = useState<Category | null>(null);
  const [adding, setAdding] = useState(false);

  const categories = useAsync(
    () => CategoriesApi.list(filterType || undefined),
    [filterType, reloadKey],
  );

  const refresh = () => setReloadKey((k) => k + 1);

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

  return (
    <>
      <div className="spread">
        <div>
          <h1 className="page-title">Categories</h1>
          <p className="page-sub">Organize income and expenses</p>
        </div>
        <button className="btn primary" onClick={() => setAdding(true)}>
          + Add
        </button>
      </div>

      <div className="toolbar">
        <div className="field">
          <label>Type</label>
          <select value={filterType} onChange={(e) => setFilterType(e.target.value as "" | TxType)}>
            <option value="">All</option>
            <option value="income">Income</option>
            <option value="expense">Expense</option>
          </select>
        </div>
      </div>

      <ErrorBanner message={categories.error} />

      <div className="card">
        {categories.loading ? (
          <Spinner />
        ) : (categories.data ?? []).length === 0 ? (
          <Empty text="No categories yet. Add one to get started." />
        ) : (
          <div className="list">
            {categories.data!.map((c) => (
              <div className="list-item" key={c.id}>
                <div className="icon-chip" style={{ background: c.color ?? DEFAULT_COLOR }}>
                  {iconEmoji(c.icon)}
                </div>
                <div className="grow">
                  <div className="title">{c.name}</div>
                  <div className="sub">{c.type}</div>
                </div>
                <button className="btn sm ghost" onClick={() => setEditing(c)}>
                  Edit
                </button>
                <button className="btn sm ghost" onClick={() => del(c)}>
                  🗑
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

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
      title={existing ? "Edit category" : "Add category"}
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
        <label>Name</label>
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Groceries" />
      </div>
      <div className="form-row">
        <label>Type</label>
        <div className="row">
          {(["expense", "income"] as TxType[]).map((t) => (
            <button
              key={t}
              type="button"
              className={`btn sm ${type === t ? "primary" : ""}`}
              onClick={() => setType(t)}
            >
              {t === "income" ? "Income" : "Expense"}
            </button>
          ))}
        </div>
      </div>
      <div className="form-row">
        <label>Color</label>
        <div className="swatch-grid">
          {COLOR_OPTIONS.map((c) => (
            <button
              key={c}
              type="button"
              className={`swatch${color === c ? " selected" : ""}`}
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
              className={`icon-pick${icon === o.name ? " selected" : ""}`}
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
