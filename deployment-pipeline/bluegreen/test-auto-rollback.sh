#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/opt/kijanikiosk"
OUT="deployment-pipeline/bluegreen"
MONITOR_LOG="$OUT/monitor.log"
EVIDENCE="$OUT/rollback-evidence.txt"

mkdir -p "$OUT"

echo "===== PRE-FLIGHT CHECKS ====="

if [[ "$(cat "$BASE/.active-env")" != "blue" ]]; then
    echo "ERROR: Blue must be active before testing"
    exit 1
fi

check_health() {
    local port="$1"
    local version="$2"
    local response

    for attempt in $(seq 1 15); do
        response=$(curl -fsS --max-time 2 \
            "http://127.0.0.1:$port/health" 2>/dev/null || true)

        if [[ "$response" == *"\"version\":\"$version\""* ]]; then
            echo "READY: port=$port version=$version"
            return 0
        fi

        sleep 1
    done

    echo "ERROR: port $port did not become healthy"
    return 1
}

check_health 3100 v1.3.0
check_health 3101 v1.4.0
check_health 8088 v1.3.0

: > "$MONITOR_LOG"

MONITOR_PID=""

cleanup() {
    if [[ -n "$MONITOR_PID" ]]; then
        if kill -0 "$MONITOR_PID" 2>/dev/null; then
            kill "$MONITOR_PID" 2>/dev/null || true
        fi
        wait "$MONITOR_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo
echo "===== STARTING MONITOR ====="

sudo -n bash "$BASE/scripts/post-deploy-monitor.sh" 60 \
    > "$MONITOR_LOG" 2>&1 &

MONITOR_PID=$!

for attempt in $(seq 1 10); do
    if grep -q '\[MONITOR START\]' "$MONITOR_LOG"; then
        break
    fi

    if ! kill -0 "$MONITOR_PID" 2>/dev/null; then
        echo "ERROR: Monitor exited unexpectedly"
        cat "$MONITOR_LOG"
        exit 1
    fi

    sleep 1
done

if ! grep -q '\[MONITOR START\]' "$MONITOR_LOG"; then
    echo "ERROR: Monitor did not start"
    cat "$MONITOR_LOG"
    exit 1
fi

cat "$MONITOR_LOG"

echo
echo "===== SWITCHING BLUE TO GREEN ====="

sudo -n bash "$BASE/scripts/switch-env.sh" green

check_health 8088 v1.4.0

echo
echo "===== WAITING FOR MONITOR DETECTION ====="

DETECTED=false

for attempt in $(seq 1 10); do
    if grep -q 'Switch detected: blue -> green' "$MONITOR_LOG"; then
        DETECTED=true
        break
    fi

    if ! kill -0 "$MONITOR_PID" 2>/dev/null; then
        break
    fi

    sleep 1
done

if [[ "$DETECTED" != true ]]; then
    echo "ERROR: Monitor did not detect the switch"
    cat "$MONITOR_LOG"
    exit 1
fi

echo "Monitor detected green deployment"

echo
echo "===== INJECTING CONTROLLED FAILURE ====="

T0=$(date +%s)
echo "T0: $(date -Is)"

sudo -n systemctl stop kk-api-green.service

RECOVERED=false
RECOVERY=0

for attempt in $(seq 1 40); do
    ACTIVE=$(cat "$BASE/.active-env")
    RESPONSE=$(curl -fsS --max-time 2 \
        http://127.0.0.1:8088/health 2>/dev/null || true)

    if [[ "$ACTIVE" == "blue" ]] &&
       [[ "$RESPONSE" == *'"version":"v1.3.0"'* ]]; then

        T2=$(date +%s)
        RECOVERY=$((T2-T0))
        RECOVERED=true
        break
    fi

    sleep 2
done

# Allow the monitor to finish writing its final messages.
if [[ "$RECOVERED" == true ]]; then
    sleep 1
fi

{
    echo "===== AUTOMATIC ROLLBACK EVIDENCE ====="
    echo "T0 - Failure: $(date -d "@$T0" -Is)"

    if [[ "$RECOVERED" == true ]]; then
        echo "T2 - Recovery: $(date -d "@$T2" -Is)"
        echo "Recovery duration: $RECOVERY seconds"
    else
        echo "Recovery not confirmed"
    fi

    echo
    echo "Active environment: $(cat "$BASE/.active-env")"
    echo "Previous environment: $(cat "$BASE/.previous-env")"
    echo "Nginx upstream: $(readlink -f /etc/nginx/kijanikiosk-active-env.conf)"

    echo
    echo "===== MONITOR LOG ====="
    cat "$MONITOR_LOG"

    echo
    if [[ "$RECOVERED" == true ]] &&
       (( RECOVERY < 90 )) &&
       grep -q 'ROLLBACK TRIGGERED' "$MONITOR_LOG"; then
        echo "PASS: Automatic rollback completed within 90 seconds"
    else
        echo "FAIL: Automatic rollback requirement not met"
    fi

} | tee "$EVIDENCE"

[[ "$RECOVERED" == true ]] || exit 1
(( RECOVERY < 90 )) || exit 1
grep -q 'ROLLBACK TRIGGERED' "$MONITOR_LOG"
