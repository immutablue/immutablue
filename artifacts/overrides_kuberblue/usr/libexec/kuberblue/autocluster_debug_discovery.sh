#!/bin/bash
# Debug mDNS discovery and show raw discovery information

set -euo pipefail

echo "Kuberblue mDNS Discovery Debug"
echo "=============================="

# Check if avahi-daemon is running
if systemctl is-active --quiet avahi-daemon; then
    echo "✓ avahi-daemon is running"
else
    echo "✗ avahi-daemon is NOT running"
    echo "Starting avahi-daemon..."
    systemctl start avahi-daemon
    sleep 2
fi

echo
echo "Raw mDNS Discovery Results:"
echo "---------------------------"

echo "Control Planes (_kuberblue-cp._tcp):"
if timeout 10 avahi-browse -rt _kuberblue-cp._tcp 2>/dev/null; then
    echo "(Raw output above)"
else
    echo "No control planes found or discovery failed"
fi

echo
echo "Workers (_kuberblue-worker._tcp):"
if timeout 10 avahi-browse -rt _kuberblue-worker._tcp 2>/dev/null; then
    echo "(Raw output above)"
else
    echo "No workers found or discovery failed"
fi

echo
echo "Parsed Discovery Results:"
echo "-------------------------"

source /usr/libexec/kuberblue/discovery.sh

echo "Control Plane IPs:"
if control_planes=$(discover_control_planes 5); then
    if [[ -n "$control_planes" ]]; then
        echo "$control_planes"
    else
        echo "None found"
    fi
else
    echo "Discovery failed"
fi

echo
echo "Worker IPs:"  
if workers=$(discover_workers 5); then
    if [[ -n "$workers" ]]; then
        echo "$workers"
    else
        echo "None found"
    fi
else
    echo "Discovery failed"
fi

echo
echo "Current Node Information:"
echo "------------------------"
echo "Hostname: $(hostname)"
echo "IP Addresses:"
ip -4 addr show | grep -E "inet.*scope global" | awk '{print "  " $2}' || echo "  Could not determine IPs"

echo
echo "Kubernetes Configuration Status:"
echo "-------------------------------"
if [[ -f /etc/kubernetes/admin.conf ]]; then
    echo "✓ Control plane config exists"
elif [[ -f /etc/kubernetes/kubelet.conf ]]; then
    echo "✓ Worker config exists"
    echo "Kubelet config server:"
    grep -E "server:" /etc/kubernetes/kubelet.conf 2>/dev/null | awk '{print "  " $2}' || echo "  Could not parse server"
else
    echo "✗ No kubernetes configuration found"
fi

echo
echo "Discovery Cache:"
echo "---------------"
if [[ -f /tmp/kuberblue_discovery_cache ]]; then
    echo "Cache exists, contents:"
    cat /tmp/kuberblue_discovery_cache
else
    echo "No discovery cache found"
fi