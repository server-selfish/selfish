#!/bin/sh
# Start the selfish stack without running migrations.
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/common.sh"
# shellcheck disable=SC2086
$COMPOSE pull
# shellcheck disable=SC2086
$COMPOSE up -d --scale selfish-migrate=0
