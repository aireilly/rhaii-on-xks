# xKS Configuration Reference for llm-d Deployments

This document provides configuration guidance for deploying llm-d on managed Kubernetes services (AKS, EKS, GKE). It covers common configurations that may need adjustment based on your cluster setup.

## Table of Contents
- [Monitoring Configuration](#monitoring-configuration)
- [GPU Node Scheduling](#gpu-node-scheduling)
- [Cloud-Specific Values Files](#cloud-specific-values-files)

---

## Monitoring Configuration

### Current State
The default llm-d guide values enable monitoring components (ServiceMonitor/PodMonitor), which require:
- Prometheus Operator CRDs installed
- kube-prometheus-stack or similar monitoring stack deployed

### Recommendation: Disable by Default

For most xKS deployments, monitoring should be **disabled by default** and enabled only when needed.

**Rationale:**
- Monitoring is optional infrastructure, not core functionality
- Requires additional dependencies (Prometheus Operator)
- Can be enabled later when monitoring stack is ready
- Reduces initial deployment complexity

### Configuration Changes

**ms-inference-scheduling/values.yaml:**
```yaml
decode:
  monitoring:
    podmonitor:
      enabled: false  # Change from true to false
```

**gaie-inference-scheduling/values.yaml:**
```yaml
inferenceExtension:
  monitoring:
    prometheus:
      enabled: false  # Already false, keep it
```

### When to Enable Monitoring
Enable monitoring when:
- Prometheus Operator is installed
- You need metrics collection for autoscaling (HPA/KEDA)
- Production observability is required

---

## GPU Node Scheduling

### The Problem

Many managed Kubernetes services apply **taints** to GPU nodes to prevent non-GPU workloads from consuming expensive GPU resources. Without matching **tolerations**, GPU workloads cannot schedule on these nodes.

### Where Do GPU Taints Come From?

**Important:** The NVIDIA GPU Operator does **NOT** add taints by default. Taints are a cluster setup decision made by administrators.

**Common sources of GPU node taints:**

| Source | Description | When It Happens |
|--------|-------------|-----------------|
| **Cloud provider node pool** | AKS/EKS/GKE can taint GPU nodes at creation | `az aks nodepool add --node-taints nvidia.com/gpu=present:NoSchedule` |
| **NVIDIA GPU Operator NFD** | Node Feature Discovery can be configured to taint | Optional, not enabled by default |
| **Manual admin action** | Admin explicitly taints nodes | `kubectl taint nodes <node> nvidia.com/gpu=present:NoSchedule` |

**GPU Operator behavior:**
- GPU Operator daemonsets have **tolerations** to run on tainted GPU nodes
- GPU Operator does **NOT add** taints automatically
- Tainting is a deliberate cluster architecture decision

**Why taint GPU nodes?**
- Prevents non-GPU workloads from landing on expensive GPU nodes
- Ensures GPU resources are reserved for workloads that need them
- Recommended for mixed clusters (CPU + GPU node pools)

### Common GPU Node Taints by Provider

| Provider | Taint Key | Taint Value | Effect |
|----------|-----------|-------------|--------|
| AKS | `nvidia.com/gpu` | `present` | `NoSchedule` |
| EKS | `nvidia.com/gpu` | `true` | `NoSchedule` |
| GKE | `nvidia.com/gpu` | `present` | `NoSchedule` |
| DigitalOcean | `nvidia.com/gpu` | `true` | `NoSchedule` |

> **Note:** These taints may vary based on GPU operator configuration and cluster setup. Check your actual node taints with:
> ```bash
> kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints'
> ```

### When Tolerations Are Required

**Required** - Mixed node clusters (CPU + GPU nodes):
```
┌─────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster                      │
├─────────────────────────────┬───────────────────────────────┤
│       CPU Node Pool         │        GPU Node Pool          │
│  (no taint)                 │  (nvidia.com/gpu:NoSchedule)  │
├─────────────────────────────┼───────────────────────────────┤
│  - Gateway pods             │  - vLLM decode pods           │
│  - EPP (inference scheduler)│  - vLLM prefill pods          │
│  - Operators                │                               │
│  - Monitoring               │                               │
└─────────────────────────────┴───────────────────────────────┘
```

In this setup:
- GPU nodes have taints to repel non-GPU workloads
- LLM pods need tolerations to schedule on GPU nodes
- Non-GPU pods (gateway, EPP) naturally land on CPU nodes

**Not Required** - All-GPU clusters:
- If all nodes have GPUs and no taints, tolerations are unnecessary
- If GPU nodes have no taints, tolerations are unnecessary

### Adding Tolerations to Values

**For AKS (nvidia.com/gpu=present:NoSchedule):**

```yaml
decode:
  tolerations:
    - key: "nvidia.com/gpu"
      operator: "Equal"
      value: "present"
      effect: "NoSchedule"

prefill:  # If using PD disaggregation
  tolerations:
    - key: "nvidia.com/gpu"
      operator: "Equal"
      value: "present"
      effect: "NoSchedule"
```

**For EKS/DigitalOcean (nvidia.com/gpu=true:NoSchedule):**

```yaml
decode:
  tolerations:
    - key: "nvidia.com/gpu"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
```

**Universal toleration (any value):**

```yaml
decode:
  tolerations:
    - key: "nvidia.com/gpu"
      operator: "Exists"
      effect: "NoSchedule"
```

### Debugging Scheduling Issues

**Check if pods are pending due to taints:**
```bash
kubectl describe pod <pod-name> -n <namespace> | grep -A5 Events
```

Look for messages like:
```
0/4 nodes are available: 2 node(s) had untolerated taint {nvidia.com/gpu: present}
```

**Check node taints:**
```bash
kubectl get nodes -l nvidia.com/gpu=present -o json | jq '.items[].spec.taints'
```

**Check pod tolerations:**
```bash
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.tolerations}' | jq
```

---

## Cloud-Specific Values Files

### Current Gap in llm-d Guides

| Guide | Has AKS values? | Has EKS values? | Has GKE values? | Has DO values? |
|-------|-----------------|-----------------|-----------------|----------------|
| inference-scheduling | No | No | Yes (gke env) | Yes |
| pd-disaggregation | Yes | No | Yes | No |

### Recommendation

Add cloud-provider-specific values files to all guides:

```
guides/inference-scheduling/ms-inference-scheduling/
├── values.yaml              # Base values (no tolerations)
├── values-aks.yaml          # AKS with tolerations
├── values-eks.yaml          # EKS with tolerations
├── values-gke.yaml          # GKE specific
├── digitalocean-values.yaml # Already exists
└── ...
```

### Example values-aks.yaml for inference-scheduling

```yaml
# AKS-specific overrides for inference-scheduling
# Usage: helmfile apply -e aks

decode:
  tolerations:
    - key: "nvidia.com/gpu"
      operator: "Equal"
      value: "present"
      effect: "NoSchedule"
  monitoring:
    podmonitor:
      enabled: false  # Enable when Prometheus Operator is installed
```

### Helmfile Environment Addition

Add to `helmfile.yaml.gotmpl`:

```yaml
environments:
  # ... existing environments ...
  aks: &AKS
    <<: *I  # Inherit from istio
  eks: &EKS
    <<: *I  # Inherit from istio

# In releases section, add:
{{- else if eq .Environment.Name "aks" }}
  - ms-inference-scheduling/values-aks.yaml
{{- else if eq .Environment.Name "eks" }}
  - ms-inference-scheduling/values-eks.yaml
```

---

## Quick Reference: xKS Deployment Checklist

### Before Deployment
- [ ] Check GPU node taints: `kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints'`
- [ ] Determine if tolerations are needed (mixed CPU/GPU cluster?)
- [ ] Verify HuggingFace token secret exists
- [ ] Check if monitoring stack is deployed (optional)

### Values Customization
- [ ] Set appropriate `replicas` based on available GPUs
- [ ] Set `parallelism.tensor` based on GPUs per node
- [ ] Add tolerations if GPU nodes are tainted
- [ ] Disable monitoring if Prometheus Operator not installed
- [ ] Adjust resource requests/limits for your GPU type

### After Deployment
- [ ] Verify pods scheduled on correct nodes
- [ ] Check model loading progress in logs
- [ ] Test inference endpoint when ready

---

## Discussion Points for Documentation Team

1. **Default monitoring state**: Should guides default to `enabled: false` for monitoring components since they require additional infrastructure?

2. **Cloud-specific values**: Should all guides include `values-aks.yaml`, `values-eks.yaml` for consistency with `pd-disaggregation`?

3. **Helmfile environments**: Should `aks` and `eks` environments be added to all guide helmfiles?

4. **Toleration documentation**: Should there be a central document explaining GPU scheduling and when tolerations are needed?

5. **Prerequisites section**: Should guide READMEs include a section on checking node taints before deployment?

6. **Clarify taint source**: Documentation should clarify that:
   - NVIDIA GPU Operator does NOT add taints by default
   - Taints are a cluster setup decision (node pool config or manual)
   - Users need to check their cluster's taint configuration before deploying
   - If GPU nodes are tainted, tolerations must be added to values

7. **Recommendation for mixed clusters**: For clusters with both CPU and GPU node pools:
   - GPU nodes SHOULD be tainted to prevent non-GPU workloads from consuming GPU resources
   - llm-d guides SHOULD provide cloud-specific values with appropriate tolerations
   - This is a best practice, not automatic behavior
