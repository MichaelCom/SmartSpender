# SmartSpender Mobile (Flutter) — Design Handoff

A redesign of the SmartSpender **mobile** app (`lib/`, Flutter + Material 3,
Provider, Drift). Goal: a nicer look & feel that matches the web redesign's
visual language, expressed in native Flutter/Material idioms. Functionality,
data model, routes and the backup schema are unchanged — this is purely
presentational.

> Web ↔ mobile are fully independent apps. The only bridge is the JSON backup
> (Export/Import). The web redesign lives one level up in
> `../web/` + `../DESIGN.md` + `../theme.css`.

---

## 1. Files in this handoff (`mobile/`)

| File | Screen / route in app |
|------|-----------------------|
| `theme-mobile.css` | **Token reference** — approximates `ColorScheme.fromSeed(Colors.green)`, light + dark. Maps to Flutter `ColorScheme` roles (see §3). |
| `dashboard.html` | Dashboard tab (`home_screen.dart` → `DashboardTab`) |
| `transactions.html` | Transactions tab (`transaction_list_screen.dart`) |
| `categories.html` | Categories tab (`category_list_screen.dart`) |
| `budgets.html` | Budgets tab (`budget_list_screen.dart`) |
| `reports.html` | Reports tab (`reports_screen.dart`) |
| `settings.html` | Settings (`settings_screen.dart`, pushed route) |
| `add-transaction.html` | Add/Edit transaction (`add_transaction_screen.dart`) |
| `add-category.html` | Add/Edit category (`add_category_screen.dart`) |
| `add-budget.html` | Add/Edit budget (`add_budget_screen.dart`) |
| `add-recurring.html` | Add/Edit recurring (`add_recurring_screen.dart`) |
| `recurring-list.html` | Recurring list (`recurring_list_screen.dart`, popup-menu route) |

Each mockup is rendered inside a **phone frame** with a light/dark toggle
(top-right). The frame and toggle are mockup-only — not part of the app.

---

## 2. What differs from web (read this first)

The mobile app is **not** the web app with a different stylesheet. Key
differences the mockups deliberately honour:

1. **One brand, not four palettes.** Mobile uses
   `ColorScheme.fromSeed(seedColor: Colors.green)` with light + dark only. The
   web's Fresh/Premium/Warm/Calm palette system does **not** exist on mobile.
   Theme is chosen via **System / Light / Dark** radios in Settings
   (`ThemeMode`).
2. **Bottom navigation**, not a sidebar. 5 tabs: Dashboard, Transactions,
   Categories, Budgets, Reports (`BottomNavigationBar`, matches `home_screen`).
   Use the M3 pill-style active indicator.
3. **Settings is a pushed route** (AppBar gear icon), not a tab. **Recurring**
   is a pushed route from the Dashboard overflow (⋮) menu. Both use a back
   arrow and show no bottom nav.
4. **FAB** for primary create actions on list screens.
5. **Material widgets** throughout — `Card`, `ListTile`, `Chip`,
   `SegmentedButton`, `LinearProgressIndicator`, `RadioListTile`,
   `NavigationBar`, `FloatingActionButton`.

---

## 3. Token → Flutter `ColorScheme` mapping

The mockup CSS variables approximate M3 roles. Map them to
`Theme.of(context).colorScheme` — **do not hardcode hex**; let `fromSeed`
generate the scheme so light/dark stays correct.

| Mockup token | Flutter `ColorScheme` role |
|--------------|----------------------------|
| `--primary` | `colorScheme.primary` |
| `--on-primary` | `colorScheme.onPrimary` |
| `--primary-container` | `colorScheme.primaryContainer` |
| `--on-primary-container` | `colorScheme.onPrimaryContainer` |
| `--surface` | `colorScheme.surface` |
| `--surface-container` | `colorScheme.surfaceContainer` |
| `--surface-container-high` | `colorScheme.surfaceContainerHigh` |
| `--on-surface` | `colorScheme.onSurface` |
| `--on-surface-variant` | `colorScheme.onSurfaceVariant` |
| `--outline` | `colorScheme.outline` |
| `--outline-variant` | `colorScheme.outlineVariant` |
| `--inverse-primary` | `colorScheme.inversePrimary` (AppBar tint, as today) |

**Semantic finance colours** stay constant across light/dark (same intent as
web): income green `#2e7d32`, expense red `#c62828`, warning amber `#f9a825`,
info blue `#1565c0`. Define these as app-level constants (they are not part of
the M3 scheme). Category icon-chip colours come from each category's stored
`color` hex, exactly as today.

