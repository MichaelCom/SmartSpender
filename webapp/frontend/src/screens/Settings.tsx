import { useRef, useState } from "react";
import { useSettings, resolveDark, PALETTES } from "../context/SettingsContext";
import { AppCurrencies } from "../lib/currency";
import { DataApi } from "../api/client";
import type { BackupDocument, ImportResult } from "../api/types";
import { Modal } from "../components/Modal";
import { ErrorBanner } from "../components/common";

/** Gradient swatches for the palette picker (mockup uses two-stop gradients). */
const PALETTE_SWATCH: Record<string, string> = {
  fresh: "linear-gradient(135deg,#10b981,#0891b2)",
  premium: "linear-gradient(135deg,#7c5cff,#a855f7)",
  warm: "linear-gradient(135deg,#fb923c,#f43f5e)",
  calm: "linear-gradient(135deg,#2f6fed,#0ea5e9)",
};

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

  const dark = resolveDark(themeMode);

  return (
    <>
      <h1 className="page-title">Settings</h1>
      <p className="page-sub">Preferences, appearance and data</p>

      {/* Appearance */}
      <div className="card section-gap">
        <h2 className="card-title" style={{ marginBottom: 14 }}>
          Appearance
        </h2>
        <label>Colour palette</label>
        <div className="palette-grid" style={{ marginBottom: 18 }}>
          {PALETTES.map((p) => (
            <button
              key={p.id}
              type="button"
              className={`palette-option${palette === p.id ? " active" : ""}`}
              onClick={() => setPalette(p.id)}
              aria-label={p.name}
            >
              <span
                className="palette-swatch"
                style={{ background: PALETTE_SWATCH[p.id] ?? p.swatch }}
              />
              {p.name}
            </button>
          ))}
        </div>

        <div className="set-row">
          <div className="grow">
            <div className="t">Dark mode</div>
            <div className="d">Switch between light and dark surfaces</div>
          </div>
          <button
            type="button"
            className={`switch${dark ? " on" : ""}`}
            role="switch"
            aria-checked={dark}
            aria-label="Dark mode"
            onClick={() => setThemeMode(dark ? "light" : "dark")}
          />
        </div>
      </div>

      {/* Preferences */}
      <div className="card section-gap">
        <h2 className="card-title" style={{ marginBottom: 14 }}>
          Preferences
        </h2>
        <div className="set-row">
          <div className="grow">
            <div className="t">Currency</div>
            <div className="d">Symbol shown on all amounts (no FX conversion)</div>
          </div>
          <select
            style={{ width: 160 }}
            value={currencyCode}
            onChange={(e) => setCurrencyCode(e.target.value)}
          >
            {AppCurrencies.all.map((cur) => (
              <option key={cur.code} value={cur.code}>
                {cur.symbol} — {cur.code}
              </option>
            ))}
          </select>
        </div>
        <div className="set-row">
          <div className="grow">
            <div className="t">Budget alert threshold</div>
            <div className="d">Warn when a budget reaches this %</div>
          </div>
          <select
            style={{ width: 110 }}
            value={budgetAlertThreshold}
            onChange={(e) => setBudgetAlertThreshold(Number(e.target.value))}
          >
            {[70, 75, 80, 85, 90, 95].map((v) => (
              <option key={v} value={v}>
                {v}%
              </option>
            ))}
          </select>
        </div>
      </div>

      <DataSection />

      <p
        className="muted"
        style={{ fontSize: 12, textAlign: "center", marginTop: 20 }}
      >
        SmartSpender Web · v1.0.0 · Local-only
      </p>
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
    <div className="card section-gap">
      <h2 className="card-title" style={{ marginBottom: 6 }}>
        Data
      </h2>
      <p className="muted" style={{ fontSize: 13, marginBottom: 14 }}>
        The only bridge between mobile &amp; web is the JSON backup file.
      </p>
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

      <div className="set-row">
        <div className="grow">
          <div className="t">Load demo data</div>
          <div className="d">Replace everything with a realistic sample dataset</div>
        </div>
        <button className="btn" onClick={loadDemo} disabled={busy}>
          ✨ Load
        </button>
      </div>

      <div className="set-row">
        <div className="grow">
          <div className="t">Export backup</div>
          <div className="d">Download all data as a JSON file (schemaVersion 1)</div>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          <button className="btn" onClick={exportCsv}>
            CSV
          </button>
          <button className="btn" onClick={exportJson}>
            ⇩ Export
          </button>
        </div>
      </div>

      <div className="set-row">
        <div className="grow">
          <div className="t">Import backup</div>
          <div className="d">Replaces all current web data</div>
        </div>
        <button className="btn" onClick={onPickFile}>
          ⇧ Import
        </button>
      </div>

      <div className="set-row">
        <div className="grow">
          <div className="t" style={{ color: "var(--expense)" }}>
            Reset all data
          </div>
          <div className="d">
            Permanently delete every transaction, budget and category
          </div>
        </div>
        <button className="btn danger" onClick={() => setConfirmClear(true)}>
          Reset
        </button>
      </div>

      <input
        ref={fileInput}
        type="file"
        accept="application/json,.json"
        style={{ display: "none" }}
        onChange={onFileChosen}
      />

      {pendingImport && (
        <Modal
          title="Replace all data?"
          onClose={() => !busy && setPendingImport(null)}
          footer={
            <div className="modal-actions">
              <button
                className="btn ghost"
                onClick={() => setPendingImport(null)}
                disabled={busy}
              >
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
              <button
                className="btn ghost"
                onClick={() => setConfirmClear(false)}
                disabled={busy}
              >
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
