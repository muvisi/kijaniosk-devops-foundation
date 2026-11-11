#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?Image reference required}"
VERSION="${2:?Version required}"

NAMESPACE=default
DEPLOYMENT=kk-payments
CONTAINER=kk-payments

CURRENT_IMAGE=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" \
  -o jsonpath="{.spec.template.spec.containers[?(@.name=='$CONTAINER')].image}")

CURRENT_VERSION=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" \
  -o jsonpath="{.spec.template.spec.containers[?(@.name=='$CONTAINER')].env[?(@.name=='APP_VERSION')].value}")

echo "Previous production image: $CURRENT_IMAGE"
echo "New production image: $IMAGE"

rollback() {
    echo "Production verification failed. Restoring previous image."

    kubectl set image "deployment/$DEPLOYMENT" \
      "$CONTAINER=$CURRENT_IMAGE" \
      -n "$NAMESPACE"

    if [ -n "$CURRENT_VERSION" ]; then
        kubectl set env "deployment/$DEPLOYMENT" \
          "APP_VERSION=$CURRENT_VERSION" \
          -n "$NAMESPACE"
    else
        kubectl set env "deployment/$DEPLOYMENT" \
          APP_VERSION- \
          -n "$NAMESPACE"
    fi

    kubectl rollout status "deployment/$DEPLOYMENT" \
      -n "$NAMESPACE" --timeout=180s || true
}

trap rollback ERR

kubectl set image "deployment/$DEPLOYMENT" \
  "$CONTAINER=$IMAGE" \
  -n "$NAMESPACE"

kubectl set env "deployment/$DEPLOYMENT" \
  "APP_VERSION=$VERSION" \
  -n "$NAMESPACE"

kubectl rollout status "deployment/$DEPLOYMENT" \
  -n "$NAMESPACE" --timeout=180s

trap - ERR

echo "Production rollout PASSED."
