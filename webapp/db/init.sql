-- SmartSpender Web — Postgres schema
-- Mirrors the Flutter Drift schema (lib/database/app_database.dart) EXACTLY.
--
-- This file is consumed by the official `postgres` Docker image: any *.sql /
-- *.sh file placed in /docker-entrypoint-initdb.d/ is executed, in alphabetical
-- order, ONLY on first boot (when the data directory is empty). This DDL is
-- idempotent (IF NOT EXISTS) so re-running against an existing DB is harmless.
--
-- Column casing is snake_case; the API maps to camelCase JSON.
-- Money is DOUBLE PRECISION (Drift `real()`), dates are TIMESTAMPTZ.
--
-- FK semantics (MUST match mobile):
--   * delete a category -> SET NULL on transactions.category_id &
--     recurring_transactions.category_id (rows kept, uncategorised)
--   * delete a category -> CASCADE delete its budgets
--   * delete a recurring rule -> SET NULL on transactions.recurring_id

BEGIN;

-- ---------------------------------------------------------------------------
-- categories
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    type        TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    color       TEXT,
    icon        TEXT,
    created_at  TIMESTAMPTZ NOT NULL
);

-- ---------------------------------------------------------------------------
-- recurring_transactions
-- Created BEFORE transactions so transactions.recurring_id can reference it
-- inline (mirrors the Drift ordering / FK requirement).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recurring_transactions (
    id                   SERIAL PRIMARY KEY,
    amount               DOUBLE PRECISION NOT NULL,
    description          TEXT,
    category_id          INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    type                 TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    frequency            TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
    start_date           TIMESTAMPTZ NOT NULL,
    end_date             TIMESTAMPTZ,
    last_generated_date  TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL
);

-- ---------------------------------------------------------------------------
-- transactions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
    id            SERIAL PRIMARY KEY,
    amount        DOUBLE PRECISION NOT NULL,
    description   TEXT,
    category_id   INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    date          TIMESTAMPTZ NOT NULL,
    type          TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    created_at    TIMESTAMPTZ NOT NULL,
    recurring_id  INTEGER REFERENCES recurring_transactions(id) ON DELETE SET NULL
);

-- ---------------------------------------------------------------------------
-- budgets
-- A budget always belongs to a category -> CASCADE delete with the category.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS budgets (
    id            SERIAL PRIMARY KEY,
    category_id   INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    amount        DOUBLE PRECISION NOT NULL,
    period        TEXT NOT NULL CHECK (period IN ('weekly', 'monthly', 'yearly')),
    start_date    TIMESTAMPTZ NOT NULL,
    end_date      TIMESTAMPTZ NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL,
    description   TEXT
);

-- ---------------------------------------------------------------------------
-- Indexes (mirror the Drift @TableIndex declarations)
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions (category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date     ON transactions (date);
CREATE INDEX IF NOT EXISTS idx_transactions_recurring ON transactions (recurring_id);
CREATE INDEX IF NOT EXISTS idx_recurring_category    ON recurring_transactions (category_id);
CREATE INDEX IF NOT EXISTS idx_budgets_category      ON budgets (category_id);

COMMIT;
