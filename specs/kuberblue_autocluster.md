# Kuberblue Autocluster Specification

## Executive Summary

### Problem Statement
Kuberblue currently requires manual cluster setup, including explicit configuration of control plane endpoints and manual execution of `kubeadm join` commands. This creates operational overhead and potential for configuration errors in production deployments.

### Solution Overview
Implement mDNS-based automatic node discovery and cluster formation that allows Kuberblue nodes to automatically discover each other on the local network and form Kubernetes clusters without manual intervention.

### Key Benefits
- **Zero Configuration**: Nodes automatically discover and join clusters
- **Production Ready**: Handles race conditions and maintains state across reboots
- **Simple Implementation**: Uses proven mDNS technology with minimal dependencies
- **Local Network Focused**: Optimized for data center and edge deployments

## Architecture Overview

### Core Components

1. **mDNS Service Advertisement**: Nodes advertise their role using Avahi services
2. **Discovery Engine**: Automatic detection of existing cluster nodes
3. **Cluster Formation Logic**: Intelligent role assignment and joining decisions
4. **State Persistence**: Maintain cluster role across reboots
5. **Race Condition Prevention**: Handle simultaneous node startup scenarios

### Technology Stack
- **Service Discovery**: mDNS via Avahi daemon
- **Network Protocol**: Standard multicast DNS (port 5353)
- **State Management**: File-based persistence with Kubernetes integration
- **Clustering**: Standard kubeadm bootstrap process

## Technical Design

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
    <txt-record>bootstrap-available=true</txt-record>
  </service>
</service-group>
```

#### Worker Node Service
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

#### Candidate Node Service (Temporary)
```xml
# /etc/avahi/services/kuberblue-candidate.service
<service-group>
  <name replace-wildcards="yes">Kuberblue Candidate on %h</name>
  <service>
    <type>_kuberblue-candidate._tcp</type>
    <port>0</port>
    <txt-record>hostname=%h</txt-record>
    <txt-record>priority=auto</txt-record>
  </service>
</service-group>
```

### Discovery and Clustering Logic

#### Main Discovery Flow
```bash
#!/bin/bash
# /usr/libexec/kuberblue/cluster_manager.sh

set -euo pipefail
source /usr/libexec/kuberblue/99-common.sh

STATE_FILE="/etc/kuberblue/cluster.conf"
CANDIDATE_TIMEOUT=30
DISCOVERY_TIMEOUT=10

main() {
    local state_info=$(determine_node_state)
    local state_source=$(echo "$state_info" | cut -d':' -f1)
    local role=$(echo "$state_info" | cut -d':' -f2)
    
    case "$state_source:$role" in
        "state-file:control-plane"|"kubernetes:control-plane")
            resume_control_plane
            ;;
        "state-file:worker"|"kubernetes:worker")
            resume_worker
            ;;
        "first-boot:unknown")
            discover_and_join
            ;;
        *)
            echo "ERROR: Unknown state $state_info"
            exit 1
            ;;
    esac
}

discover_and_join() {
    echo "Starting cluster discovery and join process..."
    
    # Initial check for existing control planes
    local control_planes=$(discover_control_planes)
    if [[ -n "$control_planes" ]]; then
        echo "Found existing control plane: $control_planes"
        join_as_worker "$control_planes"
        return
    fi
    
    # No control plane found - enter candidate election
    echo "No control plane found, entering election process..."
    candidate_election
}

candidate_election() {
    # Advertise as candidate
    create_candidate_service
    
    # Wait for other potential candidates
    local wait_time=$((RANDOM % 20 + 10))  # 10-30 seconds
    echo "Waiting ${wait_time}s for other candidates..."
    sleep "$wait_time"
    
    # Check for control planes that may have appeared
    local control_planes=$(discover_control_planes)
    if [[ -n "$control_planes" ]]; then
        echo "Control plane appeared during candidate phase, joining..."
        remove_candidate_service
        join_as_worker "$control_planes"
        return
    fi
    
    # Discover other candidates
    local candidates=$(discover_candidates)
    local my_hostname=$(hostname)
    
    if [[ -z "$candidates" ]]; then
        # Only candidate, become control plane
        echo "No other candidates found, becoming control plane"
        remove_candidate_service
        become_control_plane
    else
        # Multiple candidates, elect leader
        local winner=$(echo -e "${candidates}\n${my_hostname}" | sort | head -1)
        
        if [[ "$winner" == "$my_hostname" ]]; then
            echo "Elected as control plane (lowest hostname: $winner)"
            remove_candidate_service
            become_control_plane
        else
            echo "Waiting for $winner to become control plane"
            remove_candidate_service
            wait_for_control_plane
        fi
    fi
}

