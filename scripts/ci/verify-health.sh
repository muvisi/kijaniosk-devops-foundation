#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:?Namespace required}"
EXPECTED_VERSION="${2:?Expected version required}"

DEPLOYMENT="kk-payments"

echo "Checking deployment in namespace: $NAMESPACE"

kubectl rollout status \
  "deployment/$DEPLOYMENT" \
  -n "$NAMESPACE" \
  --timeout=180s

READY=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')

DESIRED=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" \
  -o jsonpath='{.spec.replicas}')

if [ "${READY:-0}" != "$DESIRED" ]; then
    echo "ERROR: Ready replicas do not match desired replicas."
    exit 1
fi

echo "Deployment readiness verified."

if [ "$NAMESPACE" = "kijani-staging" ]; then
    bash scripts/ci/smoke-test.sh \
      "$NAMESPACE" "$EXPECTED_VERSION"
else
    echo "Production HTTP verification requires an approved probe."
    exit 1
fi
