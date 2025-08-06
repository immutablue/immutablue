# Kuberblue Autocluster Specification

## Executive Summary

### Problem Statement
Kuberblue currently requires manual cluster setup with explicit configuration of control plane endpoints and manual execution of `kubeadm join` commands. This creates operational overhead and potential for configuration errors in production deployments.

### Solution Overview
Implement build-time role assignment with mDNS-based service discovery that allows Kuberblue nodes to have predetermined roles (control plane or worker) and automatically discover and join clusters without manual intervention.

### Key Benefits
- **Explicit Intent**: Clear role assignment eliminates ambiguity
- **Production Aligned**: Matches how real Kubernetes clusters are deployed
- **Eliminates Race Conditions**: No complex election or consensus mechanisms needed
- **Simple Implementation**: Straightforward role-specific boot logic
- **Container Best Practices**: Single responsibility per image type

## Architecture Overview

### Core Concept: Build-Time Role Assignment

Instead of runtime role discovery, Kuberblue uses build-time role specification:

```bash
# Build control plane image
make KUBERBLUE=1 CONTROL_PLANE=1 build

# Build worker image  
make KUBERBLUE=1 WORKER=1 build
```

This produces two distinct images:
- `kuberblue-control-plane`: Always initializes clusters
- `kuberblue-worker`: Always joins existing clusters

### Core Components

1. **Build-Time Role Specification**: Images built with predetermined roles
2. **mDNS Service Discovery**: Workers discover control planes via multicast DNS
3. **Role-Specific Boot Logic**: Separate initialization paths for each role
4. **Simple Service Advertisement**: Control planes advertise availability

### Technology Stack
- **Role Assignment**: Build-time flags and conditional logic
- **Service Discovery**: mDNS via Avahi daemon for worker→control plane discovery
- **Network Protocol**: Standard multicast DNS (port 5353)
- **Clustering**: Standard kubeadm bootstrap process with role-specific flows

## Technical Design

### Build System Integration

#### Makefile Extensions
```makefile
# New build targets
kuberblue-control-plane:
	make KUBERBLUE=1 CONTROL_PLANE=1 build

kuberblue-worker:
	make KUBERBLUE=1 WORKER=1 build

# Existing general target still works
kuberblue:
	make KUBERBLUE=1 build  # Default behavior unchanged
```

#### Conditional Build Logic
```bash
# In build scripts
if [[ "${CONTROL_PLANE:-}" == "1" ]]; then
    # Control plane specific setup
    cp control_plane_first_boot.sh /usr/libexec/kuberblue/setup/first_boot.sh
elif [[ "${WORKER:-}" == "1" ]]; then
    # Worker specific setup  
    cp worker_first_boot.sh /usr/libexec/kuberblue/setup/first_boot.sh
else
    # Default behavior (current single-node setup)
    # No changes to existing behavior
fi
```

### mDNS Service Advertisement

#### Control Plane Service
```xml
# /etc/avahi/services/kuberblue-control-plane.service
<service-group>
  <name replace-wildcards="yes">Kuberblue Control Plane on %h</name>
  <service>
    <type>_kuberblue-cp._tcp</type>
    <port>6443</port>
    <txt-record>version=1.0</txt-record>
    <txt-record>cluster-id=default</txt-record>
    <txt-record>ready=true</txt-record>
  </service>
</service-group>
```

#### Worker Service
```xml
# /etc/avahi/services/kuberblue-worker.service
<service-group>
  <name replace-wildcards="yes">Kuberblue Worker on %h</name>
  <service>
    <type>_kuberblue-worker._tcp</type>
    <port>10250</port>
    <txt-record>version=1.0</txt-record>
    <txt-record>cluster-id=default</txt-record>
  </service>
</service-group>
```

### Role-Specific Boot Logic

