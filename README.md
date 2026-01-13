# Sail Operator Helm Chart

Deploy Red Hat Sail Operator (OSSM 3.x) on any Kubernetes cluster without OLM.

## Prerequisites

- `kubectl` configured for your cluster
- `helmfile` installed
- For Red Hat registry: One of the following auth methods

## Quick Start

```bash
cd sail-operator-chart

# 1. Login to Red Hat registry (Option A - recommended)
podman login registry.redhat.io

# 2. Deploy
helmfile apply
```

## Configuration

Edit `environments/default.yaml`. Choose ONE auth method:

### Option A: System Podman Auth (Recommended)

```bash
# 1. Get your pull secret from Red Hat
#    https://console.redhat.com/openshift/install/pull-secret
#    Save as: ~/pull-secret.txt

# 2. Login to registry using the pull secret
podman login registry.redhat.io --authfile ~/pull-secret.txt

# 3. Verify login
podman pull registry.redhat.io/ubi8/ubi-minimal --quiet && echo "Login successful"
```

```yaml
# environments/default.yaml
useSystemPodmanAuth: true
```

This uses `${XDG_RUNTIME_DIR}/containers/auth.json` automatically.

### Option B: Pull Secret File Directly

```yaml
# environments/default.yaml
pullSecretFile: ~/pull-secret.txt
```

### Option C: Konflux (public, no auth)

```yaml
# environments/default.yaml
bundle:
  source: konflux

# Leave both empty
pullSecretFile: ""
authFile: ""
```

## What Gets Deployed

**Presync hooks (before Helm install):**
1. Gateway API CRDs (v1.4.0) - from GitHub
2. Gateway API Inference Extension CRDs (v1.2.0) - from GitHub
3. Sail Operator CRDs (19 Istio CRDs) - applied with `--server-side`

**Helm install:**
4. Namespace `istio-system`
5. Pull secret `redhat-pull-secret`
6. Sail Operator deployment + RBAC
7. Istio CR with Gateway API enabled

**Post-install hook:**
8. Patches `istiod` ServiceAccount with pull secret (waits up to 5 min for SA to be created)

> **Why hooks?** CRDs are too large for Helm (some are 700KB+, Helm has 1MB limit) and require `--server-side` apply. The istiod SA is created asynchronously by the operator.

## Update to New Bundle Version

```bash
# Update chart manifests
./scripts/update-bundle.sh 3.3.0 redhat

# Redeploy
helmfile apply
```

## Verify Installation

```bash
# Check operator
kubectl get pods -n istio-system

# Check CRDs
kubectl get crd | grep istio

# Check Istio CR
kubectl get istio -n istio-system

# Check istiod
kubectl get pods -n istio-system -l app=istiod
```

## Uninstall

```bash
# Remove Helm release and namespace (keeps CRDs)
./scripts/cleanup.sh

# Full cleanup including CRDs
./scripts/cleanup.sh --include-crds
```

---

## Post-Deployment: Application Namespaces

When deploying applications that use Istio Gateway API (e.g., llm-d), Istio auto-provisions Gateway pods in **your application namespace**. These pods pull `istio-proxyv2` from `registry.redhat.io` and need the pull secret.

**After deploying your application (e.g., llm-d), run these steps:**

```bash
# Set your application namespace
export APP_NAMESPACE=my-app-namespace

# 1. Copy pull secret to your application namespace
kubectl get secret redhat-pull-secret -n istio-system -o yaml | \
  sed "s/namespace: istio-system/namespace: ${APP_NAMESPACE}/" | \
  kubectl apply -f -

# 2. Patch the gateway's ServiceAccount (name varies by deployment)
#    Find it with: kubectl get sa -n ${APP_NAMESPACE} | grep gateway
kubectl patch serviceaccount <gateway-sa-name> -n ${APP_NAMESPACE} \
  -p '{"imagePullSecrets": [{"name": "redhat-pull-secret"}]}'

# 3. Restart the gateway pod
kubectl delete pod -n ${APP_NAMESPACE} -l gateway.istio.io/managed=istio.io-gateway-controller
```

**Example for llm-d:**

```bash
export APP_NAMESPACE=llmd-pd-aputtur

kubectl get secret redhat-pull-secret -n istio-system -o yaml | \
  sed "s/namespace: istio-system/namespace: ${APP_NAMESPACE}/" | \
  kubectl apply -f -

kubectl patch serviceaccount infra-inference-scheduling-inference-gateway-istio -n ${APP_NAMESPACE} \
  -p '{"imagePullSecrets": [{"name": "redhat-pull-secret"}]}'

kubectl delete pod -n ${APP_NAMESPACE} -l gateway.istio.io/managed=istio.io-gateway-controller
```

**Or use the helper script:**

```bash
./scripts/copy-pull-secret.sh <namespace> <gateway-sa-name>
```

> **Why?** Istio Gateway pods run Envoy proxy (`istio-proxyv2`) which is pulled from `registry.redhat.io`. Without the pull secret in your namespace, these pods will have `ImagePullBackOff` errors.

---

## File Structure

```
sail-operator-chart/
├── Chart.yaml
├── values.yaml                  # Default values
├── helmfile.yaml.gotmpl         # Deploy with: helmfile apply
├── .helmignore                  # Excludes large files from Helm
├── environments/
│   └── default.yaml             # User config (useSystemPodmanAuth)
├── manifests-crds/              # 19 Istio CRDs (applied via presync hook)
├── templates/
│   ├── deployment-*.yaml        # Sail Operator deployment
│   ├── istio-cr.yaml            # Istio CR with Gateway API
│   ├── pull-secret.yaml         # Registry pull secret
│   ├── post-install-hook.yaml   # Patches istiod SA after install
│   └── *.yaml                   # RBAC, ServiceAccount, etc.
└── scripts/
    ├── update-bundle.sh         # Update to new bundle version
    ├── cleanup.sh               # Full uninstall
    └── copy-pull-secret.sh      # Copy secret to app namespaces
```
