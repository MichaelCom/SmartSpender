# SmartSpender Web — Design Handoff

A redesign of the SmartSpender **web** app (`webapp/frontend`, React 18 + Vite +
TypeScript, React Router, Recharts). The goal is a nicer look & feel — the
functionality and data model are unchanged. These are **visual reference
mockups**, not production code: implement them in the real app using the
component/token mapping below.

> Scope: WEB only. The Flutter mobile app (`lib/`) will be redesigned to match
> in a later pass. Web and mobile remain fully independent — the only bridge is
> the JSON backup (Export/Import).

---

## 1. Files in this handoff

| File | Screen |
|------|--------|
| `theme.css` | **Shared token system** — the source of truth for all design tokens. Mirrors `webapp/frontend/src/index.css`. (Top level of `smartspender-mockups/`.) |
| `web/dashboard.html` | Dashboard (flagship — sets the visual language) |
| `web/transactions.html` | Transactions list + filters + pagination |
| `web/categories.html` | Categories card grid |
| `web/budgets.html` | Budgets summary + progress cards |
| `web/reports.html` | Reports — 5 tabs with charts (built with Highcharts in the mockup; **implement with Recharts** in the app — see §6) |
| `web/settings.html` | Settings — appearance, preferences, data |
| `web/transaction-modal.html` | Add/Edit transaction modal |

> Folder layout: the 7 web HTML files live in `web/`; `theme.css` and this
> `DESIGN.md` sit at the top level of `smartspender-mockups/`. The Flutter
> mobile mockups are in `mobile/` (with their own `mobile/theme-mobile.css`).

Each mockup has a **palette + dark-mode switcher pill** (top-right). That control
is a **mockup-only convenience** for previewing — it is NOT part of the shipped
UI. The real app already drives `data-theme` / `data-palette` on `<html>` from
Settings.

---

## 2. Design principles

1. **Keep the existing token architecture.** The current app already separates
   *mode* (light/dark: neutral surfaces) from *palette* (brand hues: Fresh,
   Premium, Warm, Calm). The redesign builds on this — do not replace it.
2. **One focal point per screen.** Dashboard → the gradient balance hero.
   Reports → the active chart. Budgets → the progress cards.
3. **Semantic finance colours are constant** across palettes: `--income`
   (green), `--expense` (red), `--warning` (amber), `--info` (blue). Only brand
   hues change per palette.
4. **Generous spacing, strong hierarchy, tabular-aligned numbers.** All money
   values use `font-variant-numeric: tabular-nums`.
5. **Subtle depth, not heavy chrome.** Soft shadows (`--shadow`), 16px radii,
   1px borders.

---

## 3. Design tokens (from `theme.css`)

All colours are CSS custom properties on `<html>`. **Never hardcode hex values**
in components — always reference tokens so palette/mode switching works.

### Mode tokens (set by `html[data-theme="light|dark"]`)
`--bg`, `--bg-accent`, `--surface`, `--surface-2`, `--surface-3`, `--text`,
`--text-muted`, `--border`, `--shadow`, `--shadow-lg`, `--on-brand`,
`--pattern-ink`, `--pattern-ink-2`.

### Palette tokens (set by `html[data-palette="fresh|premium|warm|calm"]`)
`--primary`, `--primary-strong`, `--primary-soft`, `--accent`, `--gradient`,
`--ring`, `--pattern`, `--pattern-size`, `--pattern-pos`.

### Constant semantic tokens (`:root`)
`--income` `#16b364`, `--expense` `#ef4444`, `--warning` `#f59e0b`,
`--info` `#3b82f6`, `--positive` `#16b364`.

### Shape / type
`--radius` 16px, `--radius-sm` 10px, `--radius-lg` 22px, `--space` 16px,
`--font` (system stack).

> These names match the real `index.css` exactly, with ONE addition to carry
> over: `--surface-3` (used for progress-track backgrounds and the budget-vs-
> actual "budget" bars). If it's not already in `index.css`, add it:
> light `#e9edf3`, dark `#263040`.

---

## 4. Shared components & their classes