discover_control_planes() {
    timeout $DISCOVERY_TIMEOUT avahi-browse -t _kuberblue-cp._tcp 2>/dev/null | \
    grep -E '^=' | \
    awk '{print $(NF-1)}' | \
    head -1
}

discover_candidates() {
    timeout $DISCOVERY_TIMEOUT avahi-browse -t _kuberblue-candidate._tcp 2>/dev/null | \
    grep -E '^=' | \
    awk '{print $(NF-2)}' | \
    grep -v "$(hostname)" | \
    sort -u
}

wait_for_control_plane() {
    echo "Waiting up to ${CANDIDATE_TIMEOUT}s for control plane to initialize..."
    local end_time=$(($(date +%s) + CANDIDATE_TIMEOUT))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local control_planes=$(discover_control_planes)
        if [[ -n "$control_planes" ]]; then
            echo "Control plane ready: $control_planes"
            join_as_worker "$control_planes"
            return
        fi
        sleep 2
    done
    
    echo "ERROR: Timeout waiting for control plane, manual intervention required"
    exit 1
}
```

#### State Management Functions
```bash
determine_node_state() {
    # Method 1: Check explicit state file
    if [[ -f "$STATE_FILE" ]] && source "$STATE_FILE" 2>/dev/null; then
        if [[ -n "${NODE_ROLE:-}" ]]; then
            echo "state-file:$NODE_ROLE"
            return
        fi
    fi
    
    # Method 2: Detect from Kubernetes files
    if [[ -f /etc/kubernetes/admin.conf ]]; then
        echo "kubernetes:control-plane"
        return
    elif [[ -f /etc/kubernetes/kubelet.conf ]]; then
        echo "kubernetes:worker"
        return
    fi
    
    # Method 3: First boot
    echo "first-boot:unknown"
}

save_state() {
    local role=$1
    local control_plane_ip=${2:-}
    
    cat > "$STATE_FILE" << EOF
# Kuberblue cluster state
# Generated on $(date)
CLUSTER_ID=${CLUSTER_ID:-default}
NODE_ROLE=${role}
CLUSTER_INITIALIZED=$(date -Iseconds)
CONTROL_PLANE_IP=${control_plane_ip}
LAST_UPDATE=$(date -Iseconds)
EOF
    
    echo "State saved: role=$role"
}

become_control_plane() {
    echo "Initializing as control plane node..."
    
    # Create control plane service
    create_control_plane_service
    
    # Initialize Kubernetes cluster
    if ! sudo kubeadm init --config /etc/kuberblue/kubeadm.yaml; then
        echo "ERROR: Failed to initialize Kubernetes cluster"
        exit 1
    fi
    
    # Save state
    local my_ip=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
    save_state "control-plane" "$my_ip"
    
    # Setup kubectl for kuberblue user
    setup_kubectl_access
    
    # Deploy cluster components
    deploy_cluster_manifests
    
    echo "Control plane initialization complete"
}

join_as_worker() {
    local control_plane_ip=$1
    
    echo "Joining cluster as worker node (control plane: $control_plane_ip)"
    
    # Create worker service
    create_worker_service
    
    # Get bootstrap token
    local join_token=$(get_bootstrap_token "$control_plane_ip")
    if [[ -z "$join_token" ]]; then
        echo "ERROR: Could not obtain bootstrap token"
        exit 1
    fi
    
    # Join cluster
    if ! sudo kubeadm join "${control_plane_ip}:6443" --token "$join_token" --discovery-token-unsafe-skip-ca-verification; then
        echo "ERROR: Failed to join cluster"
        exit 1
    fi
    
    # Save state
    save_state "worker" "$control_plane_ip"
    
    echo "Worker join complete"
}

