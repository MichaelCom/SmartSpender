# Web Version API Contract — SmartSpender Web (mono-repo `webapp/`)

A web counterpart to the offline Flutter mobile app, with FULL PARITY. Three
layers built in parallel, each owning a subdirectory under `webapp/`:

- **db**       → `webapp/db/`        Postgres schema, migrations, seed, Dockerfile
- **api**      → `webapp/api/`        Node + TypeScript REST API (+ ported analytics)
- **frontend** → `webapp/frontend/`   React app (Vite + TypeScript)

Infra (`webapp/docker-compose.yml`, root `.env`, glue) is owned by the ORCHESTRATOR,
not an agent. No agent edits another agent's subdirectory.

The mobile app is UNCHANGED and is NOT touched by this work. The two apps never
talk over the network; the only bridge is the JSON backup file (import/export).

================================================================================
## 0. Global conventions
================================================================================
- Language: TypeScript everywhere (api + frontend). Node 20+.
- API base URL: `http://localhost:4000` (api). Frontend dev server: `5173`.
- All money amounts: numbers (double), 2 decimals on display. NO FX conversion.
- Dates over the wire: ISO-8601 strings (UTC where applicable), matching the
  mobile backup format.
- IDs: integer, Postgres SERIAL/BIGSERIAL, auto-increment (mirrors mobile).
- Errors: JSON `{ "error": "message" }` with appropriate HTTP status.
- CORS: api allows the frontend origin.

================================================================================
## 1. Postgres schema (owned by db) — mirrors the Flutter Drift schema
================================================================================
Tables (snake_case columns; the API maps to camelCase JSON):

categories(
  id            SERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  type          TEXT NOT NULL CHECK (type IN ('income','expense')),
  color         TEXT,
  icon          TEXT,
  created_at    TIMESTAMPTZ NOT NULL
)

transactions(
  id            SERIAL PRIMARY KEY,
  amount        DOUBLE PRECISION NOT NULL,
  description   TEXT,
  category_id   INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  date          TIMESTAMPTZ NOT NULL,
  type          TEXT NOT NULL CHECK (type IN ('income','expense')),
  created_at    TIMESTAMPTZ NOT NULL,
  recurring_id  INTEGER REFERENCES recurring_transactions(id) ON DELETE SET NULL
)

recurring_transactions(
  id                 SERIAL PRIMARY KEY,
  amount             DOUBLE PRECISION NOT NULL,
  description        TEXT,
  category_id        INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  type               TEXT NOT NULL CHECK (type IN ('income','expense')),
  frequency          TEXT NOT NULL CHECK (frequency IN ('daily','weekly','monthly','yearly')),
  start_date         TIMESTAMPTZ NOT NULL,
  end_date           TIMESTAMPTZ,
  last_generated_date TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL
)

budgets(
  id            SERIAL PRIMARY KEY,
  category_id   INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  amount        DOUBLE PRECISION NOT NULL,
  period        TEXT NOT NULL CHECK (period IN ('weekly','monthly','yearly')),
  start_date    TIMESTAMPTZ NOT NULL,
  end_date      TIMESTAMPTZ NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL,
  description   TEXT
)

Notes:
- FK semantics MUST match mobile: deleting a category sets transactions &
  recurring category_id to NULL (kept) but CASCADE-deletes its budgets.
- transactions.recurring_id FK requires recurring_transactions to be created
  first (or add the FK after). db agent decides ordering/migration.
- Provide: a migration/DDL file, a seed script (optional demo data), and a
  Dockerfile OR rely on the official postgres image in compose (db agent writes
  an `init.sql` the official image runs on first boot — simplest). Expose 5432.
- Connection via env: POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB (defaults:
  smartspender / smartspender / smartspender).

================================================================================
## 2. REST API (owned by api) — camelCase JSON resources
================================================================================
Resource JSON shapes (returned by GET, accepted by POST/PATCH minus id/created):