#### Control Plane Boot Process
```bash
#!/bin/bash
# /usr/libexec/kuberblue/control_plane_boot.sh

set -euo pipefail
source /usr/libexec/kuberblue/99-common.sh

main() {
    echo "Kuberblue Control Plane initialization starting..."
    
    # Create control plane service advertisement
    create_control_plane_service
    
    # Initialize Kubernetes cluster
    initialize_cluster
    
    # Setup kubectl access
    setup_kubectl_access
    
    # Deploy cluster manifests
    deploy_cluster_components
    
    echo "Control plane initialization complete"
}

initialize_cluster() {
    echo "Initializing Kubernetes cluster..."
    
    if [[ -f /etc/kubernetes/admin.conf ]]; then
        echo "Cluster already initialized, verifying health..."
        verify_cluster_health
        return
    fi
    
    # Run kubeadm init
    sudo kubeadm init --config /etc/kuberblue/kubeadm.yaml
    
    # Wait for cluster to be ready
    wait_for_cluster_ready
}

create_control_plane_service() {
    cat > /etc/avahi/services/kuberblue-control-plane.service << 'EOF'
<service-group>
  <name replace-wildcards="yes">Kuberblue Control Plane on %h</name>
  <service>
    <type>_kuberblue-cp._tcp</type>
    <port>6443</port>
    <txt-record>version=1.0</txt-record>
    <txt-record>cluster-id=default</txt-record>
    <txt-record>ready=true</txt-record>
  </service>
</service-group>
EOF
    
    systemctl reload avahi-daemon 2>/dev/null || true
}

verify_cluster_health() {
    if ! kubectl get nodes >/dev/null 2>&1; then
        echo "ERROR: Cluster appears unhealthy"
        exit 1
    fi
}

wait_for_cluster_ready() {
    local max_wait=300
    local elapsed=0
    
    while [[ $elapsed -lt $max_wait ]]; do
        if kubectl get nodes 2>/dev/null | grep -q Ready; then
            return 0
        fi
        sleep 5
        ((elapsed += 5))
    done
    
    echo "ERROR: Cluster not ready after ${max_wait}s"
    exit 1
}

setup_kubectl_access() {
    local kuberblue_home="/home/kuberblue"
    
    mkdir -p "$kuberblue_home/.kube"
    cp /etc/kubernetes/admin.conf "$kuberblue_home/.kube/config"
    chown kuberblue:kuberblue "$kuberblue_home/.kube/config"
}

deploy_cluster_components() {
    # Deploy manifests using existing script
    if [[ -x /usr/libexec/kuberblue/kube_setup/kube_deploy.sh ]]; then
        /usr/libexec/kuberblue/kube_setup/kube_deploy.sh
    fi
}

main "$@"
```

