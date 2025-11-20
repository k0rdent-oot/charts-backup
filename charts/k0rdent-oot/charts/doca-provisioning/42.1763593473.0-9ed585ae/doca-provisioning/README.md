# DOCA Provisioning Helm Chart

NVIDIA DOCA Platform Provisioning Controller for managing DPU lifecycle.

## Installation

### Basic Installation

```bash
helm install doca-provisioning \
  oci://ghcr.io/k0rdent-oot/charts/doca-provisioning \
  --version <VERSION> \
  --namespace doca-system \
  --create-namespace
```

### With Custom Values

```bash
helm install doca-provisioning \
  oci://ghcr.io/k0rdent-oot/charts/doca-provisioning \
  --version <VERSION> \
  --namespace doca-system \
  --create-namespace \
  --set image.tag=<IMAGE_TAG> \
  --set replicaCount=2
```

### Inspect Before Installing

```bash
# View chart information
helm show chart oci://ghcr.io/k0rdent-oot/charts/doca-provisioning --version <VERSION>

# View default values
helm show values oci://ghcr.io/k0rdent-oot/charts/doca-provisioning --version <VERSION>

# Render templates locally
helm template doca-provisioning \
  oci://ghcr.io/k0rdent-oot/charts/doca-provisioning \
  --version <VERSION> \
  --namespace doca-system
```

## Upgrading

```bash
helm upgrade doca-provisioning \
  oci://ghcr.io/k0rdent-oot/charts/doca-provisioning \
  --version <NEW_VERSION> \
  --namespace doca-system
```

## Uninstallation

```bash
# Uninstall the release (keeps CRDs)
helm uninstall doca-provisioning --namespace doca-system

# Delete the namespace
kubectl delete namespace doca-system
```

## Cleanup

### Clean Up from Previous Installation

If you encounter errors about existing resources from a previous installation in a different namespace:

```bash
# 1. Delete cluster-scoped resources
kubectl delete clusterrole doca-provisioning
kubectl delete clusterrolebinding doca-provisioning

# 2. Delete resources from old namespace (if installed in 'default')
kubectl delete serviceaccount -n default doca-provisioning
kubectl delete deployment -n default doca-provisioning
kubectl delete service -n default doca-provisioning

# 3. Now install in the new namespace
helm install doca-provisioning \
  oci://ghcr.io/k0rdent-oot/charts/doca-provisioning \
  --version <VERSION> \
  --namespace doca-system \
  --create-namespace
```

### Clean Up CRDs

**WARNING**: Deleting CRDs will delete all custom resources of these types.

```bash
# List CRDs
kubectl get crds | grep provisioning.dpu.nvidia.com

# Delete all DOCA provisioning CRDs
kubectl delete crd \
  bfbs.provisioning.dpu.nvidia.com \
  dpudevices.provisioning.dpu.nvidia.com \
  dpudiscoveries.provisioning.dpu.nvidia.com \
  dpuflavors.provisioning.dpu.nvidia.com \
  dpunodemaintenances.provisioning.dpu.nvidia.com \
  dpunodes.provisioning.dpu.nvidia.com \
  dpus.provisioning.dpu.nvidia.com \
  dpusets.provisioning.dpu.nvidia.com
```

### Complete Cleanup Script

```bash
#!/bin/bash
# Complete cleanup of DOCA provisioning

# Uninstall Helm release
helm uninstall doca-provisioning -n doca-system 2>/dev/null || true

# Delete cluster-scoped resources
kubectl delete clusterrole doca-provisioning 2>/dev/null || true
kubectl delete clusterrolebinding doca-provisioning 2>/dev/null || true

# Delete resources from old namespaces
for ns in default doca-system; do
  kubectl delete deployment -n $ns doca-provisioning 2>/dev/null || true
  kubectl delete service -n $ns doca-provisioning 2>/dev/null || true
  kubectl delete serviceaccount -n $ns doca-provisioning 2>/dev/null || true
done

# Delete CRDs (WARNING: removes all custom resources)
kubectl delete crds -l controller-gen.kubebuilder.io/version 2>/dev/null || true

# Delete namespace
kubectl delete namespace doca-system 2>/dev/null || true

echo "Cleanup complete"
```

## Troubleshooting

### Error: "metadata.managedFields must be nil"

This error occurs when CRDs have managedFields from a previous installation:

```bash
# Delete existing CRDs
kubectl delete crds -l controller-gen.kubebuilder.io/version

# Reinstall chart (CRDs will be recreated)
helm install doca-provisioning \
  oci://ghcr.io/k0rdent-oot/charts/doca-provisioning \
  --version <VERSION> \
  --namespace doca-system \
  --create-namespace
```

### Error: "cannot be imported into the current release"

This happens when resources exist from a previous installation in a different namespace:

```bash
# Clean up cluster-scoped resources
kubectl delete clusterrole doca-provisioning
kubectl delete clusterrolebinding doca-provisioning

# Then reinstall
helm install doca-provisioning \
  oci://ghcr.io/k0rdent-oot/charts/doca-provisioning \
  --version <VERSION> \
  --namespace doca-system \
  --create-namespace
```

### Error: "field not declared in schema"

This was a bug in chart versions before `42.1763592305.0-15caf95a`. Upgrade to the latest version.

## Configuration

See `values.yaml` for all configuration options. Key configurations:

```yaml
# Replica count
replicaCount: 1

# Image configuration
image:
  repository: ghcr.io/k0rdent-oot/nvidia-doca-lite
  tag: ""  # Defaults to chart appVersion

# DPU settings
dpu:
  installInterface: "InstallViaHostAgent"
  maxParallelInstallations: 50
  enableDiscovery: true

# Resource limits
resources:
  limits:
    cpu: 2
    memory: 2Gi
  requests:
    cpu: 1
    memory: 1Gi
```

## Version Format

Chart versions follow: `42.{timestamp}.0-{git-hash}`

Example: `42.1763592305.0-15caf95a`

- Major: `42` (fixed)
- Minor: Unix timestamp
- Patch: `0` (fixed)
- Pre-release: Git commit hash
