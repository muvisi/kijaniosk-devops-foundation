#!/usr/bin/env bash
set -Eeuo pipefail
WINDOW="${1:-60}"
[[ "$WINDOW" =~ ^[0-9]+$ ]] && (( WINDOW >= 10 && WINDOW <= 300 )) || { echo 'Window must be 10..300 seconds' >&2; exit 2; }
BASE=/opt/kijanikiosk
INTERVAL=5
FAILURES=0
START=$(date +%s)
BASELINE=$(cat "$BASE/.active-env")
# Monitor begins BEFORE switch; observe the first switch, then watch target.
echo "[$(date -Is)] [MONITOR START] baseline=$BASELINE confidence_window=${WINDOW}s"
while (( $(date +%s) - START < WINDOW + 60 )); do
 ACTIVE=$(cat "$BASE/.active-env")
 if [[ "$ACTIVE" != "$BASELINE" ]]; then break; fi
 sleep 1
done
if [[ "$ACTIVE" == "$BASELINE" ]]; then echo '[MONITOR] No switch detected'; exit 1; fi
TARGET="$ACTIVE"
END=$(( $(date +%s) + WINDOW ))
echo "[$(date -Is)] [MONITOR] Switch detected: $BASELINE -> $TARGET"
while (( $(date +%s) < END )); do
 ACTIVE=$(cat "$BASE/.active-env")
 [[ "$ACTIVE" == "$TARGET" ]] || { echo "[$(date -Is)] [MONITOR] Active environment changed; exiting"; exit 0; }
 if [[ "$TARGET" == blue ]]; then VERSION=v1.3.0; else VERSION=v1.4.0; fi
 BODY=$(curl -fsS --max-time 2 http://127.0.0.1:8088/health 2>/dev/null || true)
 if [[ "$BODY" == *'"version":"'"$VERSION"'"'* ]]; then
   FAILURES=0
   echo "[$(date -Is)] [MONITOR OK] $BODY"
 else
   FAILURES=$((FAILURES+1))
   echo "[$(date -Is)] [MONITOR WARN] failure=$FAILURES proxy=$BODY"
 fi
 if (( FAILURES >= 2 )); then
   echo "[$(date -Is)] [MONITOR FAIL] ROLLBACK TRIGGERED"
   /opt/kijanikiosk/scripts/rollback.sh
   echo "[$(date -Is)] [MONITOR] Rollback complete: $(curl -fsS --max-time 3 http://127.0.0.1:8088/health)"
   exit 0
 fi
 sleep "$INTERVAL"
done
echo "[$(date -Is)] [MONITOR PASS] Confidence window completed"
