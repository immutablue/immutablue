#!/bin/bash
# /usr/libexec/kuberblue/worker_boot.sh

set -euo pipefail

# Parse debug flag
KUBEADM_VERBOSITY=""
while getopts "x" opt; do
    case $opt in
        x) 
            set -x
            KUBEADM_VERBOSITY="--v=5"
            ;;
        *) echo "Usage: $0 [-x]"; exit 1 ;;
    esac
done

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
    # Ensure avahi-daemon is running before discovery
    if ! systemctl is-active --quiet avahi-daemon; then
        echo "Starting avahi-daemon service..."
        systemctl start avahi-daemon
        # Wait for avahi to be properly ready
        local wait_count=0
        while ! systemctl is-active --quiet avahi-daemon && [[ $wait_count -lt 10 ]]; do
            sleep 1
            ((wait_count++))
        done
        sleep 2  # Additional settle time
    fi
    
    echo "Discovering control plane..."
    
    local control_plane_ip
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        control_plane_ip=$(discover_control_plane)
        
        if [[ -n "$control_plane_ip" ]]; then
            echo "Found control plane at: $control_plane_ip"
            if join_cluster "$control_plane_ip"; then
                echo "Successfully joined cluster"
                create_worker_service
                return
            else
                echo "Failed to join cluster, clearing discovery cache and retrying..."
                rm -f /tmp/kuberblue_discovery_cache
            fi
        fi
        
        echo "No control plane found, attempt $attempt/$max_attempts, retrying in 10s..."
        sleep 10
        ((attempt++))
    done
    
    echo "ERROR: Could not find control plane after $max_attempts attempts"
    exit 1
}

discover_control_plane() {
    # Use avahi-browse to find control plane and extract connection info
    local avahi_output
    avahi_output=$(timeout 10 avahi-browse -rt _kuberblue-cp._tcp 2>/dev/null)
    
    if [[ -z "$avahi_output" ]]; then
        return 1
    fi
    
    # Extract IP address - filter for IPv4 only (kubeadm doesn't handle IPv6 well)
    local control_plane_ip
    control_plane_ip=$(echo "$avahi_output" | grep "address = \[" | sed 's/.*address = \[\(.*\)\].*/\1/' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
    
    if [[ -n "$control_plane_ip" ]]; then
        # Store the full avahi output for token extraction
        echo "$avahi_output" > /tmp/kuberblue_discovery_cache
        echo "$control_plane_ip"
        return 0
    fi
    
    return 1
}

join_cluster() {
    local control_plane_ip=$1
    
    echo "Joining cluster at $control_plane_ip..."
    
    # Get bootstrap token from control plane API
    local join_command
    if ! join_command=$(get_join_command "$control_plane_ip"); then
        echo "ERROR: Could not get join command"
        return 1
    fi
    
    if [[ -z "$join_command" ]]; then
        echo "ERROR: Join command is empty"
        return 1
    fi
    
    # Execute join command and return its exit code
    echo "Executing: $join_command"
    if eval "$join_command"; then
        echo "kubeadm join completed successfully"
        return 0
    else
        local exit_code=$?
        echo "kubeadm join failed with exit code $exit_code"
        
        # If token error, clear cache and suggest retry
        if [[ $exit_code -eq 1 ]]; then
            echo "Clearing discovery cache due to potential token issues..."
            rm -f /tmp/kuberblue_discovery_cache
            echo "This may be due to expired token - control plane should generate fresh tokens"
        fi
        
        echo "Check kubelet logs: journalctl -u kubelet --no-pager -l"
        echo "Check kubeadm logs in /var/log/ or use --v=5 for verbose output"
        return 1
    fi
}

get_join_command() {
    local control_plane_ip=$1
    
    # Get the CA cert hash and bootstrap token from mDNS TXT records
    local ca_cert_hash bootstrap_token
    
    if ! ca_cert_hash=$(get_ca_cert_hash); then
        echo "ERROR: Could not get CA cert hash from mDNS"
        return 1
    fi
    
    if ! bootstrap_token=$(get_bootstrap_token); then
        echo "ERROR: Could not get bootstrap token from mDNS"
        return 1
    fi
    
    # Validate required components
    if [[ -z "$control_plane_ip" || -z "$bootstrap_token" || -z "$ca_cert_hash" ]]; then
        echo "ERROR: Missing required join parameters (ip=$control_plane_ip, token=$bootstrap_token, hash=$ca_cert_hash)"
        return 1
    fi
    
    echo "sudo kubeadm join $control_plane_ip:6443 --token '$bootstrap_token' --discovery-token-ca-cert-hash '$ca_cert_hash' --node-name $(hostname) $KUBEADM_VERBOSITY"
}

get_ca_cert_hash() {
    # Extract CA cert hash from cached mDNS TXT records
    # avahi-browse format: txt = ["key=value" "key=value"]  
    if [[ -f /tmp/kuberblue_discovery_cache ]]; then
        local ca_cert_hash
        ca_cert_hash=$(grep "txt = " /tmp/kuberblue_discovery_cache | sed -n 's/.*"ca-cert-hash=\([^"]*\)".*/\1/p' | head -1)
        
        if [[ -n "$ca_cert_hash" ]]; then
            echo "$ca_cert_hash"
            return 0
        fi
    fi
    
    echo "ERROR: Could not extract CA cert hash from mDNS"
    return 1
}

get_bootstrap_token() {
    # Extract bootstrap token from cached mDNS TXT records
    # avahi-browse format: txt = ["key=value" "key=value"]
    if [[ -f /tmp/kuberblue_discovery_cache ]]; then
        local bootstrap_token
        bootstrap_token=$(grep "txt = " /tmp/kuberblue_discovery_cache | sed -n 's/.*"token=\([^"]*\)".*/\1/p' | head -1)
        
        if [[ -n "$bootstrap_token" ]]; then
            echo "$bootstrap_token"
            return 0
        fi
    fi
    
    echo "ERROR: Could not extract bootstrap token from mDNS"
    return 1
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