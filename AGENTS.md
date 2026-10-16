# Agent notes

Rails 8.1 app for Omarchy hardware compatibility and classifieds.

## Run

- `docker compose -f compose.yaml up -d` — Postgres 16 on a loopback high port
- `bin/rails db:prepare db:seed`
- `bin/dev` — Puma on `PORT` from `.env` (62951 in the local `.env`) plus Tailwind watch
- `bin/rails test` — Minitest
- `bin/rubocop` / `bin/brakeman`

`.env` is gitignored. `.env.example` has placeholders, not this machine's ports. Load it into the shell before Rails commands (`set -a; . ./.env; set +a`).

## Rules

- This is a public hardware compatibility database for Omarchy. There are no accounts, listings, claims, payments, or email. Do not add them back.
- Collector lives in `lib/collectors/omarchy.sh` and is served at `GET /collect` (`curl … | bash`). It fetches `GET /challenges` then `POST /reports`. Do not call Omarchy binaries. Release channel comes from the `[omarchy]` repo URL in `/etc/pacman.conf`.
- The collector has two modes. With `ID=omarchy` in `/etc/os-release` it posts an Omarchy report. Anywhere else it prints a local verdict (likely, unclear, unlikely) and posts a `candidate` report only after an explicit yes (a prompt on `/dev/tty`, or `MARKET_SUBMIT=yes`). Default is no, and no terminal means no.
- Every verdict rule must cite the Omarchy manual or say "(to verify)". Do not state an install requirement the manual does not give. Sourced so far: Secure Boot and/or TPM off to install, Intel Macs supported, M-series not, sound and Touch Bar broken on Macs.
- Candidate reports (`source = candidate`) are never counted or shown publicly, never overwrite an Omarchy report with the same digest, and are rate limited harder than Omarchy reports. Their `instance_digest` uses a different domain prefix than Omarchy reports.
- Set `PATH`-stubbed commands and `MARKET_SYS_ROOT` fixtures in `test/lib/collector_test.rb` for every collector branch. Collector errors must exit non-zero; remember `set -e` is off inside `||` and `if` contexts.
- Ingest is allowlist-only JSON with `nonce` and `instance_digest`. Reject serial/MAC/hostname fields in `ReportSanitizer`.
- Every accepted Omarchy report is public unless an admin hides it (`hidden_at`; a hidden machine stays hidden when it reports again). Public lookup counts distinct `instance_digest` values per model, so reposting one machine never raises a count. A model is "Verified" only with 3+ machines from 2+ distinct `submitted_ip_digest` values, because the client computes `instance_digest`.
- Users exist only for admins. Only admins can sign in. There is no signup and no password reset mail; create or reset an admin with `bin/rails admin:create EMAIL=… [PASSWORD=…]`.
- Do not vendor atmos `hw-inventory.py`.
- Zeitwerk ignores `lib/collectors`.
- `json` is 3.x and Rails is 8.1.4+, which passes keywords to `JSON.parse`. Do not downgrade either.
- Schema format is SQL (`db/structure.sql`) because of `pg_trgm` GIN indexes. Dump with a Postgres 16 client.
- Cache, queue, and cable share `DATABASE_URL`. Keep their tables in `db/cache_migrate`, `db/queue_migrate`, and `db/cable_migrate` so `db:prepare` creates them on an already-populated Postgres.
- Drop migrations are irreversible by design. Never edit an old migration; add a new one.
- Production site URLs use `https://market-app-blg2k.ondigitalocean.app/`.
- Develop the slice with tests, then commit, merge into `main`, and push `origin/main` so DigitalOcean App Platform deploys. Watch the deploy until it is ACTIVE.
