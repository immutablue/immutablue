#cloud-config
# kuberblue cloud-init user-data template
#
# This file is a TEMPLATE — fill in the values and use it as cloud-init
# user-data when launching a kuberblue VM or bare metal install.
#
# Usage:
#   VM (libvirt):    virt-install --cloud-init user-data=this-file.yaml
#   VM (Lima):       Embed in Lima YAML under provision: section
#   Cloud provider:  Paste into user-data field
#   NoCloud ISO:     mkisofs -output seed.iso -volid cidata -joliet -rock user-data meta-data
#
# All kuberblue.* values are read by config_fetch.sh at first boot.

# --- kuberblue configuration ---
kuberblue:
  # Git repository URL containing cluster configuration (required)
  config: ""  # e.g. https://github.com/org/kuberblue-configs

  # Git branch or tag (default: main)
  config_ref: "main"

  # Subdirectory within repo for this cluster's config
  config_path: "."  # e.g. clusters/my-homelab

  # Deploy token for private repos (leave empty for public)
  config_token: ""

  # SOPS Age private key (leave empty if not using SOPS)
  age_key: ""

# --- Optional: run commands after cloud-init ---
# runcmd:
#   - echo "kuberblue cloud-init complete"
