# Market

Hardware compatibility and classifieds for [Omarchy](https://omarchy.org), destined for `market.omarchy.org`.

People already running Omarchy submit hardware reports. Everyone else can look up whether a vendor and model has claimed reports. After claiming a report, you can list from it for sale (new or used) or donation. Accounts claim reports, not machines.

Market is not a store. It does not take payment, escrow, or shipping.

## Local setup

Join the `docker` group so Compose can start, then:

```sh
cp .env.example .env
docker compose -f compose.yaml up -d
bin/setup --skip-server
bin/rails db:seed
bin/dev
```

Development seed creates these logins (password `password`):

| Email | Role |
| --- | --- |
| `one@example.com` | user |
| `two@example.com` | user |
| `admin@example.com` | admin |

It also claims a few hardware reports so lookup has something to find. Production and test seeds skip those accounts.

Compose publishes Postgres on a high loopback port and Mailpit SMTP/UI. The app listens on `PORT` from `.env`.

If Docker is unavailable, `mise.toml` pins Postgres 16. Point `DATABASE_HOST` / `DATABASE_PORT` at that server (or any Postgres 16+ with `pg_trgm`) and dump `db/structure.sql` with a matching `pg_dump`.

The Gemfile pins `json` to 2.x because Rails 8.1 still calls `JSON.parse(json, options)` and json 3 only accepts keywords.

## Production

The image boots in `RAILS_ENV=production`. It decrypts `config/credentials.yml.enc` with `RAILS_MASTER_KEY`. That file is gitignored as `config/master.key`. Without the key, `db:prepare` aborts with `Missing secret_key_base`.

Set one of these as a runtime secret (Kubernetes secret, Kamal `env.secret`, etc.):

- `RAILS_MASTER_KEY` — paste the contents of `config/master.key` from a machine that has it
- `SECRET_KEY_BASE` — a long random hex, if you prefer not to use credentials

Do not commit `config/master.key`.

## Collector

On an Omarchy machine:

```sh
curl -fsSL https://market.omarchy.org/collect | bash
```

Against a local server:

```sh
curl -fsSL http://127.0.0.1:62951/collect | bash
```

The script refuses to run unless `/etc/os-release` has `ID=omarchy`. Serials are hashed into `instance_digest` in memory and never sent. A short-lived challenge nonce stops replays. Public lookup counts people who claimed a snapshot, not anonymous posts. The server rejects identifier fields even if a client sends them.

## Tests

```sh
bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

## Privacy

See `/privacy`. Serials, MACs, hostnames, and usernames are not stored. Claim tokens and submitter IPs are hashed.
