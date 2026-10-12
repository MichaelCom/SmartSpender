import { useRef, useState } from "react";
import type { ThemeMode } from "../context/SettingsContext";
import { useSettings } from "../context/SettingsContext";
import { PALETTES } from "../context/SettingsContext";
import { AppCurrencies } from "../lib/currency";
import { DataApi } from "../api/client";
import type { BackupDocument, ImportResult } from "../api/types";
import { Modal } from "../components/Modal";
import { ErrorBanner } from "../components/common";

const THEME_OPTIONS: { value: ThemeMode; label: string }[] = [
  { value: "system", label: "System" },
  { value: "light", label: "Light" },
  { value: "dark", label: "Dark" },
];

export function Settings() {
  const {
    themeMode,
    palette,
    currencyCode,
    budgetAlertThreshold,
    setThemeMode,
    setPalette,
    setCurrencyCode,
    setBudgetAlertThreshold,
  } = useSettings();

  return (
    <>
      <h1 className="page-title">Settings</h1>
      <p className="page-sub">Preferences and data</p>

      <div className="card">
        <h2 className="card-title">Appearance</h2>
        <div className="form-row">
          <label>Mode</label>
          <div className="row">
            {THEME_OPTIONS.map((o) => (
              <button
                key={o.value}
                className={`btn sm ${themeMode === o.value ? "primary" : ""}`}
                onClick={() => setThemeMode(o.value)}
              >
                {o.label}
              </button>
            ))}
          </div>
        </div>

        <div className="form-row" style={{ marginTop: 16 }}>
          <label>Theme</label>
          <div className="palette-grid">
            {PALETTES.map((p) => (
              <button
                key={p.id}
                className={`palette-option${palette === p.id ? " active" : ""}`}
                onClick={() => setPalette(p.id)}
                type="button"
                aria-label={p.name}
              >
                <span
                  className="palette-swatch"
                  style={{ background: p.swatch }}
                />
                <span className="palette-name">{p.name}</span>
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="card">
        <h2 className="card-title">Currency</h2>
        <div className="form-row">
          <label>Display currency (no FX conversion)</label>
          <select value={currencyCode} onChange={(e) => setCurrencyCode(e.target.value)}>
            {AppCurrencies.all.map((c) => (
              <option key={c.code} value={c.code}>
                {c.symbol} — {c.name} ({c.code})
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="card">
        <h2 className="card-title">Budget alerts</h2>
        <div className="form-row">
          <label>Alert threshold: {budgetAlertThreshold}%</label>
          <input
            type="range"
            min={1}
            max={100}
            value={budgetAlertThreshold}
            onChange={(e) => setBudgetAlertThreshold(Number(e.target.value))}
          />
          <div className="muted" style={{ fontSize: 12, marginTop: 4 }}>
            Budgets are flagged "nearing" once spending reaches this percentage.
          </div>
        </div>
      </div>

      <DataSection />
    </>
  );
}

function DataSection() {
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [pendingImport, setPendingImport] = useState<BackupDocument | null>(null);
  const [confirmClear, setConfirmClear] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);

  const exportJson = async () => {
    setError(null);
    setStatus(null);
    try {
      const doc = await DataApi.exportJson();
      const blob = new Blob([JSON.stringify(doc, null, 2)], {
        type: "application/json",
      });
      downloadBlob(blob, `smartspender-backup-${timestamp()}.json`);
      setStatus("Exported JSON backup.");
    } catch (e) {
      setError((e as Error).message);
    }
  };

  const exportCsv = () => {
    setError(null);
    setStatus(null);
    // Navigating to the API URL triggers a browser download via Content-Disposition.
    window.open(DataApi.exportCsvUrl(), "_blank");
  };

  const onPickFile = () => fileInput.current?.click();

  const onFileChosen = async (e: React.ChangeEvent<HTMLInputElement>) => {
    setError(null);
    setStatus(null);
    const file = e.target.files?.[0];
    e.target.value = ""; // allow re-selecting same file
    if (!file) return;
    try {
      const text = await file.text();
      const parsed = JSON.parse(text) as unknown;
      if (
        typeof parsed !== "object" ||
        parsed === null ||
        (parsed as { schemaVersion?: unknown }).schemaVersion !== 1
      ) {
        throw new Error("Not a valid SmartSpender backup (schemaVersion 1).");
      }
      setPendingImport(parsed as BackupDocument);
    } catch (err) {
      setError(`Could not read file: ${(err as Error).message}`);
    }
  };

  const confirmImport = async () => {
    if (!pendingImport) return;
    setBusy(true);
    setError(null);
    try {
      const res: ImportResult = await DataApi.import(pendingImport);
      setStatus(
        `Imported ${res.categoriesImported} categories, ${res.transactionsImported} transactions, ${res.budgetsImported} budgets. All previous data was replaced.`,
      );
      setPendingImport(null);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const clearAll = async () => {
    setBusy(true);
    setError(null);
    try {
      await DataApi.clear();
      setStatus("All data cleared.");
      setConfirmClear(false);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const loadDemo = async () => {
    setBusy(true);
    setError(null);
    try {
      const res = await DataApi.seed();
      setStatus(
        `Loaded demo data: ${res.categoriesImported} categories, ${res.transactionsImported} transactions, ${res.budgetsImported} budgets. Reloading…`,
      );
      // Full data replacement — reload so every screen reflects it.
      setTimeout(() => window.location.reload(), 600);
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  };

  return (
    <div className="card">
      <h2 className="card-title">Data</h2>
      <ErrorBanner message={error} />
      {status && (
        <div
          className="error-banner"
          style={{
            background: "color-mix(in srgb, var(--income) 14%, transparent)",
            color: "var(--income)",
            borderColor: "color-mix(in srgb, var(--income) 40%, transparent)",
          }}
        >
          {status}
        </div>
      )}

      <div className="row" style={{ flexWrap: "wrap", gap: 10 }}>
        <button className="btn" onClick={loadDemo} disabled={busy}>
          ✨ Load Demo Data
        </button>
        <button className="btn" onClick={exportJson}>
          ⬇ Export JSON
        </button>
        <button className="btn" onClick={exportCsv}>
          ⬇ Export CSV
        </button>
        <button className="btn" onClick={onPickFile}>
          ⬆ Import JSON
        </button>
        <button className="btn danger" onClick={() => setConfirmClear(true)}>
          🗑 Clear All Data
        </button>
      </div>

      <input
        ref={fileInput}
        type="file"
        accept="application/json,.json"
        style={{ display: "none" }}
        onChange={onFileChosen}
      />

      <p className="muted" style={{ fontSize: 12, marginTop: 12 }}>
        Backups are compatible with the SmartSpender mobile app (schema v1). The
        two apps only exchange data through this JSON file — never over the network.
      </p>

      {pendingImport && (
        <Modal
          title="Replace all data?"
          onClose={() => !busy && setPendingImport(null)}
          footer={
            <div className="modal-actions">
              <button className="btn" onClick={() => setPendingImport(null)} disabled={busy}>
                Cancel
              </button>
              <button className="btn danger" onClick={confirmImport} disabled={busy}>
                {busy ? "Importing…" : "Replace & import"}
              </button>
            </div>
          }
        >
          <p>
            Importing this backup will <strong>delete all current data</strong> and
            replace it with the file's contents. This cannot be undone.
          </p>
          <p className="muted" style={{ fontSize: 13 }}>
            Categories: {asArrayLen(pendingImport.categories)} · Transactions:{" "}
            {asArrayLen(pendingImport.transactions)} · Budgets:{" "}
            {asArrayLen(pendingImport.budgets)}
          </p>
        </Modal>
      )}

      {confirmClear && (
        <Modal
          title="Clear all data?"
          onClose={() => !busy && setConfirmClear(false)}
          footer={
            <div className="modal-actions">
              <button className="btn" onClick={() => setConfirmClear(false)} disabled={busy}>
                Cancel
              </button>
              <button className="btn danger" onClick={clearAll} disabled={busy}>
                {busy ? "Clearing…" : "Clear everything"}
              </button>
            </div>
          }
        >
          <p>
            This permanently deletes all categories, transactions, budgets, and
            recurring rules. Consider exporting a backup first. This cannot be undone.
          </p>
        </Modal>
      )}
    </div>
  );
}

function asArrayLen(v: unknown): number {
  return Array.isArray(v) ? v.length : 0;
}

function timestamp(): string {
  return new Date().toISOString().slice(0, 19).replace(/[:T]/g, "-");
}

function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
