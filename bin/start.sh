#!/bin/sh
# Start the selfish stack (all services + one-shot migration).
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/common.sh"
# shellcheck disable=SC2086
$COMPOSE pull
# shellcheck disable=SC2086
$COMPOSE up -d
# Retry one-shot migration in case it raced postgres on first boot.
# shellcheck disable=SC2086
$COMPOSE up selfish-migrate