Category    { id, name, type, color?, icon?, createdAt }
Transaction { id, amount, description?, categoryId?, date, type, createdAt,
              recurringId?, categoryName?, categoryIcon?, categoryColor? }
              (categoryName/Icon/Color are JOINed read-only fields)
Budget      { id, categoryId, amount, period, startDate, endDate, createdAt,
              description?, categoryName?, categoryIcon?, categoryColor? }
Recurring   { id, amount, description?, categoryId?, type, frequency,
              startDate, endDate?, lastGeneratedDate?, createdAt }

### CRUD
GET    /categories            (?type=income|expense)
POST   /categories
PATCH  /categories/:id
DELETE /categories/:id        (SET NULL on txns/recurring, CASCADE budgets)

GET    /transactions          (?type= &categoryId= &from=ISO &to=ISO &search=)
GET    /transactions/:id
POST   /transactions
PATCH  /transactions/:id
DELETE /transactions/:id

GET    /budgets               (?categoryId=)
POST   /budgets
PATCH  /budgets/:id
DELETE /budgets/:id

GET    /recurring
POST   /recurring
PATCH  /recurring/:id
DELETE /recurring/:id
POST   /recurring/generate    -> { created: <int> }   (on-demand catch-up)

### Analytics / insights (ported logic — see §4)
GET /analytics/summary                (?from= &to=) -> { income, expenses, balance }
GET /analytics/expenses-by-category   (?from= &to=) -> { "<categoryName>": amount, ... }
GET /insights                         (?top=1 for single) -> Insight[] | Insight|null
GET /anomalies                        -> SpendingAnomaly[]
GET /forecast                         -> { month: MonthForecast, budgets: BudgetForecast[] }
GET /categorize?description=&type=    -> CategorySuggestion | null

### Bridge
POST /import     body = mobile backup JSON (schemaVersion 1) -> REPLACE all data,
                 remap IDs; returns { categoriesImported, transactionsImported,
                 budgetsImported }. MUST accept the EXACT mobile format in §3.
GET  /export                 -> the same JSON (schemaVersion 1 shape) + recurring
                                under an OPTIONAL "recurring" array (see §3 note)
GET  /export/transactions.csv -> CSV (RFC-4180), columns:
                                 date(YYYY-MM-DD),type,amount(2dp),category,description
DELETE /data                 -> clear ALL data (parity with mobile "Clear All Data")

================================================================================
## 3. Import/Export JSON format (the bridge — fixed, matches mobile)
================================================================================
Mobile exports exactly this (schemaVersion 1). The web /import MUST read it, and
/export MUST produce a compatible document.

{
  "schemaVersion": 1,
  "app": "SmartSpender",
  "exportedAt": "<ISO-8601 UTC>",
  "categories":   [ { "id", "name", "type", "color", "icon", "createdAt" } ],
  "transactions": [ { "id", "amount", "description", "categoryId", "date",
                      "type", "createdAt" } ],
  "budgets":      [ { "id", "categoryId", "amount", "period", "startDate",
                      "endDate", "createdAt", "description" } ]
}

Import rules (mirror mobile restoreFromJson):
- Validate: root is object; schemaVersion === 1; categories/transactions/budgets
  are arrays. Reject otherwise with 400.
- REPLACE: clear all tables, then insert. Build an oldCategoryId -> newId map as
  categories are inserted; remap transaction.categoryId (null stays null /
  unknown -> null) and budget.categoryId (skip budgets whose category is
  missing). Transactions with unknown/absent categoryId import as uncategorised.
- The mobile v1 backup does NOT contain recurring transactions. On import,
  recurring is simply absent (fine). On /export, ALSO include a "recurring"
  array (web extension) so web->web keeps recurring; a mobile import will ignore
  unknown keys. Keep schemaVersion = 1 for mobile compatibility.

