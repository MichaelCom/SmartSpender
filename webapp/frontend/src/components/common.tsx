/**
 * Shared presentational components (SINGLE OWNER: shell agent).
 *
 * Exports screens import:
 *   Spinner, ErrorBanner, Empty      — status primitives
 *   ProgressBar({ value, max, state })  — .progress/.bar budget meter
 *   StatTile({ label, value, icon, iconKind, trend, trendDir, valueClass })
 *   Badge({ kind, children })        — .badge.(ok|near|over)
 *   Donut({ data, centerLabel, centerValue, size })  — Recharts ring + overlay
 *   Sparkline({ values, color })     — small Recharts area for the hero
 *
 * Chart colours are resolved from CSS tokens at render (via getComputedStyle)
 * so Recharts re-themes on palette/mode switch. Screens pass explicit colours
 * for category series; otherwise tokens are used.
 */
import type { ReactNode } from "react";
import {
  Area,
  AreaChart,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
} from "recharts";

/* ---------------------------------------------------------------------------
   Status primitives
--------------------------------------------------------------------------- */
export function Spinner() {
  return <div className="spinner" aria-label="Loading" />;
}

export function ErrorBanner({ message }: { message: string | null }) {
  if (!message) return null;
  return <div className="error-banner">{message}</div>;
}

export function Empty({ text }: { text: string }) {
  return <div className="empty">{text}</div>;
}

/* ---------------------------------------------------------------------------
   Token helper — reads a CSS custom property off :root at render time so
   charts pick up the active palette/mode. Falls back to a safe default.
--------------------------------------------------------------------------- */
export function cssVar(name: string, fallback = "#64748b"): string {
  if (typeof window === "undefined") return fallback;
  const v = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  return v || fallback;
}

/* ---------------------------------------------------------------------------
   Badge — budget status pill.
--------------------------------------------------------------------------- */
export type BadgeKind = "ok" | "near" | "over";

export function Badge({ kind, children }: { kind: BadgeKind; children: ReactNode }) {
  return <span className={`badge ${kind}`}>{children}</span>;
}

/* ---------------------------------------------------------------------------
   ProgressBar — renders .progress/.bar. `state` maps to a token colour:
     ok   -> --primary
     near -> --warning
     over -> --expense
   An explicit `color` overrides the state mapping.
--------------------------------------------------------------------------- */
export type ProgressState = "ok" | "near" | "over";

const STATE_VAR: Record<ProgressState, string> = {
  ok: "var(--primary)",
  near: "var(--warning)",
  over: "var(--expense)",
};

export function ProgressBar({
  value,
  max,
  state = "ok",
  color,
}: {
  value: number;
  max: number;
  state?: ProgressState;
  color?: string;
}) {
  const pct = max > 0 ? (value / max) * 100 : 0;
  const width = Math.max(0, Math.min(pct, 100));
  return (
    <div className="progress">
      <div
        className="bar"
        style={{ width: `${width}%`, background: color ?? STATE_VAR[state] }}
      />
    </div>
  );
}

/* ---------------------------------------------------------------------------
   StatTile — dashboard stat card with optional icon chip + trend delta.
   `iconKind` picks the chip colour variant (inc/exp/sav/info).
   `trendDir` colours the trend text (up=income green, down=expense red).
--------------------------------------------------------------------------- */
export type StatIconKind = "inc" | "exp" | "sav" | "info";
export type TrendDir = "up" | "down";

export function StatTile({
  label,
  value,
  icon,
  iconKind = "sav",
  trend,
  trendDir,
  valueClass,
}: {
  label: string;
  value: ReactNode;
  icon?: ReactNode;
  iconKind?: StatIconKind;
  trend?: ReactNode;
  trendDir?: TrendDir;
  valueClass?: "income" | "expense";
}) {
  return (
    <div className="stat">
      <div className="top">
        <span className="label">{label}</span>
        {icon != null && <span className={`ic ${iconKind}`}>{icon}</span>}
      </div>
      <div className={`value${valueClass ? ` ${valueClass}` : ""}`}>{value}</div>
      {trend != null && (
        <div className={`trend${trendDir ? ` ${trendDir}` : ""}`}>{trend}</div>
      )}
    </div>
  );
}

/* ---------------------------------------------------------------------------
   Donut — Recharts PieChart ring (innerRadius ~62%) with a 2px --surface
   stroke and transparent background. Renders a centre overlay (total) when
   centerLabel/centerValue are given. Colours come from each datum.
--------------------------------------------------------------------------- */
export interface DonutDatum {
  label: string;
  value: number;
  color: string;
}

export function Donut({
  data,
  centerLabel,
  centerValue,
  size = 150,
}: {
  data: DonutDatum[];
  centerLabel?: ReactNode;
  centerValue?: ReactNode;
  size?: number;
}) {
  const stroke = cssVar("--surface", "#ffffff");
  const hasData = data.some((d) => d.value > 0);
  return (
    <div className="donut" style={{ width: size, height: size }}>
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          <Pie
            data={hasData ? data : [{ label: "empty", value: 1, color: cssVar("--surface-3", "#e9edf3") }]}
            dataKey="value"
            nameKey="label"
            cx="50%"
            cy="50%"
            innerRadius="62%"
            outerRadius="100%"
            paddingAngle={hasData ? 1.5 : 0}
            stroke={stroke}
            strokeWidth={2}
            isAnimationActive={false}
          >
            {(hasData ? data : [{ color: cssVar("--surface-3", "#e9edf3") }]).map((d, i) => (
              <Cell key={i} fill={d.color} />
            ))}
          </Pie>
        </PieChart>
      </ResponsiveContainer>
      {(centerLabel != null || centerValue != null) && (
        <div className="ctr">
          {centerLabel != null && <div className="s">{centerLabel}</div>}
          {centerValue != null && <div className="b">{centerValue}</div>}
        </div>
      )}
    </div>
  );
}

/* ---------------------------------------------------------------------------
   Sparkline — small Recharts area for the dashboard hero 30-day flow.
   Transparent background; sits on the gradient hero so it defaults to a
   white-tinted fill (--on-brand). Pass `color` to override.
--------------------------------------------------------------------------- */
export function Sparkline({
  values,
  color,
}: {
  values: number[];
  color?: string;
}) {
  const line = color ?? "rgba(255,255,255,0.95)";
  const data = values.map((v, i) => ({ i, v }));
  const gradId = "spark-grad";
  return (
    <div className="spark">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 2, right: 0, bottom: 0, left: 0 }}>
          <defs>
            <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={line} stopOpacity={0.55} />
              <stop offset="100%" stopColor={line} stopOpacity={0.05} />
            </linearGradient>
          </defs>
          <Area
            type="monotone"
            dataKey="v"
            stroke={line}
            strokeWidth={2}
            fill={`url(#${gradId})`}
            isAnimationActive={false}
            dot={false}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
