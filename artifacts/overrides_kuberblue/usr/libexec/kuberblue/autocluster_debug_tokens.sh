#!/bin/bash
# Debug bootstrap tokens and CA cert hashes

set -euo pipefail

echo "Kuberblue Token and Certificate Debug"
echo "===================================="

# Check if this is a control plane
if [[ -f /etc/kubernetes/admin.conf ]]; then
    echo "Control Plane Token Information:"
    echo "-------------------------------"
    
    export KUBECONFIG=/etc/kubernetes/admin.conf
    
    echo "Available bootstrap tokens:"
    kubectl get secrets -n kube-system -o name | grep bootstrap-token || echo "No bootstrap tokens found"
    
    echo
    echo "Bootstrap token details:"
    kubectl get secrets -n kube-system -l bootstrap.kubernetes.io/token-id -o custom-columns=NAME:.metadata.name,TOKEN-ID:.data.token-id,EXPIRY:.metadata.labels.'bootstrap\.kubernetes\.io/expires' 2>/dev/null || echo "Could not get token details"
    
    echo
    echo "Current CA certificate hash:"
    openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* /sha256:/'
    
    echo
    echo "Creating fresh bootstrap token for worker joining:"
    if kubectl get nodes >/dev/null 2>&1; then
        # Create a new token valid for 1 hour
        token_output=$(kubeadm token create --ttl 1h --print-join-command 2>/dev/null || echo "Failed to create token")
        echo "$token_output"
        
        if [[ "$token_output" != *"Failed"* ]]; then
            # Extract token and hash from join command
            new_token=$(echo "$token_output" | grep -o 'token [^ ]*' | cut -d' ' -f2)
            new_hash=$(echo "$token_output" | grep -o 'sha256:[^ ]*')
            echo
            echo "New token: $new_token"
            echo "CA cert hash: $new_hash"
        fi
    else
        echo "Control plane not ready to create tokens"
    fi
    
else
    echo "This is not a control plane node"
fi

echo
echo "mDNS Advertised Information:"
echo "---------------------------"

if [[ -f /tmp/kuberblue_discovery_cache ]]; then
    echo "Cached mDNS discovery data:"
    cat /tmp/kuberblue_discovery_cache
    echo
    
    echo "Extracted token from mDNS:"
    grep "txt = " /tmp/kuberblue_discovery_cache | sed -n 's/.*"token=\([^"]*\)".*/\1/p' | head -1 || echo "No token found"
    
    echo "Extracted CA cert hash from mDNS:"
    grep "txt = " /tmp/kuberblue_discovery_cache | sed -n 's/.*"ca-cert-hash=\([^"]*\)".*/\1/p' | head -1 || echo "No CA cert hash found"
else
    echo "No cached discovery data found"
    echo "Running fresh discovery..."
    timeout 10 avahi-browse -rt _kuberblue-cp._tcp 2>/dev/null || echo "No control plane found via mDNS"
fi

echo
echo "Recommendations:"
echo "---------------"
echo "If tokens don't match:"
echo "  1. On control plane: Update mDNS advertisement with fresh tokens"
echo "  2. On worker: Clear discovery cache and retry join"
echo "  3. Check if bootstrap tokens have expired"