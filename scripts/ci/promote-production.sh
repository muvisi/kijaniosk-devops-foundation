#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:?Image reference required}"
VERSION="${2:?Version required}"

NAMESPACE="default"
DEPLOYMENT="kk-payments"
CONTAINER="kk-payments"

echo "============================================"
echo " KIJANIKIOSK PRODUCTION PROMOTION"
echo "============================================"

CURRENT_IMAGE=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" \
  -o jsonpath="{.spec.template.spec.containers[?(@.name=='$CONTAINER')].image}")

CURRENT_VERSION=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" \
  -o jsonpath="{.spec.template.spec.containers[?(@.name=='$CONTAINER')].env[?(@.name=='APP_VERSION')].value}")

if [ -z "$CURRENT_IMAGE" ]; then
    echo "ERROR: Current production image could not be determined."
    exit 1
fi

echo "Current image: $CURRENT_IMAGE"
echo "Target image:  $IMAGE"

CHANGED=false

rollback() {
    if [ "$CHANGED" != true ]; then
        return
    fi

    echo "============================================"
    echo " PRODUCTION ROLLBACK"
    echo "============================================"

    trap - ERR

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
      -n "$NAMESPACE" \
      --timeout=180s

    echo "Rollback completed."
}

trap rollback ERR

CHANGED=true

kubectl set image "deployment/$DEPLOYMENT" \
  "$CONTAINER=$IMAGE" \
  -n "$NAMESPACE"

kubectl set env "deployment/$DEPLOYMENT" \
  "APP_VERSION=$VERSION" \
  -n "$NAMESPACE"

kubectl rollout status "deployment/$DEPLOYMENT" \
  -n "$NAMESPACE" \
  --timeout=180s

ACTUAL_IMAGE=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" \
  -o jsonpath="{.spec.template.spec.containers[?(@.name=='$CONTAINER')].image}")

if [ "$ACTUAL_IMAGE" != "$IMAGE" ]; then
    echo "ERROR: Production image mismatch."
    false
fi

echo "============================================"
echo " PRODUCTION ROLLOUT SUCCESSFUL"
echo "============================================"

CHANGED=false
trap - ERR
