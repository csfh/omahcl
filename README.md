# Market

Hardware compatibility and classifieds for [Omarchy](https://omarchy.org), destined for `https://market-app-blg2k.ondigitalocean.app/`.

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

The Gemfile requires Rails 8.1.4+ so `ActiveSupport::JSON.decode` works with json 3, which only accepts keyword options for `JSON.parse`.

## Production

The image boots in `RAILS_ENV=production`. It decrypts `config/credentials.yml.enc` with `RAILS_MASTER_KEY`. That file is gitignored as `config/master.key`. Without the key, `db:prepare` aborts with `Missing secret_key_base`. Puma runs Solid Queue so verification and password-reset mail leave the queue.

Do not commit `config/master.key`.

### DigitalOcean App Platform

In the app: **Settings → the web component → Environment Variables → Edit**.

Add **runtime** variables (scope Run Time is enough):

| Key | Value | Encrypt |
| --- | --- | --- |
| `RAILS_MASTER_KEY` | contents of local `config/master.key` | yes |
| `CLOUDFLARE_EMAIL_API_TOKEN` | Cloudflare API token with **Email Sending: Edit** | yes |

```sh
cat config/master.key
```

Save, then deploy. App Platform injects encrypted vars at runtime; the Dockerfile never contains the key.

If a managed Postgres is attached, App Platform also sets `DATABASE_URL`. Production primary, cache, queue, and cable connections all use that URL.

HTTP port for this image is **80** (Thruster).

### Cloudflare Email Sending

Password resets leave through Cloudflare SMTP. The From address is `Market <noreply@omarchy.csfh.dev>`, so `omarchy.csfh.dev` must be onboarded for Email Sending. Local development still uses Mailpit.

Email Sending needs a Workers Paid plan. Leave Email Routing off; that product takes inbound MX for the domain.

1. In the [Cloudflare dashboard](https://dash.cloudflare.com/), go to **Compute** → **Email Service** → **Email Sending** ([deep link](https://dash.cloudflare.com/?to=/:account/email-service/sending)).
2. **Onboard Domain** and pick `omarchy.csfh.dev`. Cloudflare writes bounce MX, SPF, and DKIM on `cf-bounce.omarchy.csfh.dev`, plus a DMARC record on `_dmarc.omarchy.csfh.dev`. If that DMARC record already exists, review the change before confirming.
3. Wait until **Email Sending** → **Settings** shows those records present (often 5–15 minutes).
4. Create an **account-owned** API token: **Manage Account** → **Account API Tokens** → **Create Token** → **Create Custom Token**. Name it `market-smtp`. Permission: **Account** → **Email Sending** → **Edit**. Limit it to the account that owns `omarchy.csfh.dev`. Copy the secret once.
5. Prove SMTP before putting the token on App Platform. Use an inbox you can open:

```sh
cat > /tmp/market-smtp.txt <<EOF
From: Market <noreply@omarchy.csfh.dev>
To: you@example.com
Subject: Market SMTP check

Cloudflare Email Sending accepted this message.
EOF

curl --ssl-reqd \
  --url "smtps://smtp.mx.cloudflare.net:465" \
  --user "api_token:PASTE_TOKEN_HERE" \
  --mail-from "noreply@omarchy.csfh.dev" \
  --mail-rcpt "you@example.com" \
  --upload-file /tmp/market-smtp.txt
```

A `250` after the body means the token and domain are good. `535` is a bad token or the wrong permission. `550 5.7.1` means `omarchy.csfh.dev` is not onboarded on that account.

6. Add `CLOUDFLARE_EMAIL_API_TOKEN` on App Platform as in the table above, then deploy. The container exits on boot if the variable is missing.

## Collector

On an Omarchy machine:

```sh
curl -fsSL https://market-app-blg2k.ondigitalocean.app/collect | bash
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
