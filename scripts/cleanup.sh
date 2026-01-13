#!/bin/bash
# Full cleanup of Sail Operator and all related resources
# Usage: ./scripts/cleanup.sh [--include-crds]
#
# What gets cleaned up:
#   - Helm release (deployment, RBAC, secrets, Istio CR)
#   - Namespace (Helm doesn't auto-delete namespaces)
#   - Cluster-scoped RBAC (ClusterRole, ClusterRoleBinding)
#   - CRDs (optional, with --include-crds)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="istio-system"
INCLUDE_CRDS=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --include-crds)
      INCLUDE_CRDS=true
      ;;
  esac
done

echo "============================================"
echo "  Sail Operator Cleanup"
echo "============================================"
echo ""

# Remove Helm release
echo "[1/4] Removing Helm release..."
if helm status sail-operator -n $NAMESPACE &>/dev/null; then
  helm uninstall sail-operator -n $NAMESPACE --wait
  echo "Helm release removed"
else
  echo "No Helm release found (skipping)"
fi

# Remove namespace
echo ""
echo "[2/4] Removing namespace..."
if kubectl get ns $NAMESPACE &>/dev/null; then
  kubectl delete ns $NAMESPACE --wait=true
  echo "Namespace $NAMESPACE removed"
else
  echo "Namespace $NAMESPACE not found (skipping)"
fi

# Remove cluster-scoped resources
echo ""
echo "[3/4] Removing cluster-scoped RBAC..."
kubectl delete clusterrole metrics-reader servicemesh-operator3-clusterrole --ignore-not-found
kubectl delete clusterrolebinding servicemesh-operator3-clusterrolebinding --ignore-not-found
echo "Cluster RBAC removed"

# Remove CRDs if requested
echo ""
echo "[4/4] CRDs..."
if [ "$INCLUDE_CRDS" = true ]; then
  echo "Removing Sail Operator CRDs..."
  kubectl delete crd -l sailoperator.io/managed=true --ignore-not-found 2>/dev/null || true
  kubectl get crd -o name | grep -E "istio\.io|sailoperator\.io" | xargs -r kubectl delete --ignore-not-found 2>/dev/null || true

  echo "Removing Gateway API CRDs..."
  kubectl get crd -o name | grep -E "gateway\.networking\.k8s\.io|inference\.networking\.x-k8s\.io" | xargs -r kubectl delete --ignore-not-found 2>/dev/null || true
  echo "CRDs removed"
else
  echo "Skipping CRDs (use --include-crds to remove)"
fi

echo ""
echo "============================================"
echo "  Cleanup Complete!"
echo "============================================"
echo ""
echo "To reinstall: cd $CHART_DIR && helmfile apply"
