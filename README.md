# Omarchy HCL

A public hardware compatibility list for [Omarchy](https://omarchy.org), at `https://omahcl.csfh.dev/`. It is unofficial.

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

### Laravel Cloud

Production runs on [Laravel Cloud](https://laravel.com/cloud/docs/deploy-guides/ruby) at `https://omahcl.csfh.dev/`. Cloud builds a Ruby app from the Gemfile; it does not use the Dockerfile (that is for Kamal or `docker run`).

Attach and set:

| What | Value |
| --- | --- |
| Postgres database | Attach one. Cloud then sets `DATABASE_URL`, and every connection here (primary, cache, queue, cable) uses it. |
| `RAILS_MASTER_KEY` | Contents of local `config/master.key`, as a secret. Or set `SECRET_KEY_BASE` instead. |
| Deploy command | `bin/rails db:prepare`. Cloud runs it before a new deployment takes traffic. The Docker entrypoint does this elsewhere, but Cloud's start command skips the entrypoint. |
| Build command | The default, `SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile`. |

Nothing else is needed: no Redis, object storage, mail, or persistent disk. Solid Queue must run for the recurring jobs in `config/recurring.yml`, which delete expired challenges and rate-limit keys older than an hour. Either set `SOLID_QUEUE_IN_PUMA=true`, which runs it inside Puma, or run `bin/jobs` as a separate process.

Things to know:

- The first migration runs `CREATE EXTENSION pg_trgm`. Cloud's docs do not say whether its Postgres allows it. If a deploy fails there, the error names the extension.
- If the database URL uses the pooled `-pooler` host, run migrations over the direct host. Migrations take an advisory lock that a transaction pooler breaks.
- The app runs on ARM64 and the lockfile carries the `aarch64-linux` platforms. Keep them when updating gems.
- TLS ends at Cloud's proxy, so `assume_ssl` and `force_ssl` are on. `/up` is exempt from the redirect for health checks.
- For the custom domain, add a CNAME in Cloudflare to the origin Cloud shows. Keep the `_acme-challenge` records DNS only (not proxied) or certificate issuance fails.
- Filesystem is reset on every deploy. Nothing here writes to it.
- Logs are under Monitoring, then Logs. One-off commands go in the Commands tab, and they must be non-interactive, so use `bin/rails runner`. `bin/rails admin:create EMAIL=…` works there.

## Collector

```sh
curl -fsSL https://omahcl.csfh.dev/collect | bash
```

Against a local server:

```sh
curl -fsSL http://127.0.0.1:62951/collect | bash
```

The script has two modes:

- **On Omarchy** (`ID=omarchy` in `/etc/os-release`) it sends an anonymous hardware report, which becomes public.
- **Anywhere else** it checks whether the machine looks able to run Omarchy and prints a verdict: likely, unclear, or unlikely. It sends nothing unless you answer yes at the prompt, and then it files a private *candidate* report. Candidates never appear on public pages. With no terminal to ask on, the answer is no. Set `OMAHCL_SUBMIT=yes` to answer for a script.

Every rule behind the verdict cites the Omarchy manual or says "(to verify)". The manual has no hardware list, so a lot comes out as unclear. macOS and WSL are explained and not inspected; boot a Linux live USB to check real hardware.

Serials are hashed into `instance_digest` in memory and never sent. A short-lived challenge nonce stops replays. The server rejects identifier fields even if a client sends them.

Environment variables: `OMAHCL_URL`, `OMAHCL_DRY_RUN` (print the payload, send nothing), `OMAHCL_SUBMIT` (`yes` or `no`), and `OMAHCL_SYS_ROOT`, `OMAHCL_ARCH`, `OMAHCL_KERNEL` and `OMAHCL_SKIP_CMDS` (for tests).

## Tests

```sh
bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

## Privacy

See `/privacy`. Serials, MACs, hostnames, and usernames are not stored. Submitter IPs are hashed.