resume_control_plane() {
    echo "Resuming as control plane node..."
    
    # Ensure service is advertised
    create_control_plane_service
    
    # Wait for Kubernetes API to be ready
    wait_for_kubernetes_api
    
    # Verify cluster health
    if ! kubectl get nodes >/dev/null 2>&1; then
        echo "WARNING: Cluster appears unhealthy"
    fi
    
    echo "Control plane resume complete"
}

resume_worker() {
    echo "Resuming as worker node..."
    
    # Ensure service is advertised
    create_worker_service
    
    # Verify connection to control plane
    if ! kubectl --kubeconfig /etc/kubernetes/kubelet.conf get nodes >/dev/null 2>&1; then
        echo "WARNING: Cannot connect to control plane"
    fi
    
    echo "Worker resume complete"
}
```

### Service Management

#### Avahi Service Management
```bash
#!/bin/bash
# /usr/libexec/kuberblue/service_manager.sh

set -euo pipefail

AVAHI_SERVICES_DIR="/etc/avahi/services"

create_control_plane_service() {
    local service_file="$AVAHI_SERVICES_DIR/kuberblue-control-plane.service"
    
    cat > "$service_file" << 'EOF'
<service-group>
  <name replace-wildcards="yes">Kuberblue Control Plane on %h</name>
  <service>
    <type>_kuberblue-cp._tcp</type>
    <port>6443</port>
    <txt-record>version=1.0</txt-record>
    <txt-record>cluster-id=default</txt-record>
    <txt-record>bootstrap-available=true</txt-record>
  </service>
</service-group>
EOF
    
    # Remove other role services
    rm -f "$AVAHI_SERVICES_DIR/kuberblue-worker.service"
    rm -f "$AVAHI_SERVICES_DIR/kuberblue-candidate.service"
    
    reload_avahi
    echo "Control plane service created"
}

create_worker_service() {
    local service_file="$AVAHI_SERVICES_DIR/kuberblue-worker.service"
    
    cat > "$service_file" << 'EOF'
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
    
    # Remove other role services
    rm -f "$AVAHI_SERVICES_DIR/kuberblue-control-plane.service"
    rm -f "$AVAHI_SERVICES_DIR/kuberblue-candidate.service"
    
    reload_avahi
    echo "Worker service created"
}

create_candidate_service() {
    local service_file="$AVAHI_SERVICES_DIR/kuberblue-candidate.service"
    
    cat > "$service_file" << EOF
<service-group>
  <name replace-wildcards="yes">Kuberblue Candidate on %h</name>
  <service>
    <type>_kuberblue-candidate._tcp</type>
    <port>0</port>
    <txt-record>hostname=$(hostname)</txt-record>
    <txt-record>priority=auto</txt-record>
  </service>
</service-group>
EOF
    
    reload_avahi
    echo "Candidate service created"
}

remove_candidate_service() {
    rm -f "$AVAHI_SERVICES_DIR/kuberblue-candidate.service"
    reload_avahi
    echo "Candidate service removed"
}

reload_avahi() {
    if systemctl is-active --quiet avahi-daemon; then
        systemctl reload avahi-daemon
    else
        echo "WARNING: avahi-daemon is not running"
    fi
}
```

### Bootstrap Token Management

```bash
#!/bin/bash
# /usr/libexec/kuberblue/bootstrap.sh

get_bootstrap_token() {
    local control_plane_ip=$1
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        echo "Attempting to get bootstrap token from $control_plane_ip (attempt $attempt)"
        
        # Try to get existing token
        local token=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            "kuberblue@$control_plane_ip" \
            "sudo kubeadm token list | grep 'authentication,signing' | head -1 | awk '{print \$1}'" 2>/dev/null)
        
        if [[ -n "$token" ]]; then
            echo "$token"
            return 0
        fi
        
        # Try to create new token
        token=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            "kuberblue@$control_plane_ip" \
            "sudo kubeadm token create --ttl 1h" 2>/dev/null)
        
        if [[ -n "$token" ]]; then
            echo "$token"
            return 0
        fi
        
        echo "Failed to get token, retrying in 5 seconds..."
        sleep 5
        ((attempt++))
    done
    
    echo "ERROR: Could not obtain bootstrap token after $max_attempts attempts"
    return 1
}

