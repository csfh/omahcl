# Market

Hardware compatibility and classifieds for [Omarchy](https://omarchy.org), destined for `market.omarchy.org`.

People already running Omarchy submit machine facts. Everyone else can look up whether a vendor and model has verified installs. After claiming a report, the owner can list that unit for sale (new or used) or donation.

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

Compose publishes Postgres on a high loopback port and Mailpit SMTP/UI. The app listens on `PORT` from `.env`.

If Docker is unavailable, `mise.toml` pins Postgres 16. Point `DATABASE_HOST` / `DATABASE_PORT` at that server (or any Postgres 16+ with `pg_trgm`) and dump `db/structure.sql` with a matching `pg_dump`.

The Gemfile pins `json` to 2.x because Rails 8.1 still calls `JSON.parse(json, options)` and json 3 only accepts keywords.

## Collector

On an Omarchy machine:

```sh
curl -fsSL https://market.omarchy.org/collect | python3
```

Against a local server:

```sh
curl -fsSL http://127.0.0.1:62951/collect | python3
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
