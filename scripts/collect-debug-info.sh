#!/bin/bash
# Collect debug info for all rhaii-on-xks components
# Output can be shared with Red Hat support
#
# Usage:
#   ./scripts/collect-debug-info.sh [output-dir]

OUTPUT_DIR="${1:-/tmp/rhaii-on-xks-debug-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUTPUT_DIR"

echo "Collecting debug info to: $OUTPUT_DIR"
echo ""

# Check kubeconfig
kubectl cluster-info >/dev/null 2>&1 || { echo "ERROR: Cannot connect to cluster"; exit 1; }

STEP=1
TOTAL=12

echo "[$STEP/$TOTAL] Cluster info..."
{
    kubectl cluster-info
    echo ""
    kubectl version
    echo ""
    echo "=== Nodes ==="
    kubectl get nodes -o wide
} > "$OUTPUT_DIR/cluster-info.txt" 2>&1

STEP=$((STEP+1))
echo "[$STEP/$TOTAL] Helm releases..."
{
    echo "=== Helm releases (all namespaces) ==="
    helm list -A
} > "$OUTPUT_DIR/helm-releases.txt" 2>&1

# --- cert-manager ---
STEP=$((STEP+1))
echo "[$STEP/$TOTAL] cert-manager operator..."
{
    echo "=== cert-manager-operator pods ==="
    kubectl get pods -n cert-manager-operator -o wide 2>&1
    echo ""
    echo "=== cert-manager pods ==="
    kubectl get pods -n cert-manager -o wide 2>&1
    echo ""
    echo "=== cert-manager deployments ==="
    kubectl get deployments -n cert-manager -o wide 2>&1
    echo ""
    echo "=== CertManager CR ==="
    kubectl get certmanager cluster -o yaml 2>&1
} > "$OUTPUT_DIR/cert-manager-status.txt" 2>&1

STEP=$((STEP+1))
echo "[$STEP/$TOTAL] cert-manager logs..."
kubectl logs -n cert-manager-operator -l name=cert-manager-operator --tail=500 > "$OUTPUT_DIR/cert-manager-operator-logs.txt" 2>&1
kubectl logs -n cert-manager -l app.kubernetes.io/component=controller --tail=500 > "$OUTPUT_DIR/cert-manager-controller-logs.txt" 2>&1
kubectl logs -n cert-manager -l app.kubernetes.io/component=webhook --tail=500 > "$OUTPUT_DIR/cert-manager-webhook-logs.txt" 2>&1

STEP=$((STEP+1))
echo "[$STEP/$TOTAL] Certificates and Issuers..."
{
    echo "=== ClusterIssuers ==="
    kubectl get clusterissuers -o wide 2>&1
    echo ""
    echo "=== Issuers (all namespaces) ==="
    kubectl get issuers -A -o wide 2>&1
    echo ""
    echo "=== Certificates (all namespaces) ==="
    kubectl get certificates -A -o wide 2>&1
    echo ""
    echo "=== CertificateRequests (all namespaces) ==="
    kubectl get certificaterequests -A -o wide 2>&1
} > "$OUTPUT_DIR/certificates-issuers.txt" 2>&1

# --- Istio / Sail Operator ---
STEP=$((STEP+1))
echo "[$STEP/$TOTAL] Istio / Sail Operator..."
{
    echo "=== istio-system pods ==="
    kubectl get pods -n istio-system -o wide 2>&1
    echo ""
    echo "=== Istio CR ==="
    kubectl get istio -n istio-system -o yaml 2>&1
    echo ""
    echo "=== GatewayClasses ==="
    kubectl get gatewayclasses -o wide 2>&1
    echo ""
    echo "=== Gateways (all namespaces) ==="
    kubectl get gateways -A -o wide 2>&1
    echo ""
    echo "=== HTTPRoutes (all namespaces) ==="
    kubectl get httproutes -A -o wide 2>&1
    echo ""
    echo "=== InferencePools (all namespaces) ==="
    kubectl get inferencepools -A -o wide 2>&1
    echo ""
    echo "=== Webhook configs ==="
    kubectl get mutatingwebhookconfiguration -l operator.istio.io/component=Pilot -o yaml 2>&1
    kubectl get validatingwebhookconfiguration -l operator.istio.io/component=Pilot -o yaml 2>&1
} > "$OUTPUT_DIR/istio-status.txt" 2>&1

