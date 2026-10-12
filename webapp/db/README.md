# SmartSpender Web — Database layer (`webapp/db/`)

Postgres schema for the web version of SmartSpender. Mirrors the Flutter Drift
schema (`lib/database/app_database.dart`) **exactly** — same tables, columns,
types, CHECK constraints, indexes, and foreign-key semantics.

## Files

| File       | Purpose                                                                 |
|------------|-------------------------------------------------------------------------|
| `init.sql` | DDL: `categories`, `recurring_transactions`, `transactions`, `budgets` + indexes. Idempotent (`IF NOT EXISTS`). |
| `seed.sql` | **Optional** demo data — the 11 default categories from the mobile app plus a few sample transactions/budget. Guarded to no-op on a non-empty DB. |

## How it's consumed (official `postgres` image)

The official `postgres` image runs any `*.sql` / `*.sh` file found in
`/docker-entrypoint-initdb.d/` **once, on first boot** (when the data volume is
empty), in alphabetical filename order. The orchestrator's `docker-compose.yml`
mounts this directory in:

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-smartspender}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-smartspender}
      POSTGRES_DB: ${POSTGRES_DB:-smartspender}
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      # Schema — always applied on first boot:
      - ./db/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro
      # Optional demo data — mount only if you want seeded data:
      # - ./db/seed.sql:/docker-entrypoint-initdb.d/02-seed.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-smartspender} -d ${POSTGRES_DB:-smartspender}"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  pgdata:
```

Mounting `init.sql` as `01-init.sql` ensures it runs before `02-seed.sql`.
`init.sql` runs by default; `seed.sql` runs **only** if the orchestrator chooses
to mount it (left commented above). A fresh DB therefore starts empty by
default, matching the mobile app (which seeds default categories from the app
layer, not the DB).

> Init scripts run only when the data directory is empty. To re-apply after
> changing the schema, remove the volume: `docker compose down -v`.

## Environment variables

Connection is configured entirely through the standard Postgres image env vars.
Defaults match the contract.

| Variable            | Default         | Description                 |
|---------------------|-----------------|-----------------------------|
| `POSTGRES_USER`     | `smartspender`  | DB role / owner             |
| `POSTGRES_PASSWORD` | `smartspender`  | Password for that role      |
| `POSTGRES_DB`       | `smartspender`  | Database name               |

The API layer connects using these (or a composed `DATABASE_URL`), e.g.:

```
DATABASE_URL=postgres://smartspender:smartspender@db:5432/smartspender
```

Exposed port: **5432**.

## Schema summary

```
categories(id, name, type[income|expense], color?, icon?, created_at)
recurring_transactions(id, amount, description?, category_id?→categories SET NULL,
    type[income|expense], frequency[daily|weekly|monthly|yearly],
    start_date, end_date?, last_generated_date?, created_at)
transactions(id, amount, description?, category_id?→categories SET NULL,
    date, type[income|expense], created_at,
    recurring_id?→recurring_transactions SET NULL)
budgets(id, category_id→categories CASCADE, amount,
    period[weekly|monthly|yearly], start_date, end_date, created_at, description?)
```

### Foreign-key semantics (must match mobile)

- Delete a **category** → `transactions.category_id` and
  `recurring_transactions.category_id` become `NULL` (rows kept,
  uncategorised); its **budgets** are **CASCADE-deleted**.
- Delete a **recurring rule** → `transactions.recurring_id` becomes `NULL`
  (generated transactions are kept).

`recurring_transactions` is created before `transactions` so the
`transactions.recurring_id` FK can be declared inline.

### Indexes

`idx_transactions_category`, `idx_transactions_date`,
`idx_transactions_recurring`, `idx_recurring_category`, `idx_budgets_category`.

## Local validation

Both files were validated against PostgreSQL by applying `init.sql` + `seed.sql`
to a fresh database and asserting:

- all tables/indexes/CHECK constraints create successfully;
- `init.sql` and `seed.sql` are idempotent / re-runnable;
- deleting a category CASCADE-deletes budgets and SET-NULLs its transactions &
  recurring rules;
- deleting a recurring rule SET-NULLs `transactions.recurring_id`;
- CHECK constraints reject invalid `type` / `frequency` / `period`, and
  `budgets.category_id` NOT NULL is enforced.
