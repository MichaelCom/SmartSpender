# SmartSpender Web — Frontend

React + Vite + TypeScript single-page app. Full parity with the offline Flutter
mobile app. Talks **only** to the REST API at `VITE_API_URL` (never the DB).

## Screens

- **Dashboard** — month income/expense/balance cards, top categories,
  budget-alert summary, top insight (tap → Reports → Insights), quick add.
- **Transactions** — list with type/date/category/search filters, add/edit/delete,
  the auto-categorization suggestion chip (`GET /categorize`), and inline anomaly
  flags (`GET /anomalies`, "Unusually large" + explanation).
- **Categories** — list/filter/add/edit/delete with the exact mobile icon + color
  palettes.
- **Budgets** — progress bars with reactive alert colouring (threshold-driven) and
  a muted forecast projection marker from `GET /forecast`, suppressed when fewer
  than 4 days have elapsed in the month.
- **Reports** — Overview, Trends, Categories, Budget, and Insights tabs (charts via
  Recharts).
- **Settings** — theme (System/Light/Dark), currency picker, budget-alert threshold
  (all persisted in `localStorage`), plus a Data section: Export JSON (`GET /export`),
  Export CSV (`GET /export/transactions.csv`), Import (`POST /import`, with a
  replace-confirm dialog), and Clear All Data (`DELETE /data`).

## Parity ports

- `src/lib/currency.ts` — exact TypeScript port of `lib/utils/currency.dart`
  (`AppCurrencies` + `CurrencyFormatter.format/formatSigned/formatCompact`), with
  the same symbols and formatting. Covered by `src/test/currency.test.ts`.
- Defaults match mobile: currency `ZAR`, theme `System`, budget-alert threshold `80`.

## Environment

| Var            | Default                 | Notes                                 |
| -------------- | ----------------------- | ------------------------------------- |
| `VITE_API_URL` | `http://localhost:4000` | API base URL (inlined at build time). |

## Scripts

```bash
npm install
npm run dev        # dev server on 5173
npm run build      # tsc -b && vite build
npm run typecheck  # tsc -b --noEmit
npm run test       # vitest run
npm run preview    # serve the production build on 5173
```

## Docker

The `Dockerfile` builds with Vite and serves the static build via `vite preview`
on port **5173**. Pass the API URL at build time:

```bash
docker build --build-arg VITE_API_URL=http://localhost:4000 -t smartspender-frontend .
docker run -p 5173:5173 smartspender-frontend
```

The orchestrator's `webapp/docker-compose.yml` wires this together with the `api`
and `db` services.
