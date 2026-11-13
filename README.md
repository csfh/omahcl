# Omarchy HCL

A public hardware compatibility list for [Omarchy](https://omarchy.org), at `https://omahcl.com/`. It is unofficial.

People already running Omarchy can send an anonymous hardware report with one command. Everyone else can look up whether a vendor and model has been seen running Omarchy. There are no accounts, listings, or email.

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

Production runs on [Laravel Cloud](https://laravel.com/cloud/docs/deploy-guides/ruby) at `https://omahcl.com/`. Cloud builds a Ruby app from the Gemfile; it does not use the Dockerfile (that is for Kamal or `docker run`).

Attach and set:

| What | Value |
| --- | --- |
| Postgres database | Attach one. Cloud then sets `DATABASE_URL`, and every connection here (primary, cache, queue, cable) uses it. |
| `RAILS_MASTER_KEY` | Contents of local `config/master.key`, as a secret. Or set `SECRET_KEY_BASE` instead. |
| Deploy command | `bin/rails db:prepare`. Cloud runs it before a new deployment takes traffic. The Docker entrypoint does this elsewhere, but Cloud's start command skips the entrypoint. |
| Build command | The default, `SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile`. |
| Start command | The default, `bundle exec bin/rails server -b '::' -p $PORT`. Thruster is not used. |
| Background process | A custom worker on the App instance running `bundle exec bin/jobs --mode async`. It runs the recurring jobs in `config/recurring.yml`, which delete expired challenges and rate-limit keys older than an hour. Async mode keeps Solid Queue to one process on the 512MB instance. Do not also set `SOLID_QUEUE_IN_PUMA`. |

Nothing else is needed: no Redis, object storage, mail, or persistent disk.

Things to know:

- The first migration runs `CREATE EXTENSION pg_trgm`. Cloud's docs do not say whether its Postgres allows it. If a deploy fails there, the error names the extension.
- If the database URL uses the pooled `-pooler` host, run migrations over the direct host. Migrations take an advisory lock that a transaction pooler breaks.
- The app runs on ARM64 and the lockfile carries the `aarch64-linux` platforms. Keep them when updating gems.
- TLS ends at Cloud's proxy, so `assume_ssl` and `force_ssl` are on. `/up` is exempt from the redirect for health checks.
- For the custom domain, add a CNAME in Cloudflare to the origin Cloud shows. Keep the `_acme-challenge` records DNS only (not proxied) or certificate issuance fails.
- Pushing `main` deploys: push-to-deploy is on.
- Hibernation is on. While the app sleeps, so do the recurring jobs, and they catch up within 5 minutes of it waking.
- `config.hosts` allows `omahcl.com` and the environment's Cloud domain, `omarchy-hcl-production-2mzewm.laravel.cloud`. A recreated environment gets a new Cloud domain. Add it there, or that domain answers 403; the `Blocked hosts` log line names it.
- The `cloud` CLI reads its organization and app from `.cloud/config.json`.
- Filesystem is reset on every deploy. Nothing here writes to it.
- Logs are under Monitoring, then Logs. One-off commands go in the Commands tab, and they must be non-interactive, so use `bin/rails runner`. `bin/rails admin:create EMAIL=…` works there.

## Collector

```sh
curl -fsSL https://omahcl.com/collect | bash
```

Against a local server:

```sh
curl -fsSL http://127.0.0.1:62951/collect | bash
```

The script never sends anything without a yes. Before asking, it lists what it would send, says what it never sends and how IP addresses are handled, and links to `/privacy`. The answer defaults to no, and with no terminal to ask on the answer is no. Set `OMAHCL_SUBMIT=yes` or `no` to answer for a script.

On a machine running Omarchy (`ID=omarchy` in `/etc/os-release`), a yes sends an anonymous hardware report, which becomes public. On any other system it says so, sends nothing and exits with status 2. macOS and WSL are not inspected; the script only reports real Omarchy machines.

`instance_digest` is a hash of the machine-id, vendor, product and CPU model, built in memory. The machine-id is never sent. The script reads no serial numbers. The server stores that digest keyed again (`Report.digest_instance`), so a copy of the database can't be matched to a machine through its `/etc/machine-id`. A short-lived challenge nonce stops replays. The server rejects identifier fields even if a client sends them.

### Deleting a report

```sh
curl -fsSL https://omahcl.com/delete | bash
```

`/delete` serves the same script with its action set to `delete` (`OMAHCL_ACTION`). It rebuilds this machine's digest with the same `instance_digest` code as the collector and, after a yes, `POST`s it with a challenge nonce to `/deletions`. The server HMACs it and deletes the matching report, hidden or not. It cannot reach reports whose digest has since changed: a reinstall, a different model or CPU string, or a report from before DMI serials left the formula.

Environment variables: `OMAHCL_URL`, `OMAHCL_ACTION`, `OMAHCL_DRY_RUN` (on Omarchy, print the payload and send nothing), `OMAHCL_SUBMIT` (`yes` or `no`, which also answers the delete prompt), and `OMAHCL_SYS_ROOT`, `OMAHCL_ARCH`, `OMAHCL_KERNEL` and `OMAHCL_SKIP_CMDS` (for tests).

## Tests

```sh
bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

## Privacy

See `/privacy`. Serials, MACs, hostnames, and usernames are not stored. No IP address is stored with a report.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md); [AGENTS.md](AGENTS.md) has the project's rules.

## License

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Christoffer Hallas.

If you send a pull request or other contribution, you agree to the [CLA](CLA.md).