setup_kubectl_access() {
    local kuberblue_home="/home/kuberblue"
    
    # Create .kube directory
    mkdir -p "$kuberblue_home/.kube"
    
    # Copy admin config
    cp /etc/kubernetes/admin.conf "$kuberblue_home/.kube/config"
    chown kuberblue:kuberblue "$kuberblue_home/.kube/config"
    
    echo "kubectl access configured for kuberblue user"
}

wait_for_kubernetes_api() {
    local max_wait=300  # 5 minutes
    local elapsed=0
    
    echo "Waiting for Kubernetes API to be ready..."
    
    while [[ $elapsed -lt $max_wait ]]; do
        if kubectl get nodes >/dev/null 2>&1; then
            echo "Kubernetes API is ready"
            return 0
        fi
        
        sleep 5
        ((elapsed += 5))
    done
    
    echo "ERROR: Kubernetes API not ready after ${max_wait}s"
    return 1
}

deploy_cluster_manifests() {
    echo "Deploying cluster manifests..."
    
    # Wait for node to be ready
    while ! kubectl get nodes | grep -q Ready; do
        echo "Waiting for node to be ready..."
        sleep 5
    done
    
    # Deploy manifests using existing deployment script
    if [[ -x /usr/libexec/kuberblue/kube_setup/kube_deploy.sh ]]; then
        /usr/libexec/kuberblue/kube_setup/kube_deploy.sh
    else
        echo "WARNING: Deployment script not found, manual manifest deployment required"
    fi
}
```

## State Persistence

### State File Format
```bash
# /etc/kuberblue/cluster.conf
# Kuberblue cluster state
# Generated on 2025-01-12T10:30:00-05:00
CLUSTER_ID=default
NODE_ROLE=control-plane
CLUSTER_INITIALIZED=2025-01-12T10:30:00-05:00
CONTROL_PLANE_IP=192.168.1.10
LAST_UPDATE=2025-01-12T10:30:00-05:00
```

### State Recovery Logic
The system provides multiple methods for determining node state:

1. **Primary**: Explicit state file (`/etc/kuberblue/cluster.conf`)
2. **Fallback**: Kubernetes configuration files (admin.conf, kubelet.conf)
3. **Default**: First boot discovery process

## Integration Points

### Modified Files

#### first_boot.sh Integration
```bash
#!/bin/bash
# /usr/libexec/kuberblue/setup/first_boot.sh
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh

mkdir -p /etc/kuberblue

# Check if this is truly first boot or a reboot
if [[ ! -f /etc/kuberblue/did_first_boot ]]; then
    # First boot - run autocluster
    echo "First boot detected, starting autocluster process..."
    /usr/libexec/kuberblue/cluster_manager.sh
    
    # Mark first boot complete
    touch /etc/kuberblue/did_first_boot
    
    # Run post-install if we became control plane
    if [[ -f /etc/kuberblue/cluster.conf ]]; then
        source /etc/kuberblue/cluster.conf
        if [[ "$NODE_ROLE" == "control-plane" ]]; then
            export KUBECONFIG=/etc/kubernetes/admin.conf
            sleep 5
            wait_for_node_ready_state
            sudo /usr/libexec/kuberblue/kube_setup/kube_post_install.sh
        fi
    fi
else
    # Subsequent boot - resume role
    echo "Subsequent boot detected, resuming cluster role..."
    /usr/libexec/kuberblue/cluster_manager.sh
fi
```

### Systemd Service

#### Autocluster Service
```ini
# /etc/systemd/system/kuberblue-autocluster.service
[Unit]
Description=Kuberblue Automatic Cluster Management
Wants=avahi-daemon.service
After=avahi-daemon.service network-online.target
Requires=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/libexec/kuberblue/cluster_manager.sh
RemainAfterExit=yes
User=root
StandardOutput=journal
StandardError=journal

# Restart on failure with exponential backoff
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
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
    - openssh-clients  # For bootstrap token retrieval
