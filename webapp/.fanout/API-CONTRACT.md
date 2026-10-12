# Web Redesign — API Contract (Batch: frontend visual overhaul)

Implements the mockups in `Docs/smartspender-mockups/web/` (and the spec
`Docs/smartspender-mockups/DESIGN.md`) in `webapp/frontend`. PURELY
PRESENTATIONAL — no API, data model, route, or backup-schema changes. Two agents
build in parallel against this contract.

### REFERENCE THE REAL MOCKUPS FIRST (authoritative)
The design source of truth is the HTML mockups + shared CSS:
- `Docs/smartspender-mockups/theme.css`  (the full token + shared-class system
  to port into webapp/frontend/src/index.css — it matches the current tokens and
  adds the refined components)
- `Docs/smartspender-mockups/web/dashboard.html`      (flagship layout)
- `Docs/smartspender-mockups/web/transactions.html`
- `Docs/smartspender-mockups/web/categories.html`
- `Docs/smartspender-mockups/web/budgets.html`
- `Docs/smartspender-mockups/web/reports.html`
- `Docs/smartspender-mockups/web/settings.html`
- `Docs/smartspender-mockups/web/transaction-modal.html`
Each mockup inlines the same tokens + classes and shows the exact markup
structure to reproduce. The `.mockbar` palette/mode switcher and the inlined
`<style>` token blocks are MOCKUP-ONLY — the real app already drives
data-theme/data-palette from Settings and keeps tokens in index.css. IGNORE the
`Docs/smartspender-mockups/mobile/` folder entirely (mobile is a later pass).

Match the mockups closely: hero card with decorative circles + sparkline, stat
tiles with icon chips + trend deltas, donut + legend, progress-bar budget alerts
with status badges, polished rows, segmented toggle, pickers, switches.

Stack: React 18 + Vite + TS, React Router, Recharts. Theme system already exists:
`html[data-theme=light|dark]` (mode) + `html[data-palette=fresh|premium|warm|calm]`
(brand). Build/verify with:
  cd webapp/frontend && npm install && npm run build   (tsc + vite, 0 errors)

================================================================================
## OWNERSHIP (no file edited by both)
================================================================================

### Agent "shell" owns ONLY:
- webapp/frontend/src/index.css            (ALL styling lives here — single owner)
- webapp/frontend/src/components/Layout.tsx (sidebar: gradient mark, active accent
  bar, NEW sidebar footer with gradient avatar + account label)
- webapp/frontend/src/components/common.tsx (shared Spinner/ErrorBanner/Empty +
  any new shared presentational helpers e.g. ProgressBar, StatTile, Badge,
  Donut wrapper, Sparkline — see "shared components" below)
- webapp/frontend/src/components/Modal.tsx  (modal shell styling hooks)
- webapp/frontend/src/components/InsightCard.tsx (kind-coloured banner styling)

### Agent "screens" owns ONLY:
- webapp/frontend/src/screens/Dashboard.tsx
- webapp/frontend/src/screens/Transactions.tsx
- webapp/frontend/src/screens/Categories.tsx
- webapp/frontend/src/screens/Budgets.tsx
- webapp/frontend/src/screens/Reports.tsx
- webapp/frontend/src/screens/Settings.tsx
- webapp/frontend/src/components/TransactionForm.tsx (the add/edit modal body:
  segmented income/expense toggle, amount w/ currency prefix, pickers, suggestion
  chip, "make recurring")

