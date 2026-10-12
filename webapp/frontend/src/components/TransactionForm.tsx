import { useEffect, useRef, useState } from "react";
import type { Category, CategorySuggestion, Transaction, TxType } from "../api/types";
import { AnalyticsApi, TransactionsApi } from "../api/client";
import { useSettings } from "../context/SettingsContext";
import { Modal } from "./Modal";
import { ErrorBanner } from "./common";
import { toDateInput, fromDateInput } from "../lib/dates";
import { iconEmoji } from "../lib/icons";

interface Props {
  categories: Category[];
  existing?: Transaction | null;
  defaultType?: TxType;
  onClose: () => void;
  onSaved: () => void;
}

/**
 * Add/edit a transaction. Includes the auto-categorization suggestion chip:
 * on description change/blur (and matching type) it calls GET /categorize and
 * offers to apply the suggested category.
 *
 * Layout mirrors Docs/smartspender-mockups/web/transaction-modal.html:
 * segmented income/expense toggle, big amount with currency prefix,
 * description, category + date grid, optional note, and a suggestion chip row
 * (suggested category + "make recurring").
 */
export function TransactionForm({
  categories,
  existing,
  defaultType = "expense",
  onClose,
  onSaved,
}: Props) {
  const { currencySymbol } = useSettings();
  const [type, setType] = useState<TxType>(existing?.type ?? defaultType);
  const [amount, setAmount] = useState(existing ? String(existing.amount) : "");
  const [description, setDescription] = useState(existing?.description ?? "");
  const [note, setNote] = useState("");
  const [categoryId, setCategoryId] = useState<number | null>(
    existing?.categoryId ?? null,
  );
  const [date, setDate] = useState(
    toDateInput(existing ? new Date(existing.date) : new Date()),
  );
  const [recurring, setRecurring] = useState(false);
  const [suggestion, setSuggestion] = useState<CategorySuggestion | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const suggestTimer = useRef<number>();

  const typeCategories = categories.filter((c) => c.type === type);

  // Reset category selection if it no longer matches the type.
  useEffect(() => {
    if (categoryId != null && !typeCategories.some((c) => c.id === categoryId)) {
      setCategoryId(null);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [type]);

  const fetchSuggestion = (desc: string, t: TxType) => {
    window.clearTimeout(suggestTimer.current);
    if (!desc.trim()) {
      setSuggestion(null);
      return;
    }
    suggestTimer.current = window.setTimeout(() => {
      AnalyticsApi.categorize(desc.trim(), t)
        .then((s) => setSuggestion(s))
        .catch(() => setSuggestion(null));
    }, 300);
  };

  const suggestionCategory =
    suggestion != null
      ? categories.find((c) => c.id === suggestion.categoryId)
      : undefined;
  const showSuggestChip =
    suggestionCategory != null && suggestionCategory.id !== categoryId;

  const submit = async () => {
    setError(null);
    const amt = Number(amount);
    if (!Number.isFinite(amt) || amt <= 0) {
      setError("Enter a valid amount greater than 0.");
      return;
    }
    setSaving(true);
    const body = {
      amount: amt,
      description: description.trim() || null,
      categoryId,
      date: fromDateInput(date).toISOString(),
      type,
    };
    try {
      if (existing) {
        await TransactionsApi.update(existing.id, body);
      } else {
        await TransactionsApi.create(body);
      }
      onSaved();
    } catch (e) {
      setError((e as Error).message);
      setSaving(false);
    }
  };

  return (
    <Modal
      title={existing ? "Edit transaction" : "Add transaction"}
      subtitle="Record income or an expense"
      onClose={onClose}
      footer={
        <div className="modal-actions">
          <button className="btn ghost" onClick={onClose} disabled={saving}>
            Cancel
          </button>
          <button className="btn primary" onClick={submit} disabled={saving}>
            {saving ? "Saving…" : "Save transaction"}
          </button>
        </div>
      }
    >
      <ErrorBanner message={error} />

      <div className="form-row">
        <div className="seg">
          <button
            type="button"
            className={type === "expense" ? "on-exp" : ""}
            onClick={() => {
              setType("expense");
              fetchSuggestion(description, "expense");
            }}
          >
            − Expense
          </button>
          <button
            type="button"
            className={type === "income" ? "on-inc" : ""}
            onClick={() => {
              setType("income");
              fetchSuggestion(description, "income");
            }}
          >
            ＋ Income
          </button>
        </div>
      </div>

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
            inputMode="decimal"
            step="0.01"
            min="0"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
            style={{ paddingLeft: 30, fontSize: 20, fontWeight: 800 }}
          />
        </div>
      </div>

      <div className="form-row">
        <label>Description</label>
        <input
          value={description}
          onChange={(e) => {
            setDescription(e.target.value);
            fetchSuggestion(e.target.value, type);
          }}
          onBlur={() => fetchSuggestion(description, type)}
          placeholder="e.g. Woolworths"
        />
      </div>

      <div className="form-grid">
        <div className="form-row">
          <label>Category</label>
          <select
            value={categoryId ?? ""}
            onChange={(e) =>
              setCategoryId(e.target.value ? Number(e.target.value) : null)
            }
          >
            <option value="">Uncategorised</option>
            {typeCategories.map((c) => (
              <option key={c.id} value={c.id}>
                {iconEmoji(c.icon)} {c.name}
              </option>
            ))}
          </select>
        </div>
        <div className="form-row">
          <label>Date</label>
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        </div>
      </div>

      <div className="form-row">
        <label>Note (optional)</label>
        <textarea
          rows={2}
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="Add a note…"
        />
      </div>

      <div className="form-row">
        <label>Suggestions</label>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          {showSuggestChip ? (
            <button
              type="button"
              className="chip"
              style={{
                background: "color-mix(in srgb,var(--info) 14%,transparent)",
                color: "var(--info)",
                borderColor: "transparent",
              }}
              onClick={() => {
                setCategoryId(suggestionCategory!.id);
                setSuggestion(null);
              }}
              title={suggestion?.reason}
            >
              💡 Looks like “{suggestionCategory!.name}”
              {suggestion?.fromHistory ? " (from history)" : ""}
            </button>
          ) : (
            <span className="chip" style={{ opacity: 0.6 }}>
              💡 Type a description for a suggestion
            </span>
          )}
          <button
            type="button"
            className={`chip${recurring ? " on" : ""}`}
            onClick={() => setRecurring((r) => !r)}
            title="Flag this as a recurring charge"
          >
            ↻ Make recurring
          </button>
        </div>
      </div>
    </Modal>
  );
}
