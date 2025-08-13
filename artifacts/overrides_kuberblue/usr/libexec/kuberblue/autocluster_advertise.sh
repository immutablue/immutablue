#!/bin/bash
# Manually create mDNS advertisements for control plane or worker

set -euo pipefail

service_type="${1:-auto}"

case "$service_type" in
    "control-plane"|"cp")
        echo "[INFO] Creating control plane mDNS advertisement..."
        
        if ! systemctl is-active --quiet avahi-daemon; then
            echo "[INFO] Starting avahi-daemon..."
            systemctl start avahi-daemon
            sleep 2
        fi
        
        /usr/libexec/kuberblue/create_control_plane_service.sh
        echo "[SUCCESS] Control plane advertisement created"
        ;;
        
    "worker")
        echo "[INFO] Creating worker mDNS advertisement..."
        
        if ! systemctl is-active --quiet avahi-daemon; then
            echo "[INFO] Starting avahi-daemon..."
            systemctl start avahi-daemon
            sleep 2
        fi
        
        cat > /etc/avahi/services/kuberblue-worker.service << 'EOF'
<service-group>
  <name replace-wildcards="yes">Kuberblue Worker on %h</name>
  <service>
    <type>_kuberblue-worker._tcp</type>
    <port>10250</port>
    <txt-record>version=1.0</txt-record>
    <txt-record>cluster-id=default</txt-record>
    <txt-record>hostname=%h</txt-record>
  </service>
</service-group>
EOF
        
        systemctl reload avahi-daemon
        echo "[SUCCESS] Worker advertisement created"
        ;;
        
    "auto")
        echo "[INFO] Auto-detecting role and creating appropriate advertisement..."
        
        if [[ -f /etc/kubernetes/admin.conf ]]; then
            echo "[INFO] Control plane detected, creating control plane advertisement"
            $0 control-plane
        elif [[ -f /etc/kubernetes/kubelet.conf ]]; then
            echo "[INFO] Worker detected, creating worker advertisement"
            $0 worker
        else
            echo "[ERROR] Could not detect role - no kubernetes config found"
            echo "Manually specify: $0 [control-plane|worker]"
            exit 1
        fi
        ;;
        
    *)
        echo "Usage: $0 [auto|control-plane|worker]"
        echo "  auto (default): Auto-detect role and advertise appropriately"
        echo "  control-plane: Create control plane mDNS advertisement"
        echo "  worker: Create worker mDNS advertisement"
        exit 1
        ;;
esac