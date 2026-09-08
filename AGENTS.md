# Agent notes

Rails 8.1 app for Omarchy hardware compatibility and classifieds.

## Run

- `docker compose -f compose.yaml up -d` — Postgres 16 and Mailpit on loopback high ports
- `bin/rails db:prepare db:seed`
- `bin/dev` — Puma on `PORT` from `.env` (62951 in the local `.env`) plus Tailwind watch
- `bin/rails test` — Minitest
- `bin/rubocop` / `bin/brakeman`

`.env` is gitignored. `.env.example` has placeholders, not this machine's ports.

## Rules

- Collector lives in `lib/collectors/omarchy.py` and is served at `GET /collect`.
- Ingest is `POST /reports`. Allowlist-only JSON. Reject serial/MAC/hostname fields in `ReportSanitizer`.
- Listing a machine requires a claimed report for that unit. Classifieds only: no payments.
- Donation destinations are admin-curated; seed includes Omacom Foundation.
- Do not vendor atmos `hw-inventory.py`.
- Zeitwerk ignores `lib/collectors`.
- Keep `json` on 2.x until Rails calls `JSON.parse` with keywords. json 3 breaks cookies, flash, jsonb, and signed tokens.
- Schema format is SQL (`db/structure.sql`) because of `pg_trgm` GIN indexes. Dump with a Postgres 16 client.
