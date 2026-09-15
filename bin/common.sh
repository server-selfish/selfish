# Shared setup for selfish bin scripts. Source from start.sh, stop.sh, restart.sh.
# Not meant to run directly.
set -eu

# Resolve deployment root (parent of bin/) so scripts run from anywhere.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker not found in PATH" >&2
  exit 1
fi

if [ ! -f .env ]; then
  echo "error: .env not found, copy .env.example to .env first" >&2
  exit 1
fi

# shellcheck disable=SC2139
COMPOSE="docker compose --env-file .env \
  -f docker-compose.yml \
  -f database/docker-compose.postgresql.yml \
  -f valkey/docker-compose.valkey.yml \
  -f backend/docker-compose.backend.yml \
  -f frontend/docker-compose.frontend.yml \
  -f gateway/docker-compose.nginx.yml \
  -f prometheus/docker-compose.prometheus.yml \
  -f migration/docker-compose.migration.yml"