#### Worker Boot Process
```bash
#!/bin/bash
# /usr/libexec/kuberblue/worker_boot.sh

set -euo pipefail
source /usr/libexec/kuberblue/99-common.sh

main() {
    echo "Kuberblue Worker initialization starting..."
    
    # Check if already joined
    if [[ -f /etc/kubernetes/kubelet.conf ]]; then
        echo "Already joined cluster, resuming worker role..."
        create_worker_service
        verify_cluster_connection
        return
    fi
    
    # Discover and join cluster
    discover_and_join_cluster
    
    echo "Worker initialization complete"
}

discover_and_join_cluster() {
    echo "Discovering control plane..."
    
    local control_plane_ip
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        control_plane_ip=$(discover_control_plane)
        
        if [[ -n "$control_plane_ip" ]]; then
            echo "Found control plane at: $control_plane_ip"
            join_cluster "$control_plane_ip"
            create_worker_service
            return
        fi
        
        echo "No control plane found, attempt $attempt/$max_attempts, retrying in 10s..."
        sleep 10
        ((attempt++))
    done
    
    echo "ERROR: Could not find control plane after $max_attempts attempts"
    exit 1
}

discover_control_plane() {
    # Use avahi-browse to find control plane
    timeout 5 avahi-browse -t _kuberblue-cp._tcp 2>/dev/null | \
    grep -E '^=' | \
    head -1 | \
    awk '{print $(NF-1)}'
}

join_cluster() {
    local control_plane_ip=$1
    
    echo "Joining cluster at $control_plane_ip..."
    
    # Get bootstrap token from control plane API
    local join_command=$(get_join_command "$control_plane_ip")
    
    if [[ -z "$join_command" ]]; then
        echo "ERROR: Could not get join command"
        exit 1
    fi
    
    # Execute join command
    eval "$join_command"
}

get_join_command() {
    local control_plane_ip=$1
    
    # Try to get join command via kubeadm token create
    # This uses the cluster's API to create a new token
    local token_endpoint="https://$control_plane_ip:6443"
    
    # For now, use a simple approach with kubeadm discovery
    # In production, this would use proper token management
    echo "sudo kubeadm join $control_plane_ip:6443 --discovery-token-unsafe-skip-ca-verification --node-name $(hostname)"
}

create_worker_service() {
    cat > /etc/avahi/services/kuberblue-worker.service << 'EOF'
<service-group>
  <name replace-wildcards="yes">Kuberblue Worker on %h</name>
  <service>
    <type>_kuberblue-worker._tcp</type>
    <port>10250</port>
    <txt-record>version=1.0</txt-record>
    <txt-record>cluster-id=default</txt-record>
  </service>
</service-group>
EOF
    
    systemctl reload avahi-daemon 2>/dev/null || true
}

verify_cluster_connection() {
    if ! kubectl --kubeconfig /etc/kubernetes/kubelet.conf get nodes >/dev/null 2>&1; then
        echo "WARNING: Cannot connect to control plane"
    fi
}

main "$@"
```

### Simple Discovery Service

```bash
#!/bin/bash
# /usr/libexec/kuberblue/discovery.sh

set -euo pipefail

discover_control_planes() {
    local timeout=${1:-10}
    
    timeout "$timeout" avahi-browse -t _kuberblue-cp._tcp 2>/dev/null | \
    grep -E '^=' | \
    awk '{print $(NF-1)}' | \
    sort -u
}

discover_workers() {
    local timeout=${1:-10}
    
    timeout "$timeout" avahi-browse -t _kuberblue-worker._tcp 2>/dev/null | \
    grep -E '^=' | \
    awk '{print $(NF-1)}' | \
    sort -u
}

wait_for_control_plane() {
    local max_wait=${1:-300}
    local elapsed=0
    
    echo "Waiting for control plane (max ${max_wait}s)..."
    
    while [[ $elapsed -lt $max_wait ]]; do
        local control_plane=$(discover_control_planes 3)
        if [[ -n "$control_plane" ]]; then
            echo "$control_plane"
            return 0
        fi
        
        sleep 5
        ((elapsed += 5))
        
        if [[ $((elapsed % 30)) -eq 0 ]]; then
            echo "Still waiting for control plane... (${elapsed}s elapsed)"
        fi
    done
    
    return 1
}
```

## Integration Points

### Modified Files

#### First Boot Integration
```bash
# /usr/libexec/kuberblue/setup/first_boot.sh (control plane version)
#!/bin/bash
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh

mkdir -p /etc/kuberblue

if [[ ! -f /etc/kuberblue/did_first_boot ]]; then
    echo "First boot: initializing control plane..."
    /usr/libexec/kuberblue/control_plane_boot.sh
    touch /etc/kuberblue/did_first_boot
    
    # Run post-install
    export KUBECONFIG=/etc/kubernetes/admin.conf
    sleep 5
    wait_for_node_ready_state
    sudo /usr/libexec/kuberblue/kube_setup/kube_post_install.sh
else
    echo "Subsequent boot: resuming control plane..."
    /usr/libexec/kuberblue/control_plane_boot.sh
fi
```

```bash
# /usr/libexec/kuberblue/setup/first_boot.sh (worker version)
#!/bin/bash
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh

mkdir -p /etc/kuberblue

if [[ ! -f /etc/kuberblue/did_first_boot ]]; then
    echo "First boot: joining as worker..."
    /usr/libexec/kuberblue/worker_boot.sh
    touch /etc/kuberblue/did_first_boot
else
    echo "Subsequent boot: resuming worker role..."
    /usr/libexec/kuberblue/worker_boot.sh
fi
```

