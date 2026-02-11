# Collecting Debug Information

This guide explains how to collect diagnostic information from your rhaii-on-xks deployment for troubleshooting or to share with Red Hat support.

## Quick Start

```bash
./scripts/collect-debug-info.sh
```

Output is saved to `/tmp/rhaii-on-xks-debug-<timestamp>/`.

To specify a custom output directory:

```bash
./scripts/collect-debug-info.sh /path/to/output
```

## What Is Collected

The script collects the following information from your cluster:

| Step | Component | Data Collected |
|------|-----------|----------------|
| 1 | Cluster | Kubernetes version, cluster info, node list |
| 2 | Helm | All Helm releases across namespaces |
| 3-4 | cert-manager | Operator, controller, and webhook pod status and logs |
| 5 | Certificates | ClusterIssuers, Issuers, Certificates, CertificateRequests |
| 6-7 | Istio / Sail Operator | Operator and istiod pod status and logs, Gateways, HTTPRoutes, InferencePools, GatewayClasses |
| 8-9 | LWS Operator | Operator pod status and logs, LeaderWorkerSets, webhook configs |
| 10-11 | KServe | Controller pod status and logs, LLMInferenceServices, LLMInferenceServiceConfig |
| 12 | Events | Warning and error events from all operator namespaces |

### Namespaces Inspected

- `cert-manager-operator`
- `cert-manager`
- `istio-system`
- `openshift-lws-operator`
- `opendatahub`

## Output Files

```
rhaii-on-xks-debug-<timestamp>/
├── cluster-info.txt                  # Kubernetes version, nodes
├── helm-releases.txt                 # All Helm releases
├── cert-manager-status.txt           # Pods, deployments, CertManager CR
├── cert-manager-operator-logs.txt    # Operator logs
├── cert-manager-controller-logs.txt  # Controller logs
├── cert-manager-webhook-logs.txt     # Webhook logs
├── certificates-issuers.txt          # All certs, issuers, ClusterIssuers
├── istio-status.txt                  # Pods, Istio CR, Gateways, HTTPRoutes
├── istiod-logs.txt                   # istiod logs
├── sail-operator-logs.txt            # Sail operator logs
├── lws-operator-status.txt           # Pods, LeaderWorkerSets, webhooks
├── lws-operator-logs.txt             # LWS operator logs
├── kserve-status.txt                 # Pods, LLMInferenceServices, Gateway
├── kserve-controller-logs.txt        # KServe controller logs
└── warning-events.txt                # Warning/error events from all namespaces
```

## Sharing with Red Hat Support

Package the collected data:

```bash
tar -czf rhaii-debug.tar.gz -C /tmp rhaii-on-xks-debug-*
```

Attach `rhaii-debug.tar.gz` to your support case.

## Privacy and Security

The script collects:
- Pod names, status, and logs
- Resource definitions (CRDs, CRs)
- Kubernetes events
- Helm release metadata

The script does **not** collect:
- Secret values (passwords, tokens, certificates)
- Application data or model weights
- Network traffic or request payloads

Review the output before sharing if your environment has specific data sensitivity requirements.

## Prerequisites

- `kubectl` configured with access to the cluster
- Read access to the namespaces listed above

## Troubleshooting the Script

If the script reports `ERROR: Cannot connect to cluster`:

```bash
# Verify kubeconfig
kubectl cluster-info

# Check current context
kubectl config current-context
```

If some sections show empty output, the corresponding component may not be deployed. This is expected if you haven't installed all components.
