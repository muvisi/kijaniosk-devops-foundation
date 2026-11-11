#!/usr/bin/env bash
set -Eeuo pipefail
BASE=/opt/kijanikiosk
CURRENT=$(cat "$BASE/.active-env")
PREVIOUS=$(cat "$BASE/.previous-env")
[[ "$CURRENT" != "$PREVIOUS" ]] || { echo 'No different previous environment to restore' >&2; exit 1; }
echo "[$(date -Is)] Rollback from $CURRENT to $PREVIOUS"
/opt/kijanikiosk/scripts/switch-env.sh "$PREVIOUS"