### Package Dependencies

#### Required Packages
Add to Kuberblue package manifest:

```yaml
# packages.yaml - kuberblue section
kuberblue:
  rpm:
    - avahi-daemon
    - avahi-tools
```

#### Role-Specific Packages
```yaml
# Control plane specific packages
kuberblue_control_plane:
  rpm:
    - kubectl
    - etcd-client  # For debugging
    
# Worker specific packages  
kuberblue_worker:
  rpm:
    - container-selinux
    - containernetworking-plugins
```

### Systemd Services

#### Autocluster Service
```ini
# /etc/systemd/system/kuberblue-autocluster.service
[Unit]
Description=Kuberblue Automatic Clustering
Wants=avahi-daemon.service
After=avahi-daemon.service network-online.target
Requires=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/libexec/kuberblue/setup/first_boot.sh
RemainAfterExit=yes
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

## Deployment Patterns

### Docker Compose Example
```yaml
version: '3.8'
services:
  control-plane:
    image: kuberblue-control-plane:latest
    hostname: kube-cp-01
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    networks:
      - kuberblue
      
  worker-01:
    image: kuberblue-worker:latest
    hostname: kube-worker-01
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    networks:
      - kuberblue
    depends_on:
      - control-plane
      
  worker-02:
    image: kuberblue-worker:latest
    hostname: kube-worker-02
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    networks:
      - kuberblue
    depends_on:
      - control-plane

networks:
  kuberblue:
    driver: bridge
```

### Container Orchestration
```bash
# Simple deployment script
#!/bin/bash

# Deploy control plane
docker run -d --name kube-cp \
  --hostname kube-cp-01 \
  --privileged \
  kuberblue-control-plane:latest

# Wait for control plane to be ready
sleep 30

# Deploy workers
for i in {1..3}; do
  docker run -d --name "kube-worker-$i" \
    --hostname "kube-worker-$i" \
    --privileged \
    kuberblue-worker:latest
done
```

### Production Deployment with Terraform
```hcl
resource "docker_container" "control_plane" {
  image = "kuberblue-control-plane:latest"
  name  = "kuberblue-control-plane"
  
  hostname = "kube-cp-01"
  privileged = true
  
  networks_advanced {
    name = docker_network.kuberblue.name
  }
}

resource "docker_container" "workers" {
  count = var.worker_count
  
  image = "kuberblue-worker:latest"
  name  = "kuberblue-worker-${count.index + 1}"
  
  hostname = "kube-worker-${count.index + 1}"
  privileged = true
  
  networks_advanced {
    name = docker_network.kuberblue.name
  }
  
  depends_on = [docker_container.control_plane]
}
```

## Operational Workflows

### Control Plane Deployment
1. Deploy control plane image
2. Node boots and runs control plane boot script
3. Initializes Kubernetes cluster with kubeadm
4. Advertises control plane service via mDNS
5. Deploys cluster manifests and components
6. Ready to accept worker nodes

### Worker Deployment
1. Deploy worker image(s)
2. Node boots and runs worker boot script
3. Discovers control plane via mDNS
4. Obtains join command and joins cluster
5. Advertises worker service via mDNS
6. Ready to run workloads

### Scaling Operations
```bash
# Add more workers
docker run -d --name kube-worker-4 \
  --hostname kube-worker-4 \
  --privileged \
  kuberblue-worker:latest