STEP=$((STEP+1))
echo "[$STEP/$TOTAL] Istio logs..."
kubectl logs -n istio-system -l app=istiod --tail=500 > "$OUTPUT_DIR/istiod-logs.txt" 2>&1
kubectl logs -n istio-system -l name=sail-operator --tail=500 > "$OUTPUT_DIR/sail-operator-logs.txt" 2>&1

# --- LWS Operator ---
STEP=$((STEP+1))
echo "[$STEP/$TOTAL] LWS Operator..."
{
    echo "=== LWS Operator pods ==="
    kubectl get pods -n openshift-lws-operator -o wide 2>&1
    echo ""
    echo "=== LeaderWorkerSetOperator CR ==="
    kubectl get leaderworkersetoperator cluster -o yaml 2>&1
    echo ""
    echo "=== LeaderWorkerSets (all namespaces) ==="
    kubectl get leaderworkersets -A -o wide 2>&1
    echo ""
    echo "=== LWS Certificates ==="
    kubectl get certificates -n openshift-lws-operator -o wide 2>&1
    echo ""
    echo "=== LWS Webhook configs ==="
    kubectl get mutatingwebhookconfiguration lws-mutating-webhook-configuration -o yaml 2>&1
    kubectl get validatingwebhookconfiguration lws-validating-webhook-configuration -o yaml 2>&1
} > "$OUTPUT_DIR/lws-operator-status.txt" 2>&1

STEP=$((STEP+1))
echo "[$STEP/$TOTAL] LWS Operator logs..."
kubectl logs -n openshift-lws-operator -l control-plane=controller-manager --tail=500 > "$OUTPUT_DIR/lws-operator-logs.txt" 2>&1

# --- KServe ---
STEP=$((STEP+1))
echo "[$STEP/$TOTAL] KServe..."
{
    echo "=== opendatahub pods ==="
    kubectl get pods -n opendatahub -o wide 2>&1
    echo ""
    echo "=== LLMInferenceServiceConfig ==="
    kubectl get llminferenceserviceconfig -n opendatahub -o yaml 2>&1
    echo ""
    echo "=== LLMInferenceServices (all namespaces) ==="
    kubectl get llmisvc -A -o wide 2>&1
    echo ""
    echo "=== Gateway in opendatahub ==="
    kubectl get gateway -n opendatahub -o wide 2>&1
} > "$OUTPUT_DIR/kserve-status.txt" 2>&1

STEP=$((STEP+1))
echo "[$STEP/$TOTAL] KServe controller logs..."
kubectl logs -n opendatahub -l control-plane=kserve-controller-manager --tail=500 > "$OUTPUT_DIR/kserve-controller-logs.txt" 2>&1

# --- Events ---
STEP=$((STEP+1))
echo "[$STEP/$TOTAL] Recent warning/error events..."
{
    for ns in cert-manager-operator cert-manager istio-system openshift-lws-operator opendatahub; do
        echo "=== Events in $ns ==="
        kubectl get events -n "$ns" --sort-by='.lastTimestamp' --field-selector type!=Normal 2>&1 | tail -30
        echo ""
    done
} > "$OUTPUT_DIR/warning-events.txt" 2>&1

echo ""
echo "=== Debug info collected ==="
echo ""
ls -la "$OUTPUT_DIR"
echo ""
echo "To share: tar -czf rhaii-debug.tar.gz -C $(dirname "$OUTPUT_DIR") $(basename "$OUTPUT_DIR")"
