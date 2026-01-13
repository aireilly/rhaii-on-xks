#!/bin/bash
# Copy pull secret to a namespace and patch Gateway ServiceAccount
# Usage: ./copy-pull-secret.sh <namespace> [gateway-sa-name]

set -e

NAMESPACE=${1:?Usage: $0 <namespace> [gateway-sa-name]}
GATEWAY_SA=${2:-""}
SOURCE_NS="istio-system"
SECRET_NAME="redhat-pull-secret"

echo "Copying $SECRET_NAME from $SOURCE_NS to $NAMESPACE..."
kubectl get secret $SECRET_NAME -n $SOURCE_NS -o yaml | \
  sed "s/namespace: $SOURCE_NS/namespace: $NAMESPACE/" | \
  kubectl apply -f -

if [ -n "$GATEWAY_SA" ]; then
  echo "Patching ServiceAccount $GATEWAY_SA with pull secret..."
  kubectl patch serviceaccount $GATEWAY_SA -n $NAMESPACE \
    -p "{\"imagePullSecrets\": [{\"name\": \"$SECRET_NAME\"}]}"
  
  echo "Restarting Gateway pods..."
  kubectl delete pod -n $NAMESPACE -l gateway.istio.io/managed=istio.io-gateway-controller 2>/dev/null || true
fi

echo "Done! Pull secret copied to $NAMESPACE"
