import type { Insight } from "../api/types";

const ICON: Record<Insight["kind"], string> = {
  positive: "✅",
  warning: "⚠️",
  info: "💡",
};

interface Props {
  insight: Insight;
  onClick?: () => void;
}

/**
 * Compact insight card. Mirrors the mobile InsightHighlight widget:
 * icon coloured by kind + title/detail, optional tap handler.
 */
export function InsightCard({ insight, onClick }: Props) {
  return (
    <div
      className={`insight ${insight.kind}${onClick ? " clickable" : ""}`}
      onClick={onClick}
      role={onClick ? "button" : undefined}
      tabIndex={onClick ? 0 : undefined}
      onKeyDown={(e) => {
        if (onClick && (e.key === "Enter" || e.key === " ")) onClick();
      }}
    >
      <span className="ico">{ICON[insight.kind]}</span>
      <div className="txt">
        <div className="t">{insight.title}</div>
        <div className="d">{insight.detail}</div>
      </div>
      {onClick && <span className="muted">›</span>}
    </div>
  );
}
