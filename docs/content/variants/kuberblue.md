+++
title = 'Kuberblue'
weight = 4
+++

# Kuberblue

Kuberblue is the Kubernetes-ready variant of Immutablue, designed for running container orchestration workloads.

## Overview

Kuberblue includes everything needed to run a Kubernetes cluster:

- Pre-installed Kubernetes components (kubeadm, kubelet, kubectl)
- Container runtime (CRI-O)
- Networking components
- Automated cluster initialization

## Installation

```bash
sudo bootc switch ghcr.io/immutablue/kuberblue:latest
sudo reboot
```

## Configuration

Kuberblue settings are configured via `settings.yaml`:

```yaml
kuberblue:
  install_dir: "/usr/immutablue-build-kuberblue"
  config_dir: "/etc/kuberblue"
  uid: 970
```

| Setting | Default | Description |
|---------|---------|-------------|
| `.kuberblue.install_dir` | `/usr/immutablue-build-kuberblue` | Build artifacts directory |
| `.kuberblue.config_dir` | `/etc/kuberblue` | Configuration directory |
| `.kuberblue.uid` | `970` | System user UID |

## Cluster Setup

### Initialize a New Cluster

```bash
# Initialize the cluster
kuberblue init

# Get kubeconfig
kuberblue get-config
```

### Join an Existing Cluster

```bash
# Get join command from master node
kuberblue get-join-command

# On worker node
kuberblue join <token> <master-ip>
```

## Commands

The `kuberblue` command provides cluster management:

| Command | Description |
|---------|-------------|
| `kuberblue init` | Initialize a new cluster |
| `kuberblue reset` | Reset/destroy the cluster |
| `kuberblue get-config` | Copy kubeconfig to user |
| `kuberblue put-config` | Deploy kubeconfig to cluster |
| `kuberblue untaint-master` | Allow pods on master node |
| `kuberblue deploy` | Deploy applications |

## Justfile Commands

```bash
# Via immutablue command
immutablue kuberblue_init
immutablue kuberblue_reset
immutablue kuberblue_get_config
```

## Systemd Services

| Service | Description |
|---------|-------------|
| `kuberblue-onboot.service` | Cluster initialization on boot |

## Directory Structure

```
/usr/immutablue-build-kuberblue/    # Build artifacts
/etc/kuberblue/                      # Configuration
/usr/libexec/kuberblue/             # Scripts
    ├── kube_setup/                  # Setup scripts
    │   ├── kube_init.sh
    │   ├── kube_reset.sh
    │   ├── kube_get_config.sh
    │   └── ...
    ├── setup/                       # Boot scripts
    └── variables.sh                 # Configuration variables
```

## Networking

Kuberblue supports common CNI plugins:

- Flannel (default)
- Calico
- Cilium

## Storage

For persistent storage, consider:

- Local path provisioner
- NFS provisioner
- TrueBlue variant for ZFS-backed storage

## Best Practices

### Single-Node Cluster

For development or small deployments:

```bash
# Initialize
kuberblue init

# Allow workloads on master
kuberblue untaint-master
```

### Multi-Node Cluster

1. Initialize master node
2. Get join command from master
3. Join worker nodes

### Resource Limits

Recommended minimums:
- Master: 2 CPU, 4GB RAM
- Worker: 2 CPU, 2GB RAM

## Troubleshooting

### Cluster won't initialize

```bash
# Check kubelet status
systemctl status kubelet

# View kubelet logs
journalctl -u kubelet -f

# Reset and retry
kuberblue reset
kuberblue init
```

### Pods stuck in Pending

```bash
# Check node status
kubectl get nodes

# Check pod events
kubectl describe pod <pod-name>
```

## See Also

- [Immutablue Variants](/variants/)
- [TrueBlue (ZFS)](/variants/trueblue-zfs/) - For ZFS storage