================================================================================
## 4. Ported analytics logic (owned by api) — behavioural parity with mobile
================================================================================
Port these PURE functions from the Dart engine (lib/services/insights/*) to TS,
preserving semantics EXACTLY. Reference the Dart source + its tests for expected
outputs; add TS unit tests mirroring the Dart test cases.

- Categorization: seed keyword map (COPY the exact map from
  categorization_engine.dart) + history learning; history overrides seed; min 2
  history matches to be confident; returns { categoryId, reason, fromHistory }.
- Anomaly: per-category z-score on expense amounts; minSamples=6, zThreshold=2.0,
  above-mean only; returns { transaction, zScore, categoryMean, timesTypical }.
- Forecast: forecastBudget = spentSoFar + remainingRecurring + run-rate on
  discretionary (non-recurring) spend; forecastMonth similarly. EARLY-MONTH note
  is a UI concern (frontend), not the engine.
- Insights: compose savings-rate, biggest-category, top-mover (vs last month),
  anomaly roll-up, forecast roll-up; each with a priority; `top=1` returns the
  highest-priority. Reuse anomaly + forecast. Accept a currencySymbol for the
  rendered strings.
Pin: minSamples=6, zThreshold=2.0, minHistoryMatches=2, insight priorities match
the Dart source.

================================================================================
## 5. Frontend (owned by frontend) — full parity screens
================================================================================
React + Vite + TypeScript. Talks ONLY to the api (no direct DB). Screens mirror
mobile:
- Dashboard: month income/expense/balance cards, top categories, budget-alert
  summary, top insight (tap -> Reports Insights), quick add.
- Transactions: list (filter type, date, search), add/edit/delete, the
  auto-categorization suggestion chip (calls GET /categorize), anomaly flags
  (from GET /anomalies) with inline "Unusually large" + explanation.
- Categories: list/filter/add/edit/delete (name, type, icon, color).
- Budgets: list with progress + reactive alert colouring + a muted projection
  line (from GET /forecast; suppress when <4 days elapsed in the month).
- Reports: Overview, Trends, Categories, Budget, Insights tabs (charts via a JS
  charting lib, e.g. Recharts).
- Settings: theme (System/Light/Dark), currency picker, budget-alert threshold —
  persisted in localStorage. Plus a Data section: Export JSON, Export CSV,
  Import (file upload -> POST /import, replace-confirm dialog), Clear All Data.
Currency: port AppCurrencies list + CurrencyFormatter (format/formatSigned/
formatCompact) to TS, EXACT same symbols/formatting as mobile.
Budget-alert threshold default 80; dark mode default System.

================================================================================
## 6. Docker (owned by ORCHESTRATOR, but agents must enable it)
================================================================================
Target: `cd webapp && docker compose up` brings up db + api + frontend, reachable
at localhost. Each agent MUST provide what compose needs from its subdir:
- db: an `init.sql` (DDL + optional seed) consumable by the official `postgres`
  image, OR a Dockerfile; document the expected env vars.
- api: a Dockerfile (node:20-alpine), listens on 4000, reads DB connection from
  env (DATABASE_URL or discrete POSTGRES_* vars), has `npm run build`/`start` and
  `npm run dev`, and a wait-for-db / retry on startup.
- frontend: a Dockerfile (build with Vite; served via a static server or `vite
  preview`) on 5173, with the API base URL from an env var (VITE_API_URL).
The orchestrator writes docker-compose.yml tying them together + a webapp/README.

================================================================================
## 7. Ownership (STRICT — no agent touches another's subdir)
================================================================================
- db:       ONLY files under webapp/db/
- api:      ONLY files under webapp/api/
- frontend: ONLY files under webapp/frontend/
- NONE of them edit webapp/docker-compose.yml or anything OUTSIDE webapp/ (the
  Flutter app at repo root is OFF-LIMITS).
Each agent: build + typecheck + run its own tests before reporting done. The
orchestrator wires compose, runs the full stack, and verifies end-to-end
(including importing a real mobile backup).

================================================================================
## 8. Verification (orchestrator, after merge)
================================================================================
- `cd webapp && docker compose up --build` → all three services healthy.
- Smoke: create a category/transaction/budget via the UI; GET /insights returns;
  POST /import with a mobile backup JSON replaces data and the UI reflects it;
  GET /export round-trips; CSV export opens.
