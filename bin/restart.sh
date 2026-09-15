#!/bin/sh
# Restart the selfish stack. Keeps data volumes.
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/common.sh"
# shellcheck disable=SC2086
$COMPOSE down
# shellcheck disable=SC2086
$COMPOSE up -d
# shellcheck disable=SC2086
$COMPOSE up selfish-migrate