### Neither agent touches:
- api/, context/SettingsContext.tsx (theme system is done), lib/*, hooks/*,
  api/client.ts, api/types.ts, App.tsx, main.tsx, anything outside webapp/frontend.
  (If a screen truly needs a new SettingsContext value it must STOP and ask — but
  it should not; everything needed already exists.)

### The seam (how they avoid colliding on CSS):
- shell defines the COMPLETE class vocabulary below in index.css.
- screens apply those classes; for dynamic/one-off values (category colour, bar
  width %, chart colours) screens use inline `style={{...}}` as the current code
  already does — screens NEVER edit index.css.
- If a screen needs a class shell didn't provide, prefer an inline style; do not
  edit index.css.

================================================================================
## SHARED CLASS VOCABULARY — shell MUST provide all of these (index.css)
================================================================================
From the handoff §4. shell implements/updates each; screens rely on them.

App shell:        .app .sidebar .content
Sidebar nav:      .nav-link .nav-link.active .nav-ico
                  (active: --primary-soft bg + gradient accent bar via ::before)
Brand:            .brand .brand-mark
Sidebar footer:   .side-foot .side-user .avatar     (NEW)
Page header:      .spread .page-title .page-sub .header-actions
Buttons:          .btn .btn.primary .btn.ghost .btn.danger .btn.sm
                  (.primary = gradient fill + ring shadow)
Cards:            .card .card-head .card-title .link
Stat tiles:       .stat-grid .stat  + dashboard: .ic .trend .up .down
Lists/rows:       .list .row .chip-ic .amount (+ .income/.expense)
                  (.chip-ic = category-colour icon chip)
Chips/filters:    .chip .chip.on
Badges:           .badge .badge.over .badge.near .badge.ok
Progress:         .progress  .progress .bar   (bar colour set inline per state)
Tabs:             .tabs .tab .tab.active       (underline, Reports)
Chart box:        .chart-box                    (Reports chart container)
Table:            .tbl                          (uppercase muted headers, hover rows)
Modal:            .modal-backdrop .modal .form-row .form-grid .modal-actions
Segmented ctrl:   .seg .seg .on-inc .seg .on-exp
Pickers:          .swatch-grid .swatch  .icon-grid .icon-pick
Toggle switch:    .switch .switch.on
Settings row:     .set-row
Palette picker:   .palette-grid .palette-option .palette-swatch  (already exists;
                  keep/refine)
Misc already present: .section-gap .grid-2 .form-row .form-grid .toolbar .badge

Token note: ADD `--surface-3` to index.css if missing (light #e9edf3, dark
#263040) under the two mode blocks — used for progress tracks + budget bars.
Keep all existing tokens + the per-palette background patterns intact.

================================================================================
## SHARED PRESENTATIONAL COMPONENTS (shell builds; screens import)
================================================================================
shell adds these to common.tsx (or a new components file it owns) so screens can
compose charts/progress without duplicating logic:

- ProgressBar({ value, max, state }) -> renders .progress/.bar; state in
  'ok'|'near'|'over' maps to --primary / --warning / --expense inline.
- StatTile({ label, value, icon?, trend? }) -> .stat with optional .ic + .trend.
- Badge({ kind, children }) -> .badge.(ok|near|over).
- Donut({ data: {label,value,color}[] }) -> a Recharts PieChart (innerRadius ~62%,
  2px --surface stroke, transparent bg) + legend. Colours resolved from tokens /
  passed in.
- Sparkline({ values }) -> small Recharts bar/area for the dashboard hero 30-day
  flow. Transparent bg, --on-brand-tinted bars (it sits on the gradient hero).

screens MUST import these rather than re-implementing. If shell names them
differently, it documents the export names in a comment at the top of common.tsx.

================================================================================
## CHARTS (both agents) — Recharts, token-resolved colours
================================================================================
Per handoff §6: resolve colours at render via
getComputedStyle(document.documentElement).getPropertyValue('--primary').trim()
so charts re-theme on palette/mode switch. Grouped columns: --income vs --expense
(overview), --surface-3 (budget) vs --primary (actual). Category series:
#10b981,#3b82f6,#f59e0b,#8b5cf6,#64748b (+ existing PIE_COLORS for long lists).
Donut innerRadius ~62%, transparent chart backgrounds.
- shell owns the reusable Donut/Sparkline wrappers.
- screens own the Reports-specific charts (overview columns, trends areaspline +
  avg line, budget-vs-actual) styled the same way.

================================================================================
## PER-SCREEN WORK (screens agent) — see handoff §5 for full detail
================================================================================
- Dashboard: gradient balance HERO (balance + MoM delta pill + income/spent minis
  + 30-day Sparkline); stat tiles w/ icon chip + trend delta; "Spending by
  category" DONUT + legend (replaces plain list); budget alerts = ProgressBar +
  Badge; recent transactions polished rows.
- Transactions: toolbar (search + Type/Category/Month selects) + quick-filter
  chips; group by month w/ net total on header; rows w/ .chip-ic + signed amount
  + ⋯ actions; pagination footer.
- Categories: responsive card grid (min 300px) — icon chip, name, txn count,
  total, Edit; "New category" modal w/ colour+icon pickers.
- Budgets: summary stat row (budgeted/spent/remaining) + per-budget progress
  cards w/ Badge + "R X left"; bar colour per state.
- Reports: 5 tabs (Overview/Trends/Categories/Budget/Insights) restyled w/
  token-resolved Recharts; Insights reuse InsightCard styling.
- Settings: Appearance (palette picker + mode toggle), Preferences (currency,
  threshold, week-start*), Data (Export/Import/Reset prominent; +Load Demo Data
  which already exists). (*week-start is cosmetic; only add if trivial, else skip.)
- TransactionForm modal: segmented income/expense toggle, big amount w/ currency
  prefix, description, category+date, optional note, suggestion chip, make-recurring.

================================================================================
## RULES
================================================================================
- Purely presentational. Do NOT change API calls, data shapes, routes, or the
  backup schema. Preserve all existing behaviour (filters, add/edit/delete, demo
  seed, import/export, theme switching).
- Everything must keep working across all 4 palettes x light/dark. Never hardcode
  brand hex — use tokens (or the constant --income/--expense/--warning/--info).
- Each agent: `npm run build` with ZERO TypeScript errors before reporting done,
  and keep `src/test` passing (npm test). Orchestrator does final build + Docker
  verify + commits/merges.
