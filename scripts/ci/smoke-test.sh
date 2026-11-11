#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-kijani-staging}"
EXPECTED_VERSION="${2:?Expected version is required}"
POD="kk-smoke-${BUILD_NUMBER:-manual}-$(date +%s)"

cleanup() {
    kubectl delete pod "$POD" -n "$NAMESPACE" \
      --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Creating smoke-test pod: $POD"

kubectl run "$POD" \
  -n "$NAMESPACE" \
  --image=busybox:1.36 \
  --restart=Never \
  --command -- sh -c \
  'wget -qO- http://kk-payments-service:3001/health'

kubectl wait \
  -n "$NAMESPACE" \
  --for=jsonpath='{.status.phase}'=Succeeded \
  "pod/$POD" \
  --timeout=120s || {
    kubectl logs "$POD" -n "$NAMESPACE" || true
    exit 1
  }

RESPONSE=$(kubectl logs "$POD" -n "$NAMESPACE")

echo "Health response: $RESPONSE"

printf '%s' "$RESPONSE" | grep -q '"status":"healthy"'
printf '%s' "$RESPONSE" | grep -Fq "\"version\":\"$EXPECTED_VERSION\""

echo "Smoke test PASSED."
