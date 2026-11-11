#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:?Target image required}"
VERSION="${2:?Target version required}"

NAMESPACE="default"
DEPLOYMENT="kk-payments"
CONTAINER="kk-payments"
HEALTH_URL="${PRODUCTION_HEALTH_URL:?Production health URL required}"

export KUBECONFIG="${KUBECONFIG:?KUBECONFIG required}"

PREVIOUS_IMAGE=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath="{.spec.template.spec.containers[?(@.name=='$CONTAINER')].image}")

PREVIOUS_VERSION=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath="{.spec.template.spec.containers[?(@.name=='$CONTAINER')].env[?(@.name=='APP_VERSION')].value}")

[ -n "$PREVIOUS_IMAGE" ] || {
  echo "ERROR: Previous production image is unknown."
  exit 1
}

echo "Previous image: $PREVIOUS_IMAGE"
echo "Target image:   $IMAGE"

check_rollout() {
  kubectl rollout status "deployment/$DEPLOYMENT" \
    -n "$NAMESPACE" --timeout=180s

  kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json |
    python3 -c '
import json,sys
d=json.load(sys.stdin)
spec=d["spec"]
status=d.get("status",{})
replicas=spec.get("replicas",1)
assert status.get("observedGeneration",0) >= d["metadata"]["generation"]
assert status.get("updatedReplicas",0) == replicas
assert status.get("availableReplicas",0) == replicas
assert status.get("readyReplicas",0) == replicas
print(f"All {replicas} replicas updated and available.")
'
}

check_http() {
  local expected="$1"
  local response

  for attempt in $(seq 1 12); do
    response=$(curl -fsS --max-time 5 "$HEALTH_URL" 2>/dev/null) || response=""

    if printf '%s' "$response" |
      python3 -c '
import json,sys
try:
    data=json.load(sys.stdin)
    assert data.get("status")=="healthy"
    assert data.get("version")==sys.argv[1]
except (ValueError,AssertionError):
    sys.exit(1)
' "$expected"; then
      echo "HTTP verification passed: $response"
      return 0
    fi

    echo "HTTP attempt $attempt failed"
    sleep 5
  done

  return 1
}

rollback() {
  echo "===== PRODUCTION ROLLBACK ====="

  local failed=0

  kubectl set image "deployment/$DEPLOYMENT" \
    "$CONTAINER=$PREVIOUS_IMAGE" -n "$NAMESPACE" || failed=1

  if [ -n "$PREVIOUS_VERSION" ]; then
    kubectl set env "deployment/$DEPLOYMENT" \
      "APP_VERSION=$PREVIOUS_VERSION" -n "$NAMESPACE" || failed=1
  else
    kubectl set env "deployment/$DEPLOYMENT" \
      APP_VERSION- -n "$NAMESPACE" || failed=1
  fi

  check_rollout || failed=1

  local restored_image
  restored_image=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    -o jsonpath="{.spec.template.spec.containers[?(@.name=='$CONTAINER')].image}") || failed=1

  [ "${restored_image:-}" = "$PREVIOUS_IMAGE" ] || failed=1

  if [ -n "$PREVIOUS_VERSION" ]; then
    check_http "$PREVIOUS_VERSION" || failed=1
  fi

  if [ "$failed" -eq 0 ]; then
    echo "ROLLBACK VERIFIED"
  else
    echo "CRITICAL: ROLLBACK VERIFICATION FAILED"
  fi

  return "$failed"
}

on_error() {
  local original_status=$?
  trap - ERR

  if rollback; then
    echo "Promotion failed; previous release restored."
  else
    echo "CRITICAL: Manual production recovery required."
  fi

  exit "$original_status"
}

trap on_error ERR

kubectl set image "deployment/$DEPLOYMENT" \
  "$CONTAINER=$IMAGE" -n "$NAMESPACE"

kubectl set env "deployment/$DEPLOYMENT" \
  "APP_VERSION=$VERSION" -n "$NAMESPACE"

check_rollout

ACTUAL_IMAGE=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath="{.spec.template.spec.containers[?(@.name=='$CONTAINER')].image}")

[ "$ACTUAL_IMAGE" = "$IMAGE" ]

check_http "$VERSION"

trap - ERR

echo "PRODUCTION PROMOTION VERIFIED"
