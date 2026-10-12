# SmartSpender Web

A local, Dockerized web counterpart to the offline Flutter mobile app, with full
feature parity. It is a **separate application** — the mobile and web apps never
communicate over the network. The only bridge between them is the JSON backup
file (Export on one, Import on the other).

## Stack
- **db** — Postgres 16 (schema mirrors the mobile Drift schema)
- **api** — Node + TypeScript REST API (`http://localhost:4000`)
- **frontend** — React + Vite + TypeScript (`http://localhost:5173`)

## Run it

```bash
cd webapp
docker compose up --build
```

Then open http://localhost:5173. The API is at http://localhost:4000.

To load demo data on first boot, uncomment the `seed.sql` volume line in
`docker-compose.yml` before the first `up` (seeds run only when the db volume is
first created).

Reset everything (including the database):

```bash
docker compose down -v
```

## Moving data between mobile and web
- **Mobile → web:** export a backup in the mobile app, then use Settings →
  Data → Import in the web app (file upload). Import **replaces** all web data.
- **Web → mobile:** export from the web app (Settings → Data → Export), then use
  the mobile app's restore.

The backup format is `schemaVersion: 1`, matching the mobile app. The web export
additionally includes a `recurring` array (ignored by the mobile import, which
is forward-compatible). Note: the current mobile backup does not yet carry
recurring transactions — see the project notes if you want that extended.

## Development (without Docker)
Each service can run on its own:
- `cd db` — see `db/README.md` for running Postgres + loading `init.sql`.
- `cd api && npm install && npm run dev` (needs a reachable Postgres via env).
- `cd frontend && npm install && npm run dev` (set `VITE_API_URL`).
