<div align="center">

# Selfish — Self-Hosted Deployment

*Run the full Selfish stack on your own server in a few steps.*

[Quickstart](#quickstart) • [GitHub auth](#github-auth-setup) • [Configuration](#configuration) • [Scripts](#scripts) • [Services](#services) • [Troubleshooting](#troubleshooting)

</div>

> [!Note]
> Current HEAD references only support for go tech stack. later will add more diverse other techs

Selfish ships as three apps plus managed infrastructure, all wired together with Docker Compose:

| Component | Tech | Source |
|---|---|---|
| Backend API | Go, clean architecture, GitHub App auth + JWT | `../backend` (`github.com/server-selfish/backend`) |
| Frontend | TanStack Start, React 19, Tailwind CSS 4 | `../frontend` |
| Gateway | Nginx with TLS termination | `gateway/nginx.conf` |
| Database | PostgreSQL 18 | `database/` |
| Cache | Valkey | `valkey/` |
| Migrations | `migrate/migrate`, fetched from the backend repo at deploy time | `migration/` |
| Observability | Prometheus + cAdvisor, VictoriaLogs | `prometheus/`, `vlogs/` |

The gateway proxies `/api/*` to the backend and everything else to the frontend, so the whole platform is served from a single entrypoint.

## Prerequisites

- Docker Engine with the Compose plugin, on the target server (or your machine for a local run).
- A POSIX shell to run the helper scripts: Linux, macOS, WSL, or Git Bash on Windows.
- TLS certificate + key for the gateway (`gateway/cert/server.crt`, `gateway/cert/server.key`).
- GitHub OAuth App credentials (or GitHub App credentials) and a JWT secret for the backend.

> [!NOTE]
> The backend image also mounts the Docker socket (`/var/run/docker.sock`), so the deployment target must be a Docker host, not just a client machine.

## Quickstart

**1. Configure environment variables.**

```bash
cp .env.example .env
```

Fill in every value in `.env` (see [Configuration](#configuration)).

**2. Configure the backend.**

```bash
cp backend/config.example.yaml backend/config.yaml
```

Edit `backend/config.yaml` (ports, database, Valkey, CORS, JWT issuer/TTLs), and place the GitHub App private key and any other secrets under `backend/.secret/`.

**3. Install the TLS certificate.**

Place your certificate and key at:

- `gateway/cert/server.crt`
- `gateway/cert/server.key`

> [!WARNING]
> `backend/config.yaml`, `backend/.secret/`, `gateway/cert/`, `valkey/valkey.acl`, and `.env` are gitignored for a reason. Never commit them.

**4. Start everything (builds nothing, pulls images, runs migrations).**

```bash
./bin/start.sh
```

Open `https://<your-server>:8080` (host port `8080` maps to the gateway's `443`).

**5. Stop or restart.**

```bash
./bin/stop.sh      # stops containers, keeps data volumes
./bin/restart.sh   # stop + start, keeps data volumes
```

To start without running database migrations:

```bash
./bin/start-no-migrate.sh
```

## GitHub auth setup

Selfish login needs **two** GitHub registrations: an **OAuth App** (user sign-in) and a **GitHub App** (repository installation). Both live under your GitHub account or organization: `Settings` → `Developer settings`.

The backend builds its callback URLs from `app.base.url` in `backend/config.yaml` (use your public address, e.g. `https://<your-server>:8080/api`):

- OAuth callback: `<app.base.url>/auth/github/callback`
- GitHub App callback: `<app.base.url>/api/github-app/callback`

### 1. OAuth App → client ID and client secret

1. Go to `Developer settings` → `OAuth Apps` → `New OAuth App`.
2. Fill in:
   - `Application name`: e.g. `Selfish`
   - `Homepage URL`: e.g. `https://<your-server>:8080`
   - `Authorization callback URL`: the OAuth callback URL above.
3. `Register application`. The **Client ID** is shown on the app page.
4. Click `Generate a new client secret` and copy the **Client secret** immediately.
5. Put them in `.env`:

```bash
AUTH_GITHUB_CLIENT_ID=<client-id>
AUTH_GITHUB_CLIENT_SECRET=<client-secret>
```

> [!WARNING]
> GitHub shows the client secret only once. If you lose it, generate a new one and update `.env`.

### 2. GitHub App → App ID, App slug, private key

1. Go to `Developer settings` → `GitHub Apps` → `New GitHub App`.
2. Fill in:
   - `GitHub App name`: e.g. `selfish-deploy`. The **App slug** is this name lowercased (visible in the App's URL: `github.com/apps/<slug>`).
   - `Homepage URL`: e.g. `https://<your-server>:8080`
   - `Callback URL`: the GitHub App callback URL above.
   - Deactivate the webhook if the backend does not consume it.
   - Under `Permissions`, grant what the backend needs (at minimum repository `Contents: Read` and `Metadata: Read`; extend if installs fail with permission errors).
   - Choose where the App can be installed (your account or any account).
3. `Create GitHub App`. The **App ID** is shown near the top of the App settings page.
4. Scroll to `Private keys` → `Generate a private key`. GitHub downloads a `.pem` file **once**.
5. Save the key into `backend/.secret/`, e.g. `backend/.secret/github-app.pem`, and point the env var at the **container** path (`backend/.secret` is mounted at `/.secret`):

```bash
AUTH_GITHUB_APP_ID=<app-id>
AUTH_GITHUB_APP_SLUG=<app-slug>
AUTH_GITHUB_PRIVATE_KEY_PATH=/.secret/github-app.pem
```

> [!WARNING]
> The `.pem` downloads only once and `backend/.secret/` is gitignored. Back it up safely; if lost, delete the key in the App settings and generate a new one.

### 3. Install the App

After `./bin/start.sh` is up, install the GitHub App on your account or organization: open the App page → `Install App`, or hit the backend install endpoint at `<app.base.url>/github-app/install`. Repository access is recorded via the callback above.

## Configuration

All values come from `.env` in this directory (loaded via `--env-file` by the helper scripts).

| Variable | Used by | Description |
|---|---|---|
| `BASE_URL_BACKEND_ENDPOINT` | Frontend | Public backend URL the frontend calls |
| `NODE_TLS_REJECT_UNAUTHORIZED` | Frontend | Set `0` only with a self-signed gateway cert |
| `FRONTEND_PORT` | Frontend | Port the frontend listens on inside its container |
| `BACKEND_ENV` | Backend | Set `production` for deployments |
| `DB_USER`, `DB_PASSWORD`, `DB_NAME` | Database, migration | Postgres credentials and database name |
| `DATABASE_URL` | Migration | Full `migrate -database` URL; defaults to one composed from `DB_*` |
| `MIGRATIONS_GIT_REF` | Migration | Backend repo ref to fetch `migrations/` from (default `main`) |
| `AUTH_GITHUB_CLIENT_ID`, `AUTH_GITHUB_CLIENT_SECRET` | Backend | GitHub OAuth credentials |
| `AUTH_GITHUB_APP_ID`, `AUTH_GITHUB_APP_SLUG`, `AUTH_GITHUB_PRIVATE_KEY_PATH` | Backend | GitHub App credentials |
| `AUTH_JWT_SECRET` | Backend | Secret for signing JWTs |

## Scripts

All scripts live in `bin/` and share setup (project root resolution, Docker and `.env` checks, the full `-f` file list) via `bin/common.sh`. Run them from anywhere; they `cd` to the deployment root themselves.

| Script | What it does |
|---|---|
| `bin/start.sh` | `pull`, `up -d` for all stacks, then runs the one-shot `selfish-migrate` (with a retry in case it raced Postgres on first boot) |
| `bin/start-no-migrate.sh` | `pull`, `up -d` with `--scale selfish-migrate=0`; schema untouched |
| `bin/stop.sh` | `down`; containers removed, named volumes kept |
| `bin/restart.sh` | `down`, `up -d`, then `selfish-migrate` |

> [!TIP]
> `stop`/`restart` never pass `-v`, so `selfish_db_data`, `selfish_valkey_data`, and `selfish_prometheus_data` survive restarts. Deleting volumes is a deliberate manual step: `docker volume rm ...`.

## Services

Every stack shares the `selfish-network` bridge network and is pinned to an explicit image tag.

| Service | Image | Notes |
|---|---|---|
| `selfish_db` | `postgres:18.3-alpine3.23` | Healthchecked with `pg_isready`; migration waits on `service_healthy` |
| `selfish_cache` | `valkey/valkey-bundle:9-alpine` | ACL file at `valkey/valkey.acl` |
| `selfish-backend` | `ghcr.io/server-selfish/backend:latest` | Reads `/config.yaml` + `/.secret`, port `8081` |
| `selfish-frontend` | `ghcr.io/server-selfish/frontend:latest` | Reached through the gateway, no published ports |
| `selfish-gateway` | `nginx:1.28.0-alpine-slim` | Host `8080` → container `443` |
| `selfish-migrate` | `migrate/migrate:v4.18.2` | One-shot (`restart: "no"`); downloads `migrations/` from `server-selfish/backend@<ref>` and runs `up`, then prints the current version |
| `selfish_prometheus`, `selfish_cadvisor` | `prom/prometheus:v3.12.0-distroless`, `gcr.io/cadvisor/cadvisor:v0.54.1` | Scrape config in `prometheus/prometheus.yml` |
| `selfish_logs` | `victoriametrics/victoria-logs:v1.50.0` | Included in default `bin/` runs via `vlogs/`, port `9428` |

### Logs stack

`vlogs/docker-compose.vlogs.yml` is part of default `bin/` runs through `bin/common.sh`. `selfish-backend` exports OTLP/HTTP logs to `http://selfish_logs:9428/insert/opentelemetry/v1/logs`. `start.sh` runs migrate after boot. `start-no-migrate.sh` skips migrate with `--scale selfish-migrate=0` but still starts logs store.

## Project structure

```text
.
├── bin/                    # start/stop/restart helpers + shared common.sh
├── backend/                # backend compose fragment, config.yaml, .secret/
├── frontend/               # frontend compose fragment
├── gateway/                # nginx compose fragment, nginx.conf, cert/
├── database/               # postgres compose fragment (+ healthcheck)
├── valkey/                 # valkey compose fragment + ACL
├── migration/              # one-shot migrate compose fragment
├── prometheus/             # prometheus + cadvisor fragments and config
├── vlogs/                  # victoria-logs fragment (included by default)
├── docker-compose.yml      # project name + shared network
└── .env                    # your secrets (gitignored, copy from .env.example)
```

## Troubleshooting

- **Migration fails on first boot:** Postgres was still initializing. Just run `./bin/start.sh` again; it retries `selfish-migrate` after the full stack is up.
- **`selfish-migrate` can't reach the DB:** check `DB_USER`/`DB_PASSWORD`/`DB_NAME` in `.env` match `backend/config.yaml`, and inspect the failing SQL with `docker logs selfish-migrate`.
- **Frontend shows API errors:** verify `BASE_URL_BACKEND_ENDPOINT` points at the gateway's `/api/` route and the gateway cert is trusted (or `NODE_TLS_REJECT_UNAUTHORIZED=0` for self-signed).
- **Gateway serves nothing on `:8080`:** confirm `gateway/cert/server.crt` and `server.key` exist and match; check `docker logs selfish-gateway`.
- **Scripts say `docker not found`:** run them where the Docker Engine (not just the CLI) is installed, or point `DOCKER_HOST` at your server.