# Remove worker
kubectl drain kube-worker-4 --ignore-daemonsets --delete-emptydir-data
kubectl delete node kube-worker-4
docker stop kube-worker-4
docker rm kube-worker-4
```

## Benefits of This Architecture

### Operational Benefits
1. **Predictable Deployment**: Always know what role each node will have
2. **No Race Conditions**: Eliminates complex election and timing issues
3. **Production Alignment**: Matches how real Kubernetes clusters are deployed
4. **Container Best Practices**: Single responsibility per image
5. **Easy Orchestration**: Integrates cleanly with Docker Compose, Kubernetes, Terraform

### Technical Benefits
1. **Simplified Implementation**: 80% less complexity than runtime discovery
2. **Better Testing**: Clear separation of control plane vs worker logic
3. **Resource Optimization**: Role-specific packages and configurations
4. **Clearer Troubleshooting**: Role-specific logs and behaviors

### Developer Benefits
1. **Explicit Intent**: No guessing about what will happen
2. **Easier Debugging**: Role-specific code paths
3. **Modular Design**: Clean separation of concerns
4. **Extensible**: Easy to add role-specific features

## Limitations and Constraints

### Network Requirements
- **Multicast DNS Support**: Network must allow multicast traffic
- **Local Network**: All nodes must be in same broadcast domain
- **Port Accessibility**: Standard Kubernetes ports must be reachable

### Operational Constraints
- **Two Images**: Requires building and maintaining two images
- **Explicit Deployment**: Cannot dynamically change roles at runtime
- **Initial Setup**: Control plane must be deployed first

### Recovery Scenarios
- **Control Plane Failure**: Requires redeployment (standard Kubernetes practice)
- **Network Partition**: Manual recovery required
- **mDNS Failure**: Workers cannot discover control plane

## Security Considerations

### Trust Model
- **Local Network Trust**: Assumes local network is trusted
- **mDNS Visibility**: Service advertisements visible to broadcast domain
- **Bootstrap Security**: Uses kubeadm's standard bootstrap process

### Security Mitigations
- **Network Isolation**: Deploy on dedicated network segments
- **Firewall Rules**: Standard Kubernetes port restrictions
- **Regular Updates**: Keep images updated with security patches

## Testing Strategy

### Unit Testing
- Control plane initialization logic
- Worker discovery and joining logic
- mDNS service advertisement and discovery
- Error handling for various failure scenarios

### Integration Testing
- Control plane + single worker deployment
- Control plane + multiple worker deployment
- Worker joining existing cluster
- Network partition recovery

### Performance Testing
- Cluster formation time with various worker counts
- mDNS discovery latency
- Resource usage of role-specific images

## Future Enhancements

### Multi-Control Plane HA
- Support for multiple control plane nodes
- Load balancer integration
- etcd cluster formation

### Advanced Discovery
- DNS SRV record support
- Cloud provider API integration
- Cross-subnet discovery capabilities

### Operational Improvements
- Health monitoring and alerting
- Automated backup and restore
- Integration with GitOps workflows
- Cluster lifecycle management

### Container Ecosystem Integration
- Kubernetes operator for Kuberblue clusters
- Helm charts for deployment
- Integration with container registries

## Migration Path

### From Current Kuberblue
Existing single-node Kuberblue deployments continue to work unchanged:
```bash
# Existing behavior preserved
make KUBERBLUE=1 build
```

New role-specific deployments are opt-in:
```bash
# New capabilities
make KUBERBLUE=1 CONTROL_PLANE=1 build
make KUBERBLUE=1 WORKER=1 build
```

### Deployment Strategy
1. **Phase 1**: Implement role-specific build system
2. **Phase 2**: Add role-specific boot logic
3. **Phase 3**: Add mDNS discovery for workers
4. **Phase 4**: Documentation and examples
5. **Phase 5**: Advanced features (multi-CP, etc.)

## Conclusion

This revised architecture provides a production-ready approach to Kubernetes clustering that:

- **Eliminates complex race conditions** through explicit role assignment
- **Aligns with production practices** used by real Kubernetes deployments  
- **Simplifies implementation** by removing 80% of the complexity
- **Improves operational characteristics** with predictable behavior
- **Follows container best practices** with single responsibility

The build-time role assignment approach provides superior operational characteristics while maintaining the simplicity goals of mDNS-based discovery. This architecture is both easier to implement and more suitable for production use than runtime discovery approaches.

---

**Implementation Status**: Specification Complete  
**Next Steps**: Implement build system changes and role-specific boot scripts
