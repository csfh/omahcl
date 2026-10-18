# Agent notes

Rails 8.1 app for Omarchy HCL (omahcl.com), an unofficial public database of hardware that runs Omarchy.

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
- The collector posts only after an explicit yes (a prompt on `/dev/tty`, or `OMAHCL_SUBMIT=yes`), following a privacy notice that links to `/privacy`. Default is no, and no terminal means no. With `ID=omarchy` in `/etc/os-release` it posts an Omarchy report. Anywhere else it first prints a local verdict (likely, unclear, unlikely) and posts a `candidate` report. Keep the notice in step with the privacy page.
- Every verdict rule must cite the Omarchy manual or say "(to verify)". Do not state an install requirement the manual does not give. Sourced so far: Secure Boot and/or TPM off to install, Intel Macs supported, M-series not, sound and Touch Bar broken on Macs.
- Candidate reports (`source = candidate`) are never counted or shown publicly, never overwrite an Omarchy report with the same digest, and are rate limited harder than Omarchy reports. Their `instance_digest` uses a different domain prefix than Omarchy reports.
- Set `PATH`-stubbed commands and `OMAHCL_SYS_ROOT` fixtures in `test/lib/collector_test.rb` for every collector branch. Collector errors must exit non-zero; remember `set -e` is off inside `||` and `if` contexts.
- Ingest is allowlist-only JSON with `nonce` and `instance_digest`. Reject serial/MAC/hostname fields in `ReportSanitizer`.
- The server stores `instance_digest` as `Report.digest_instance` of the client's value, an HMAC keyed from `secret_key_base`. Look machines up through it. Changing `secret_key_base` gives every machine a new report on its next post.
- Every accepted Omarchy report is public unless an admin hides it (`hidden_at`; a hidden machine stays hidden when it reports again). Public lookup counts distinct `instance_digest` values per model, so reposting one machine never raises a count. A model is "Verified" only with 3+ machines from 2+ distinct `submitted_ip_digest` values, because the client computes `instance_digest`.
- Users exist only for admins. Only admins can sign in. There is no signup and no password reset mail; create or reset an admin with `bin/rails admin:create EMAIL=… [PASSWORD=…]`.
- Do not vendor atmos `hw-inventory.py`.
- Zeitwerk ignores `lib/collectors`.
- `json` is 3.x and Rails is 8.1.4+, which passes keywords to `JSON.parse`. Do not downgrade either.
- Schema format is SQL (`db/structure.sql`) because of `pg_trgm` GIN indexes. Dump with a Postgres 16 client.
- Cache, queue, and cable share `DATABASE_URL`. Keep their tables in `db/cache_migrate`, `db/queue_migrate`, and `db/cable_migrate` so `db:prepare` creates them on an already-populated Postgres.
- Drop migrations are irreversible by design. Never edit an old migration; add a new one.
- The display name is Omarchy HCL. Internal identifiers use `omahcl`, and the Rails module is `HCL`. The collector's `omarchy-market-instance-v1` and `omarchy-market-candidate-v1` digest domains keep their old names on purpose: renaming them re-keys every machine. A collector test pins the exact digests.
- Collector env vars are `OMAHCL_*` only. The URL placeholder is `__OMAHCL_URL__` and must change together with `CollectsController`.
- Production site URLs use `https://omahcl.com/`. Production runs on Laravel Cloud, which builds from the Gemfile and ignores the Dockerfile. Its deploy command must be `bin/rails db:prepare`; keep the `aarch64-linux` lockfile platforms.
- There are no GitHub Actions workflows and none should be added. Run `bin/rails test`, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, and `bin/importmap audit` locally before every push (or `bin/ci`).
- Develop the slice with tests, then commit, merge into `main`, and push `origin/main`. Pushing `main` deploys to production: Laravel Cloud has push-to-deploy on.
