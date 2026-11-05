#!/usr/bin/env bash
set -Eeuo pipefail
TARGET="${1:-}"
[[ "$TARGET" == blue || "$TARGET" == green ]] || { echo 'Usage: switch-env.sh blue|green' >&2; exit 2; }
BASE=/opt/kijanikiosk
exec 9>"$BASE/.switch.lock"
flock -x 9
ACTIVE=$(cat "$BASE/.active-env")
[[ "$ACTIVE" == blue || "$ACTIVE" == green ]] || exit 1
if [[ "$TARGET" == "$ACTIVE" ]]; then echo "[$(date -Is)] Already active: $TARGET"; exit 0; fi
if [[ "$TARGET" == blue ]]; then PORT=3100; VERSION=v1.3.0; else PORT=3101; VERSION=v1.4.0; fi
systemctl is-active --quiet "kk-api-$TARGET.service" || { echo 'Target service inactive' >&2; exit 1; }
BODY=$(curl -fsS --max-time 2 "http://127.0.0.1:$PORT/health") || { echo 'Target health check failed' >&2; exit 1; }
echo "$BODY" | grep -Fq '"version":"'"$VERSION"'"' || { echo "Wrong version on $TARGET: $BODY" >&2; exit 1; }
CURRENT_LINK=$(readlink -f /etc/nginx/kijanikiosk-active-env.conf)
NEW_LINK="/etc/nginx/kijanikiosk/$TARGET.conf"
ln -s "$NEW_LINK" /etc/nginx/kijanikiosk-active-env.conf.next
mv -Tf /etc/nginx/kijanikiosk-active-env.conf.next /etc/nginx/kijanikiosk-active-env.conf
if ! nginx -t >/dev/null 2>&1 || ! systemctl reload nginx; then
 ln -s "$CURRENT_LINK" /etc/nginx/kijanikiosk-active-env.conf.next
 mv -Tf /etc/nginx/kijanikiosk-active-env.conf.next /etc/nginx/kijanikiosk-active-env.conf
 nginx -t && systemctl reload nginx || true
 echo 'Switch failed; restored previous Nginx configuration' >&2
 exit 1
fi
# Verify the new upstream, allowing Nginx reload to settle.
VERIFIED=false
PROXY=""

for attempt in $(seq 1 10); do
    PROXY=$(curl -fsS --max-time 2 \
        http://127.0.0.1:8088/health 2>/dev/null || true)

    if printf '%s' "$PROXY" | grep -Fq "\"version\":\"$VERSION\""; then
        VERIFIED=true
        break
    fi

    sleep 1
done

if [[ "$VERIFIED" != true ]]; then
    echo "Proxy verification failed; restoring previous configuration" >&2

    ln -s "$CURRENT_LINK" \
        /etc/nginx/kijanikiosk-active-env.conf.next

    mv -Tf \
        /etc/nginx/kijanikiosk-active-env.conf.next \
        /etc/nginx/kijanikiosk-active-env.conf

    nginx -t && systemctl reload nginx || true
    exit 1
fi

printf '%s\n' "$ACTIVE" > "$BASE/.previous-env.tmp"
printf '%s\n' "$TARGET" > "$BASE/.active-env.tmp"
mv -f "$BASE/.previous-env.tmp" "$BASE/.previous-env"
mv -f "$BASE/.active-env.tmp" "$BASE/.active-env"
echo "[$(date -Is)] SWITCH OK: $ACTIVE -> $TARGET; proxy=$PROXY"