```

## Operational Workflows

### First Boot Scenarios

#### Single Node Startup
```
1. Node boots with clean state
2. Runs discovery, finds no control planes
3. Waits random interval (10-30s) for race condition avoidance
4. Still no control planes, initializes as control plane
5. Advertises control plane service via mDNS
6. Deploys cluster manifests
7. Saves state file
```

#### Multiple Node Simultaneous Startup
```
1. Multiple nodes boot simultaneously
2. All run discovery, find no control planes
3. All enter candidate election phase
4. Each waits random interval + advertises as candidate
5. Hostname-based election determines winner
6. Winner becomes control plane, others wait
7. Workers join control plane when ready
8. All save appropriate state
```

#### Joining Existing Cluster
```
1. Node boots and runs discovery
2. Finds existing control plane via mDNS
3. Obtains bootstrap token from control plane
4. Joins cluster as worker node
5. Advertises worker service via mDNS
6. Saves worker state
```

### Reboot Scenarios

#### Control Plane Reboot
```
1. Node reboots, loads state file
2. Detects previous role as control plane
3. Re-advertises control plane service
4. Waits for Kubernetes API to be ready
5. Verifies cluster health
6. Resumes normal operation
```

#### Worker Node Reboot
```
1. Node reboots, loads state file
2. Detects previous role as worker
3. Re-advertises worker service
4. Verifies connection to control plane
5. Resumes normal operation
```

## Security Considerations

### Trust Model
- **Local Network Trust**: Assumes local network is trusted
- **mDNS Visibility**: Service advertisements visible to entire broadcast domain
- **Bootstrap Token Security**: Tokens have limited lifetime (1 hour default)

### Security Mitigations
- **Token Rotation**: Automatic bootstrap token rotation
- **CA Verification**: Bootstrap process includes CA certificate hash verification
- **Network Isolation**: Recommend VLAN isolation for production clusters
- **Firewall Rules**: Standard Kubernetes port restrictions apply

### Known Limitations
- **No Cross-Network Discovery**: Limited to single broadcast domain
- **Plaintext Service Advertisements**: mDNS broadcasts are not encrypted
- **No Authentication**: Initial discovery phase has no authentication

## Limitations and Constraints

### Network Requirements
- **Multicast DNS Support**: Network must allow multicast traffic
- **Port Requirements**: Standard Kubernetes ports (6443, 10250, etc.)
- **Broadcast Domain**: All nodes must be in same broadcast domain

### Operational Constraints
- **Single Cluster per Network**: Cannot distinguish between multiple clusters
- **Initial Single Control Plane**: No built-in HA control plane support initially
- **Local Network Only**: Cannot span multiple sites/networks

### Recovery Scenarios
- **State File Corruption**: Falls back to Kubernetes config detection
- **mDNS Failure**: Requires manual intervention
- **Split Network**: Manual recovery required

## Testing Strategy

### Unit Testing
```bash
# Test discovery functions
test_discover_control_planes() {
    # Mock avahi-browse output
    # Verify correct IP extraction
}

test_candidate_election() {
    # Mock multiple candidates
    # Verify correct winner selection
}

test_state_management() {
    # Test state file creation/loading
    # Verify state persistence
}
```

### Integration Testing
- **Multi-node cluster formation**: 3-5 node simultaneous startup
- **Race condition handling**: Stress test with rapid node addition
- **Reboot resilience**: Verify state persistence across reboots
- **Network partition recovery**: Test behavior with temporary network issues

### Failure Scenario Testing
- **Control plane failure**: Worker behavior when control plane dies
- **State corruption**: Recovery from corrupted state files
- **mDNS unavailable**: Behavior when Avahi daemon fails
- **Network isolation**: Partial network connectivity scenarios

## Future Enhancements

### Multi-Control Plane HA
- Extend candidate election to support multiple control planes
- etcd cluster formation logic
- Load balancer integration for control plane access

### Cross-Subnet Discovery
- DNS SRV record support
- Static discovery file integration
- Cloud provider API integration

### Advanced Security
- Certificate-based node authentication
- Encrypted service advertisements
- Integration with external PKI systems

### Operational Improvements
- Health monitoring and alerting
- Cluster state visualization
- Automated backup and restore
- Integration with GitOps workflows

## Conclusion

This specification provides a comprehensive design for automatic Kubernetes clustering in Kuberblue using mDNS technology. The solution balances simplicity with production requirements, providing zero-configuration clustering while handling edge cases like race conditions and reboot persistence.

The implementation leverages proven technologies (mDNS, Avahi) and follows Kubernetes best practices for bootstrap and cluster formation. The design is extensible to support future enhancements while maintaining backward compatibility.

---

**Implementation Status**: Specification Complete  
**Next Steps**: Begin implementation of core scripts and integration testing
