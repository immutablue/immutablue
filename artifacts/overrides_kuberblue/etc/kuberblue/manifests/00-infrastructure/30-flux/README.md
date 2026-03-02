# Flux CD (Tier 1 Core)

Flux is installed via the `flux` CLI in `kube_flux_bootstrap.sh`, not via a Helm chart.

The flux CLI is downloaded during the image build (see `build/30-install-packages.sh`).

## Bootstrap

Flux bootstrap happens in `first_boot.sh` after the cluster is initialized:
- If `gitops.enabled: false` (default): Flux is installed passively (CRDs + controllers only)
- If `gitops.enabled: true`: Full bootstrap against the configured GitOps repo

## Configuration

Set options in `/etc/kuberblue/gitops.yaml` (overrides `/usr/kuberblue/gitops.yaml`):

```yaml
gitops:
  enabled: true
  repo:
    url: ssh://git@github.com/org/fleet-infra
    branch: main
    path: clusters/my-cluster
  provider: generic
  auth_secret: flux-git-auth
```

Create the SSH auth secret before bootstrapping:
```bash
flux create secret git flux-git-auth \
  --url=ssh://git@github.com/org/fleet-infra \
  --private-key-file=~/.ssh/id_ed25519
```
