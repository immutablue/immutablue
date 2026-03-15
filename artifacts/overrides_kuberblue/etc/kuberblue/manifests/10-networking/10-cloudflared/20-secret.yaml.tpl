# Cloudflare Tunnel Token Secret Template
#
# Fill in your tunnel token and apply:
#   1. Replace <YOUR_TUNNEL_TOKEN> with the token from `cloudflared tunnel create`
#   2. kubectl apply -f <this-file>
#
# For SOPS-encrypted secrets, save as 20-secret.sops.yaml and encrypt:
#   sops --encrypt --age <AGE_RECIPIENT> 20-secret.yaml > 20-secret.sops.yaml

apiVersion: v1
kind: Secret
metadata:
  name: cloudflared-tunnel-token
  namespace: cloudflared
type: Opaque
stringData:
  tunnel-token: "<YOUR_TUNNEL_TOKEN>"
