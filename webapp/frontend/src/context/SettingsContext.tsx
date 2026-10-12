/**
 * App-wide user settings persisted in localStorage. Parity with the mobile
 * SettingsController (lib/providers/settings_provider.dart):
 *   - themeMode: System / Light / Dark   (default System)
 *   - currencyCode                        (default ZAR)
 *   - budgetAlertThreshold (1..100)       (default 80)
 */
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { AppCurrencies } from "../lib/currency";

export type ThemeMode = "system" | "light" | "dark";

/** Colour personalities. Orthogonal to light/dark mode. */
export type Palette = "fresh" | "premium" | "warm" | "calm";

export const PALETTES: { id: Palette; name: string; swatch: string }[] = [
  { id: "fresh", name: "Fresh", swatch: "#10b981" },
  { id: "premium", name: "Premium", swatch: "#7c5cff" },
  { id: "warm", name: "Warm", swatch: "#f97316" },
  { id: "calm", name: "Calm", swatch: "#2f6fed" },
];

const THEME_MODE_KEY = "settings.themeMode";
const PALETTE_KEY = "settings.palette";
const CURRENCY_CODE_KEY = "settings.currencyCode";
const BUDGET_ALERT_THRESHOLD_KEY = "settings.budgetAlertThreshold";

export const DEFAULT_THEME_MODE: ThemeMode = "system";
export const DEFAULT_PALETTE: Palette = "fresh";
export const DEFAULT_CURRENCY_CODE = "ZAR";
export const DEFAULT_BUDGET_ALERT_THRESHOLD = 80;

function clamp(v: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, v));
}

function loadThemeMode(): ThemeMode {
  const v = localStorage.getItem(THEME_MODE_KEY);
  if (v === "system" || v === "light" || v === "dark") return v;
  return DEFAULT_THEME_MODE;
}

function loadPalette(): Palette {
  const v = localStorage.getItem(PALETTE_KEY);
  if (v === "fresh" || v === "premium" || v === "warm" || v === "calm") return v;
  return DEFAULT_PALETTE;
}

function loadCurrencyCode(): string {
  return localStorage.getItem(CURRENCY_CODE_KEY) ?? DEFAULT_CURRENCY_CODE;
}

function loadThreshold(): number {
  const raw = localStorage.getItem(BUDGET_ALERT_THRESHOLD_KEY);
  const n = raw == null ? DEFAULT_BUDGET_ALERT_THRESHOLD : Number(raw);
  if (!Number.isFinite(n)) return DEFAULT_BUDGET_ALERT_THRESHOLD;
  return clamp(Math.round(n), 1, 100);
}

export interface SettingsState {
  themeMode: ThemeMode;
  palette: Palette;
  currencyCode: string;
  currencySymbol: string;
  budgetAlertThreshold: number;
  setThemeMode: (mode: ThemeMode) => void;
  setPalette: (palette: Palette) => void;
  setCurrencyCode: (code: string) => void;
  setBudgetAlertThreshold: (percent: number) => void;
}

const SettingsContext = createContext<SettingsState | null>(null);

/** Resolves whether the effective theme is dark, honoring the OS for "system". */
export function resolveDark(mode: ThemeMode): boolean {
  if (mode === "dark") return true;
  if (mode === "light") return false;
  return (
    typeof window !== "undefined" &&
    window.matchMedia("(prefers-color-scheme: dark)").matches
  );
}

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [themeMode, setThemeModeState] = useState<ThemeMode>(loadThemeMode);
  const [palette, setPaletteState] = useState<Palette>(loadPalette);
  const [currencyCode, setCurrencyCodeState] = useState<string>(loadCurrencyCode);
  const [budgetAlertThreshold, setThresholdState] = useState<number>(loadThreshold);

  const setThemeMode = useCallback((mode: ThemeMode) => {
    setThemeModeState((prev) => {
      if (prev === mode) return prev;
      localStorage.setItem(THEME_MODE_KEY, mode);
      return mode;
    });
  }, []);

  const setPalette = useCallback((p: Palette) => {
    setPaletteState((prev) => {
      if (prev === p) return prev;
      localStorage.setItem(PALETTE_KEY, p);
      return p;
    });
  }, []);

  const setCurrencyCode = useCallback((code: string) => {
    setCurrencyCodeState((prev) => {
      if (prev === code) return prev;
      localStorage.setItem(CURRENCY_CODE_KEY, code);
      return code;
    });
  }, []);

  const setBudgetAlertThreshold = useCallback((percent: number) => {
    const clamped = clamp(Math.round(percent), 1, 100);
    setThresholdState((prev) => {
      if (prev === clamped) return prev;
      localStorage.setItem(BUDGET_ALERT_THRESHOLD_KEY, String(clamped));
      return clamped;
    });
  }, []);

  // Apply theme class to <html> and react to OS changes when in "system".
  useEffect(() => {
    const apply = () => {
      const dark = resolveDark(themeMode);
      document.documentElement.dataset.theme = dark ? "dark" : "light";
    };
    apply();
    if (themeMode === "system") {
      const mq = window.matchMedia("(prefers-color-scheme: dark)");
      mq.addEventListener("change", apply);
      return () => mq.removeEventListener("change", apply);
    }
  }, [themeMode]);

  // Apply the colour palette to <html>.
  useEffect(() => {
    document.documentElement.dataset.palette = palette;
  }, [palette]);

  const value = useMemo<SettingsState>(
    () => ({
      themeMode,
      palette,
      currencyCode,
      currencySymbol: AppCurrencies.symbolFor(currencyCode),
      budgetAlertThreshold,
      setThemeMode,
      setPalette,
      setCurrencyCode,
      setBudgetAlertThreshold,
    }),
    [themeMode, palette, currencyCode, budgetAlertThreshold, setThemeMode, setPalette, setCurrencyCode, setBudgetAlertThreshold],
  );

  return <SettingsContext.Provider value={value}>{children}</SettingsContext.Provider>;
}

export function useSettings(): SettingsState {
  const ctx = useContext(SettingsContext);
  if (!ctx) throw new Error("useSettings must be used within SettingsProvider");
  return ctx;
}
