import { useEffect, useRef, useState } from "react";
import type { Category, CategorySuggestion, Transaction, TxType } from "../api/types";
import { AnalyticsApi, TransactionsApi } from "../api/client";
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
 * on description blur (and matching type) it calls GET /categorize and offers
 * to apply the suggested category.
 */
export function TransactionForm({
  categories,
  existing,
  defaultType = "expense",
  onClose,
  onSaved,
}: Props) {
  const [type, setType] = useState<TxType>(existing?.type ?? defaultType);
  const [amount, setAmount] = useState(existing ? String(existing.amount) : "");
  const [description, setDescription] = useState(existing?.description ?? "");
  const [categoryId, setCategoryId] = useState<number | null>(
    existing?.categoryId ?? null,
  );
  const [date, setDate] = useState(
    toDateInput(existing ? new Date(existing.date) : new Date()),
  );
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
        <label>Type</label>
        <div className="row">
          {(["expense", "income"] as TxType[]).map((t) => (
            <button
              key={t}
              type="button"
              className={`btn sm ${type === t ? "primary" : ""}`}
              onClick={() => {
                setType(t);
                fetchSuggestion(description, t);
              }}
            >
              {t === "income" ? "Income" : "Expense"}
            </button>
          ))}
        </div>
      </div>

      <div className="form-grid">
        <div className="form-row">
          <label>Amount</label>
          <input
            type="number"
            inputMode="decimal"
            step="0.01"
            min="0"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
          />
        </div>
        <div className="form-row">
          <label>Date</label>
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
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
          placeholder="e.g. Uber ride"
        />
      </div>

      {showSuggestChip && (
        <div className="form-row">
          <button
            type="button"
            className="chip suggest"
            onClick={() => {
              setCategoryId(suggestionCategory!.id);
              setSuggestion(null);
            }}
            title={suggestion?.reason}
          >
            <span>{iconEmoji(suggestionCategory!.icon)}</span>
            Suggested: {suggestionCategory!.name}
            {suggestion?.fromHistory ? " (from history)" : ""}
          </button>
        </div>
      )}

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
              {c.name}
            </option>
          ))}
        </select>
      </div>
    </Modal>
  );
}
