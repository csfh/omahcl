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
- `GET /delete` serves the same script with `OMAHCL_ACTION=delete`, which rebuilds the machine's digest and, after a yes, posts it with a nonce to `POST /deletions`. `CollectsController` fills `__OMAHCL_ACTION__` from a fixed allowlist, never from params. `Report.erase` deletes by `digest_instance` of it, hidden rows included, because an erasure request wins over a hide. Keep the digest code shared with the collector so the two cannot drift; a test pins that they match.
- Collector lives in `lib/collectors/omarchy.sh` and is served at `GET /collect` (`curl … | bash`). It fetches `GET /challenges` then `POST /reports`. Do not call Omarchy binaries. Release channel comes from the `[omarchy]` repo URL in `/etc/pacman.conf`.
- The collector posts only after an explicit yes (a prompt on `/dev/tty`, or `OMAHCL_SUBMIT=yes`), following a privacy notice that links to `/privacy`. Default is no, and no terminal means no. With `ID=omarchy` in `/etc/os-release` it posts an Omarchy report. Anywhere else it says so, sends nothing and exits 2. There are no candidate reports and no local verdict; do not add them back. Only machines running Omarchy are reported. Keep the notice in step with the privacy page.
- Set `PATH`-stubbed commands and `OMAHCL_SYS_ROOT` fixtures in `test/lib/collector_test.rb` for every collector branch. Collector errors must exit non-zero; remember `set -e` is off inside `||` and `if` contexts.
- Ingest is allowlist-only JSON with `nonce` and `instance_digest`. Reject serial/MAC/hostname fields in `ReportSanitizer`. The collector never reads DMI serials (they are root-only); `instance_digest` hashes the machine-id, vendor, product and CPU model, and the pinned test digest must not change.
- The server stores `instance_digest` as `Report.digest_instance` of the client's value, an HMAC keyed from `secret_key_base`. Look machines up through it. Changing `secret_key_base` gives every machine a new report on its next post.
- Every accepted Omarchy report is public unless an admin hides it (`hidden_at`; a hidden machine stays hidden when it reports again, unless its owner deleted it with `/delete`). Public lookup counts distinct `instance_digest` values per model, so reposting one machine never raises a count. A model is "Verified" with 3+ distinct machines. The client computes `instance_digest`, so that is a sanity bar, not proof. Reports store nothing derived from the IP: IPs feed only the one-hour rate-limit counters. Do not add an IP column or digest back.
- Cards live at `/cards/:key` (HTML and `.png`). `Report.card_key_for` hashes the model and CPU into a 16-hex key, so each configuration has one stable link, and `db/migrate/20261019120000_add_card_key_to_reports.rb` spells out the same formula (a test pins them together). It is plain SHA-256, not keyed with `secret_key_base`, so rotating the secret never breaks a shared link. A card says "Omarchy Verified" for any visible Omarchy report by the owner's choice, separate from the 3+ machines "Verified" badge. A card shows no machine count and none of `public_id` or the digests. `CardImage` draws the PNG in pure Ruby so Laravel Cloud needs no image library.
- Charts come from `Report::Stats`: start from `Report.visible`, count distinct machines. Charts are server-rendered SVG with the numbers beside them as text. Draw with geometry and Tailwind classes, because the CSP blocks inline `style` attributes.
- Users exist only for admins. Only admins can sign in. There is no signup and no password reset mail; create or reset an admin with `bin/rails admin:create EMAIL=… [PASSWORD=…]`.
- Do not vendor atmos `hw-inventory.py`.
- Zeitwerk ignores `lib/collectors`.
- `json` is 3.x and Rails is 8.1.4+, which passes keywords to `JSON.parse`. Do not downgrade either.
- Schema format is SQL (`db/structure.sql`) because of `pg_trgm` GIN indexes. Dump with a Postgres 16 client.
- Cache, queue, and cable share `DATABASE_URL`. Keep their tables in `db/cache_migrate`, `db/queue_migrate`, and `db/cable_migrate` so `db:prepare` creates them on an already-populated Postgres.
- Drop migrations are irreversible by design. Never edit an old migration; add a new one.
- The display name is Omarchy HCL. Internal identifiers use `omahcl`, and the Rails module is `HCL`. The collector's `omarchy-market-instance-v1` digest domain keeps its old name on purpose: renaming it re-keys every machine. A collector test pins the exact digest.
- Collector env vars are `OMAHCL_*` only. The URL and action placeholders are `__OMAHCL_URL__` and `__OMAHCL_ACTION__` and must change together with `CollectsController`.
- Production site URLs use `https://omahcl.com/`. Production runs on Laravel Cloud, which builds from the Gemfile and ignores the Dockerfile. Its deploy command must be `bin/rails db:prepare`; keep the `aarch64-linux` lockfile platforms.
- The CSP's `script-src` is `'self' 'unsafe-inline'` plus Cloudflare's hosts, with no nonce, by the owner's choice. Cloudflare injects an inline script that changes on every response and Turbo re-runs it, and browsers ignore `'unsafe-inline'` next to a nonce. Keep the nonce on `style-src` only.
- There are no GitHub Actions workflows and none should be added. Run `bin/rails test`, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, and `bin/importmap audit` locally before every push (or `bin/ci`).
- Develop the slice with tests, then commit, merge into `main`, and push `origin/main`. Pushing `main` deploys to production: Laravel Cloud has push-to-deploy on.
