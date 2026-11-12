#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:?Image reference required}"
VERSION="${2:?Version required}"

NAMESPACE="${DEPLOY_NAMESPACE:-default}"
DEPLOYMENT="kk-payments"
CONTAINER="kk-payments"
HEALTH_URL="${PRODUCTION_HEALTH_URL:?PRODUCTION_HEALTH_URL required}"

CURRENT_IMAGE=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" \
  -o jsonpath="{.spec.template.spec.containers[?(@.name=='$CONTAINER')].image}")

CURRENT_VERSION=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" \
  -o jsonpath="{.spec.template.spec.containers[?(@.name=='$CONTAINER')].env[?(@.name=='APP_VERSION')].value}")

[ -n "$CURRENT_IMAGE" ] || {
    echo "ERROR: Cannot determine current production image"
    exit 1
}

echo "Current image: $CURRENT_IMAGE"
echo "Target image:  $IMAGE"

CHANGED=false

verify_http() {
    local expected="$1"
    local response

    for attempt in $(seq 1 12); do
        response=$(curl -fsS --max-time 5 "$HEALTH_URL" 2>/dev/null) || response=""

        if printf '%s' "$response" | python3 -c '
import json,sys
try:
    data=json.load(sys.stdin)
    assert data.get("status")=="healthy"
    assert data.get("version")==sys.argv[1]
except (ValueError, AssertionError):
    sys.exit(1)
' "$expected"; then
            echo "HTTP health verification passed: $response"
            return 0
        fi

        echo "Health check attempt $attempt failed"
        sleep 5
    done

    echo "ERROR: Production HTTP verification failed"
    return 1
}

rollback() {
    local original_status=$?
    trap - ERR
    trap - EXIT

    if [ "$CHANGED" = true ]; then
        echo "===== ROLLING BACK PRODUCTION ====="

        kubectl set image "deployment/$DEPLOYMENT" \
          "$CONTAINER=$CURRENT_IMAGE" -n "$NAMESPACE" || true

        if [ -n "$CURRENT_VERSION" ]; then
            kubectl set env "deployment/$DEPLOYMENT" \
              "APP_VERSION=$CURRENT_VERSION" -n "$NAMESPACE" || true
        else
            kubectl set env "deployment/$DEPLOYMENT" \
              APP_VERSION- -n "$NAMESPACE" || true
        fi

        kubectl rollout status "deployment/$DEPLOYMENT" \
          -n "$NAMESPACE" --timeout=180s || true

        if [ -n "$CURRENT_VERSION" ]; then
            verify_http "$CURRENT_VERSION" || true
        fi

        echo "Rollback attempted. Inspect production before retrying."
    fi

    exit "$original_status"
}

trap rollback ERR

CHANGED=true

kubectl set image "deployment/$DEPLOYMENT" \
  "$CONTAINER=$IMAGE" -n "$NAMESPACE"

kubectl set env "deployment/$DEPLOYMENT" \
  "APP_VERSION=$VERSION" -n "$NAMESPACE"

kubectl rollout status "deployment/$DEPLOYMENT" \
  -n "$NAMESPACE" --timeout=180s

ACTUAL_IMAGE=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" \
  -o jsonpath="{.spec.template.spec.containers[?(@.name=='$CONTAINER')].image}")

[ "$ACTUAL_IMAGE" = "$IMAGE" ]

verify_http "$VERSION"

CHANGED=false
trap - ERR

echo "Production promotion completed successfully."