| Component | Key classes | Notes |
|-----------|-------------|-------|
| App shell | `.app`, `.sidebar`, `.content` | 244px sticky sidebar + centered content (max 1140px). Collapses under 900px. |
| Sidebar nav | `.nav-link`, `.nav-link.active`, `.nav-ico` | Active item gets `--primary-soft` bg + a gradient accent bar on the left edge (`::before`). |
| Brand | `.brand`, `.brand-mark` | Gradient rounded-square logo mark + wordmark. |
| Sidebar footer | `.side-foot`, `.side-user`, `.avatar` | Gradient avatar + account label (new). |
| Page header | `.spread`, `.page-title`, `.page-sub`, `.header-actions` | Title + subtitle left, actions right. |
| Buttons | `.btn`, `.btn.primary`, `.btn.ghost`, `.btn.danger`, `.btn.sm` | `.primary` = gradient fill + ring shadow. |
| Cards | `.card`, `.card-head`, `.card-title`, `.link` | Standard surface container. |
| Stat tiles | `.stat-grid`, `.stat` (+ dashboard `.ic`, `.trend`, `.up`/`.down`) | Auto-fit grid, min 190px. |
| Lists / rows | `.list`, `.row`, `.chip-ic`, `.amount` (+ `.income`/`.expense`) | `.chip-ic` = coloured category icon (category colour as bg). |
| Chips / filters | `.chip`, `.chip.on` | Pill filters; `.on` = active. |
| Badges | `.badge.over`, `.badge.near`, `.badge.ok` | Budget status. |
| Progress | `.progress`, `.progress .bar` | Bar colour set inline per state (expense/warning/primary). |
| Tabs | `.tabs`, `.tab`, `.tab.active` | Underline tabs (Reports). |
| Table | `.tbl` | Uppercase muted headers, hover rows. |
| Modal | `.modal-backdrop`, `.modal`, `.form-row`, `.form-grid`, `.modal-actions` | Centered, max 480px. |
| Segmented control | `.seg`, `.seg .on-inc`, `.seg .on-exp` | Income/Expense toggle in the form. |
| Pickers | `.swatch-grid`/`.swatch`, `.icon-grid`/`.icon-pick` | Colour & icon pickers (category/budget forms). |
| Toggle switch | `.switch`, `.switch.on` | Settings toggles. |
| Settings row | `.set-row` | Label + description + control. |
| Palette picker | `.palette-grid`, `.palette-option`, `.palette-swatch` | In Settings → Appearance. |

---

## 5. Per-screen notes

### Dashboard (`dashboard.html`)
- **Gradient balance hero** is the new focal point: balance + MoM delta pill,
  income/spent minis, and a 30-day flow sparkline (bars). In the app, drive the
  sparkline from the same series the Reports daily chart uses.
- Stat tiles gained an **icon chip** and a **trend delta** (▲/▼ vs last month).
  Compute deltas from the previous-month summary.
- "Spending by category" uses a **donut + legend** (replaces the plain list).
- "Budget alerts" uses **progress bars + status badges** (over/nearing/on-track).
- "Recent transactions" = polished rows reused from Transactions.

### Transactions (`transactions.html`)
- Toolbar: search + Type / Category / Month selects; quick-filter chips below.
- Grouped by month with a **net total** on the group header.
- Each row: category `.chip-ic`, title/sub, signed amount, `⋯` actions menu.
- Pagination footer ("Showing N of M").

### Categories (`categories.html`)
- Responsive card grid (min 300px). Each card: icon chip, name, txn count,
  total, Edit. "New category" opens a modal with the colour/icon pickers.

### Budgets (`budgets.html`)
- Summary stat row (Total budgeted / Spent / Remaining).
- Per-budget progress cards with status badge + "R X left". Bar colour follows
  state: `--expense` (over), `--warning` (nearing), `--primary` (ok).

### Reports (`reports.html`)
- 5 tabs: Overview, Trends, Categories, Budget, Insights.
  - Overview: income-vs-expenses grouped columns + summary stats.
  - Trends: spending areaspline with a 3-month average line; daily columns.
  - Categories: donut + horizontal bar.
  - Budget: budget-vs-actual grouped columns.
  - Insights: coloured insight banners (positive/warning/info) — reuse the
    existing `InsightCard` component styling.

### Settings (`settings.html`)
- Appearance: **palette picker** + **dark-mode toggle**.
- Preferences: currency, budget alert threshold, week-start.
- Data: Export / Import / Reset (the JSON backup is the only mobile↔web bridge —
  keep this prominent). Reset uses `.btn.danger`.

### Add/Edit transaction modal (`transaction-modal.html`)
- Income/Expense **segmented toggle**, large amount field with currency prefix,
  description, category + date, optional note.
- Smart-category **suggestion chip** (reuse the existing categorisation
  suggestion logic) and a "Make recurring" affordance.

---

## 6. Charts — mockup vs app

The **mockups use Highcharts** (loaded from CDN) purely so they render
standalone. **The app already uses Recharts** (`recharts` in package.json) — keep
Recharts. The important part to carry over is the **styling**, not the library:

- Resolve colours from CSS tokens at render time rather than hardcoding, e.g.
  `getComputedStyle(document.documentElement).getPropertyValue('--primary').trim()`,
  so charts re-theme on palette/mode switch (the mockups do exactly this).
- Grouped columns: `--income` vs `--expense` (overview), `--surface-3` (budget)
  vs `--primary` (actual).
- Category series palette used in mockups:
  `#10b981, #3b82f6, #f59e0b, #8b5cf6, #64748b` (+ the existing `PIE_COLORS` in
  `Reports.tsx` for longer lists).
- Donut: `innerSize ~62%`, 2px border in `--surface` between slices.
- Keep chart backgrounds transparent so the page surface shows through.

---

## 7. Implementation order (suggested)

1. Add `--surface-3` to `index.css` if missing; confirm all tokens resolve.
2. Apply the shell/sidebar changes (`Layout.tsx`) — gradient mark, active accent
   bar, sidebar footer.
3. Dashboard (hero, stat tiles, donut, budget alerts).
4. Transactions, Categories, Budgets (shared row/card/progress components).
5. Reports (restyle Recharts with token-resolved colours).
6. Settings + Add/Edit modal (segmented control, pickers, toggles).

Nothing here changes the API, data model, routes, or the backup schema
(`schemaVersion: 1`). It's purely presentational.