---

## 4. Shared widgets & styling notes

| Mockup element | Flutter widget | Notes |
|----------------|----------------|-------|
| Phone app bar | `AppBar` | Dashboard keeps the logo + `inversePrimary` background (as today); detail routes use a plain surface AppBar + back arrow. |
| Bottom nav | `NavigationBar` (M3) | Pill indicator = `primaryContainer`/`onPrimaryContainer`. Prefer migrating the current `BottomNavigationBar` to `NavigationBar` for the pill look. |
| Gradient hero | `Container` + `BoxDecoration(gradient:)` | Linear gradient from `primary` → a darker green; `onPrimary` text; rounded 22. Replaces today's blue/orange balance box. |
| Mini stat tiles | `Card` | 2-up row; small tinted icon box + label + value. |
| List rows | `ListTile` or custom `Row` | Leading = coloured icon chip (category colour), title, subtitle, trailing signed amount (`tabular figures`). |
| Filter chips | `ChoiceChip` / `FilterChip` | Horizontal scroller; selected = `primaryContainer`. |
| Progress bars | `LinearProgressIndicator` | Colour by state: expense/warning/primary. |
| Status badges | small `Container` pill | over / nearing / on-track. |
| Segmented income/expense | `SegmentedButton` | Selected segment tinted income-green or expense-red. |
| Colour picker | `Wrap` of circle swatches | The exact 15-colour list from `add_category_screen.dart`. |
| Icon picker | `Wrap` of icon tiles | The exact 20 `IconData` entries from `add_category_screen.dart`. |
| Settings rows | `RadioListTile` / `ListTile` | Theme-mode radios; currency + alert-threshold stepper. |
| FAB | `FloatingActionButton` | `primaryContainer` container colour, rounded 20. |
| Numbers | — | Use tabular figures and the currency symbol from `SettingsController`. |

**Charts (Reports):** mobile currently renders Reports with its own widgets. The
mockup uses Highcharts only to render standalone — **keep whatever chart
approach the app uses** and carry over the *styling*: income/expense colour
pairing, the category palette, transparent backgrounds, donut inner-radius
~60%. Resolve colours from the active `ColorScheme` so charts adapt to
light/dark.

---

## 5. Per-screen notes

- **Dashboard** — gradient "Money left over" hero (keeps the existing savings-%
  pill); 2-up income/expense mini tiles; budget-alert banner (tap → Budgets,
  index 3); recent transactions. Quick actions (Add income / Add expense) stay.
- **Transactions** — filter-chip scroller; list grouped by day
  (Today/Yesterday/Earlier); FAB to add; search + export in the AppBar.
- **Categories** — single card list of category rows (icon chip, name, txn
  count, total); FAB → Add category.
- **Budgets** — budgeted/spent mini tiles; per-budget cards with progress bar +
  status badge; FAB → Add budget.
- **Reports** — chip tabs (Overview/Trends/Categories/Budget/Insights);
  income-vs-expense columns + spending donut; insight banners.
- **Settings** — System/Light/Dark radios (`ThemeMode`); currency picker row;
  alert-threshold stepper; Data section (Export / Import / Clear all — the JSON
  backup is the only mobile↔web bridge). Clear-all is destructive (red).
- **Add transaction** — expense/income `SegmentedButton`; large amount field;
  description; category chips; date; optional note; smart-category suggestion.
- **Add category** — live preview; type toggle; name; 15-swatch colour picker;
  20-icon picker (exact lists from the app).
- **Add budget** — category chips; amount; period Weekly/Monthly/Yearly; start
  date; **auto-derived** end date; conflict-warning note.
- **Add recurring** — expense/income toggle; amount; description; category;
  frequency Daily/Weekly/Monthly/Yearly; start date; optional end date;
  plain-language summary.
- **Recurring list** — active rules with 🔁 frequency + next-run subtitle; add
  in AppBar; pushed route (back arrow, no bottom nav).

---

## 6. Implementation order (suggested)

1. Confirm `ColorScheme.fromSeed(Colors.green)` light/dark; add the 4 semantic
   finance constants.
2. Migrate `BottomNavigationBar` → `NavigationBar` (pill indicator).
3. Dashboard (gradient hero, mini tiles, alert banner, recent list).
4. List screens (Transactions, Categories, Budgets) — shared row/card/progress
   widgets.
5. Reports styling.
6. Forms (transaction, category, budget, recurring) + Settings + Recurring list.

Nothing here changes models, providers, Drift schema, routes, or the backup
format (`schemaVersion: 1`).
