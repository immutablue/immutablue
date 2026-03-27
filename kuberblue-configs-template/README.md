# kuberblue-configs

Cluster configuration repository for [kuberblue](https://gitlab.com/immutablue/immutablue) — a zero-touch Kubernetes OS built on Fedora bootc.

## Quick Start

1. Fork or clone this repo
2. Copy `clusters/example/` to `clusters/<your-cluster-name>/`
3. Edit the config files for your environment
4. (Optional) Encrypt secrets with SOPS + Age
5. Deploy:

```bash
# Generate an Age key pair (first time only)
age-keygen -o age.key
# Note the public key from the output

# Boot your kuberblue image with config injection:
# PXE/cmdline:
#   kuberblue.config=https://github.com/you/kuberblue-configs
#   kuberblue.config.path=clusters/my-cluster
#   kuberblue.age-key=AGE-SECRET-KEY-...
#
# Cloud-init: use the user-data template
#
# Ansible:
#   ansible-playbook provision.yaml \
#     -e kuberblue_config_url=https://github.com/you/kuberblue-configs \
#     -e kuberblue_config_path=clusters/my-cluster \
#     -e kuberblue_age_key_file=./age.key
```

## Repository Structure

```
clusters/
  example/              # Example cluster config (copy this)
    cluster.yaml        # Cluster topology, networking, node role
    cni.yaml            # CNI (Cilium) and overlay networking config
    gitops.yaml         # FluxCD GitOps configuration
    security.yaml       # SOPS, admin user, kubeconfig policy
    settings.yaml       # Global kuberblue settings
    packages.yaml       # Package tier overrides (enable/disable optional components)
    secrets/            # SOPS-encrypted secrets
      .sops.yaml        # SOPS configuration (Age recipients)
      tailscale-authkey.sops.yaml
      flux-git-auth.sops.yaml
```

## Config Files

| File | Purpose |
|------|---------|
| `cluster.yaml` | Cluster name, topology (single/multi/ha), node role, networking CIDRs, advertise address |
| `cni.yaml` | CNI choice (Cilium), Tailscale mesh, Cloudflare tunnel, kube-proxy replacement |
| `gitops.yaml` | FluxCD: enable/disable, git repo URL, branch, path, auth secret |
| `security.yaml` | SOPS Age key config, admin user/group, kubeconfig distribution |
| `settings.yaml` | kuberblue UID, install directory |
| `packages.yaml` | Enable/disable optional packages (monitoring, backup, cert-manager, etc.) |

## Secrets Management

Secrets are managed with [SOPS](https://github.com/getsops/sops) + [Age](https://github.com/FiloSottile/age) encryption.

### Setup

```bash
# Generate a key pair
age-keygen -o age.key 2>&1 | tee age.pub
# Output: public key: age1...

# Configure SOPS to use your Age public key
# Edit clusters/<name>/secrets/.sops.yaml and set the age recipient
```

### Encrypting secrets

```bash
# Create a plaintext secret file
cat > tailscale-authkey.yaml <<EOF
tailscale:
  authkey: "tskey-auth-xxxxx"
EOF

# Encrypt it
cd clusters/my-cluster/secrets/
sops --encrypt tailscale-authkey.yaml > tailscale-authkey.sops.yaml
rm tailscale-authkey.yaml  # Remove plaintext

# Commit the encrypted version
git add tailscale-authkey.sops.yaml
git commit -m "Add encrypted Tailscale authkey"
```

### Security model

- **Public repo + SOPS** (recommended): The repo can be public. All secrets are encrypted with Age. Only the Age private key can decrypt them. The Age key is injected at boot time (via kernel cmdline, cloud-init, or Ansible) and never stored in the repo.

- **Private repo + deploy token**: For environments where even the cluster topology is sensitive. A read-only deploy token is injected at boot alongside the Age key.

## Private Repo Support

For private repos, generate a read-only deploy token:

- **GitLab**: Project > Settings > Repository > Deploy Tokens (scope: `read_repository`)
- **GitHub**: Settings > Developer Settings > Fine-grained PATs (scope: `Contents: Read-only`)
- **Forgejo**: Settings > Applications > Access Tokens

Pass the token at boot:
```
kuberblue.config.token=glpat-xxxxx
```

## Cluster Topologies

### Single node (default)
```yaml
# cluster.yaml
cluster:
  topology: single
  node_role: control-plane
```

### Multi-node
```yaml
# Control plane node
cluster:
  topology: multi
  node_role: control-plane
  multi:
    worker_auto_join: true
    token_distribution: tailscale

# Worker node (separate config path)
cluster:
  topology: multi
  node_role: worker
  multi:
    worker_auto_join: true
    token_distribution: tailscale
```

### HA (3 control planes + kube-vip)
```yaml
cluster:
  topology: ha
  node_role: control-plane
  ha:
    vip_address: "192.168.1.100"
    control_planes: 3
```
