# Market

A public database of hardware that runs [Omarchy](https://omarchy.org), destined for `https://market-app-blg2k.ondigitalocean.app/`.

People already running Omarchy send an anonymous hardware report with one command. Everyone else can look up whether a vendor and model has been seen running Omarchy. There are no accounts, listings, or email.

## Local setup

Join the `docker` group so Compose can start, then:

```sh
cp .env.example .env
docker compose -f compose.yaml up -d
bin/setup --skip-server
bin/rails db:seed
bin/dev
```

Development seed creates one admin login, `admin@example.com` with password `password`, and a few sample reports so lookup has something to find. Production and test seeds skip them.

Compose publishes Postgres on a high loopback port. The app listens on `PORT` from `.env`.

If Docker is unavailable, `mise.toml` pins Postgres 16. Point `DATABASE_HOST` / `DATABASE_PORT` at that server (or any Postgres 16+ with `pg_trgm`) and dump `db/structure.sql` with a matching `pg_dump`.

## Admins

Only admins have accounts, and there is no signup or reset mail. Create an admin, or reset an admin's password, from a console on the server:

```sh
bin/rails admin:create EMAIL=you@example.com
```

It prints a generated password unless you pass `PASSWORD=…`.

## Production

The image boots in `RAILS_ENV=production`. It decrypts `config/credentials.yml.enc` with `RAILS_MASTER_KEY`. That file is gitignored as `config/master.key`. Without the key, `db:prepare` aborts with `Missing secret_key_base`.

Do not commit `config/master.key`.

### DigitalOcean App Platform

In the app: **Settings → the web component → Environment Variables → Edit**. Add one **runtime** variable:

| Key | Value | Encrypt |
| --- | --- | --- |
| `RAILS_MASTER_KEY` | contents of local `config/master.key` | yes |

Save, then deploy. App Platform injects encrypted vars at runtime; the Dockerfile never contains the key. `CLOUDFLARE_EMAIL_API_TOKEN` from earlier versions is no longer read and can be removed.

If a managed Postgres is attached, App Platform also sets `DATABASE_URL`. Production primary, cache, queue, and cable connections all use that URL.

HTTP port for this image is **80** (Thruster).

## Collector

```sh
curl -fsSL https://market-app-blg2k.ondigitalocean.app/collect | bash
```

Against a local server:

```sh
curl -fsSL http://127.0.0.1:62951/collect | bash
```

The script has two modes:

- **On Omarchy** (`ID=omarchy` in `/etc/os-release`) it sends an anonymous hardware report, which becomes public.
- **Anywhere else** it checks whether the machine looks able to run Omarchy and prints a verdict: likely, unclear, or unlikely. It sends nothing unless you answer yes at the prompt, and then it files a private *candidate* report. Candidates never appear on public pages. With no terminal to ask on, the answer is no. Set `MARKET_SUBMIT=yes` to answer for a script.

Every rule behind the verdict cites the Omarchy manual or says "(to verify)". The manual has no hardware list, so a lot comes out as unclear. macOS and WSL are explained and not inspected; boot a Linux live USB to check real hardware.

Serials are hashed into `instance_digest` in memory and never sent. A short-lived challenge nonce stops replays. The server rejects identifier fields even if a client sends them.

Environment variables: `MARKET_URL`, `MARKET_DRY_RUN` (print the payload, send nothing), `MARKET_SUBMIT` (`yes` or `no`), `MARKET_SYS_ROOT`, `MARKET_ARCH`, `MARKET_KERNEL` and `MARKET_SKIP_CMDS` (for tests).

## Tests

```sh
bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

## Privacy

See `/privacy`. Serials, MACs, hostnames, and usernames are not stored. Submitter IPs are hashed.
