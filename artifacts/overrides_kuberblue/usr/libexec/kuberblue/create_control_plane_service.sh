#!/bin/bash
set -euo pipefail

# Ensure avahi-daemon is running before advertising
if ! systemctl is-active --quiet avahi-daemon; then
    echo "Starting avahi-daemon service..."
    systemctl start avahi-daemon
    sleep 2  # Wait for service to be ready
fi

# Extract bootstrap token and CA cert hash from kubeadm init output
bootstrap_token=""
ca_cert_hash=""

if [[ -f /etc/kuberblue/kubeadm_init_result.log ]]; then
    # Parse the join command from kubeadm output
    join_line=$(grep -A 2 "kubeadm join" /etc/kuberblue/kubeadm_init_result.log | tr -d '\n\134')
    
    if [[ -n "$join_line" ]]; then
        bootstrap_token=$(echo "$join_line" | sed -n 's/.*--token \([a-z0-9]*\.[a-z0-9]*\).*/\1/p')
        ca_cert_hash=$(echo "$join_line" | sed -n 's/.*--discovery-token-ca-cert-hash \(sha256:[a-f0-9]*\).*/\1/p')
    fi
fi

# Always generate fresh token to ensure it's not expired
echo "Generating fresh bootstrap token..."
bootstrap_token=$(kubeadm token create)
ca_cert_hash=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* /sha256:/')

cat > /etc/avahi/services/kuberblue-control-plane.service << EOF
<service-group>
  <name replace-wildcards="yes">Kuberblue Control Plane on %h</name>
  <service>
    <type>_kuberblue-cp._tcp</type>
    <port>6443</port>
    <txt-record>version=1.0</txt-record>
    <txt-record>cluster-id=default</txt-record>
    <txt-record>ready=true</txt-record>
    <txt-record>token=$bootstrap_token</txt-record>
    <txt-record>ca-cert-hash=$ca_cert_hash</txt-record>
  </service>
</service-group>
EOF

echo "Advertising bootstrap token: $bootstrap_token"
echo "Advertising CA cert hash: $ca_cert_hash"

systemctl reload avahi-daemon 2>/dev/null || true