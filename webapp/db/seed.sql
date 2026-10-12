-- SmartSpender Web — OPTIONAL demo/seed data
--
-- This file is NOT auto-run by the postgres image unless you explicitly mount it
-- into /docker-entrypoint-initdb.d/ (see webapp/db/README.md). It is kept
-- separate from init.sql so a fresh database starts EMPTY by default — matching
-- the mobile app, which seeds default categories from the app layer, not the DB.
--
-- Contents: the exact default category set the mobile app creates on first run
-- (lib/providers/category_provider.dart -> initializeDefaultCategories), plus a
-- few sample transactions so analytics/insights endpoints have data to chew on.
--
-- Safe to run only on an EMPTY database (it assumes SERIAL ids start at 1).
-- Guarded so it no-ops if categories already exist.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM categories LIMIT 1) THEN
        RAISE NOTICE 'categories already present; skipping seed.';
        RETURN;
    END IF;

    -- Default categories (same names/types/colors/icons as the mobile app).
    INSERT INTO categories (name, type, color, icon, created_at) VALUES
        ('Salary',           'income',  '#4CAF50', 'work',            now()),
        ('Investment',       'income',  '#FF9800', 'trending_up',     now()),
        ('Other Income',     'income',  '#9C27B0', 'attach_money',    now()),
        ('Food & Dining',    'expense', '#F44336', 'restaurant',      now()),
        ('Transportation',   'expense', '#3F51B5', 'directions_car',  now()),
        ('Shopping',         'expense', '#E91E63', 'shopping_bag',    now()),
        ('Entertainment',    'expense', '#9C27B0', 'movie',           now()),
        ('Bills & Utilities','expense', '#607D8B', 'receipt',         now()),
        ('Healthcare',       'expense', '#4CAF50', 'local_hospital',  now()),
        ('Education',        'expense', '#FF9800', 'school',          now()),
        ('Other Expenses',   'expense', '#795548', 'category',        now());

    -- A handful of sample transactions in the current month (ids resolved by name).
    INSERT INTO transactions (amount, description, category_id, date, type, created_at)
    SELECT v.amount, v.description, c.id, v.date, v.type, now()
    FROM (VALUES
        (3500.00, 'Monthly salary deposit', 'Salary',          date_trunc('month', now()) + interval '1 day',  'income'),
        (  85.40, 'Weekly groceries',       'Food & Dining',   date_trunc('month', now()) + interval '3 days', 'expense'),
        (  42.10, 'Fuel',                   'Transportation',  date_trunc('month', now()) + interval '5 days', 'expense'),
        (  19.99, 'Streaming subscription', 'Entertainment',   date_trunc('month', now()) + interval '6 days', 'expense'),
        ( 120.00, 'Electricity bill',       'Bills & Utilities', date_trunc('month', now()) + interval '8 days', 'expense'),
        (  60.00, 'New shoes',              'Shopping',        date_trunc('month', now()) + interval '10 days','expense')
    ) AS v(amount, description, cat_name, date, type)
    JOIN categories c ON c.name = v.cat_name;

    -- A sample monthly budget on Food & Dining.
    INSERT INTO budgets (category_id, amount, period, start_date, end_date, created_at, description)
    SELECT c.id, 400.00, 'monthly',
           date_trunc('month', now()),
           (date_trunc('month', now()) + interval '1 month' - interval '1 day'),
           now(), 'Monthly food budget'
    FROM categories c WHERE c.name = 'Food & Dining';
END $$;
