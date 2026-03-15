# First-Boot Marker Bug Fix

**Priority:** CRITICAL
**File:** `artifacts/overrides_kuberblue/usr/libexec/kuberblue/setup/first_boot.sh`
**Status:** Documented for Phase 3 merge (Phase 3 is modifying the same file)

## The Bug

The first-boot marker (`/etc/kuberblue/did_first_boot`) is written BEFORE
post-install steps complete on the control-plane path. If any of the following
fail, the node thinks it already completed first boot and will not retry on
next reboot:

- `kube_post_install.sh` (core manifest deployment)
- `kube_sops_setup.sh` (SOPS+Age key setup)
- `kube_flux_bootstrap.sh` (Flux CD bootstrap)
- Worker join token generation

## Current Code (broken)

```bash
# Line ~42 in first_boot.sh — control-plane path
kuberblue_state_set "cluster-initialized" "true"

touch "${FIRST_BOOT_MARKER}"        # <-- BUG: written here, BEFORE post-install
export KUBECONFIG=/etc/kubernetes/admin.conf

# ... wait_for_node_ready_state ...
# ... kube_post_install.sh ...       # <-- if this fails, marker already exists
# ... kube_sops_setup.sh ...
# ... kube_flux_bootstrap.sh ...
```

## Fix

Move `touch "${FIRST_BOOT_MARKER}"` to the END of the entire flow, after ALL
steps succeed. The marker should be the very last thing written.

### Control-plane path fix:

```bash
# Remove the early marker write (line ~42):
# - touch "${FIRST_BOOT_MARKER}"

# Add at the very end of the control-plane block (after join token generation):
    fi

    # Mark first boot complete ONLY after entire flow succeeds
    touch "${FIRST_BOOT_MARKER}"

# --- Worker node join ---
elif [[ "${KUBERBLUE_NODE_ROLE}" == "worker" ]]; then
```

### Worker path (already correct):

The worker path writes the marker after `kubeadm join` succeeds, which is
correct. No change needed.

## Recovery

If a node is stuck due to this bug (marker exists but post-install incomplete):

```bash
kuberblue reset --force
# or manually:
rm /etc/kuberblue/did_first_boot
reboot
```

## Apply After

Apply this fix AFTER Phase 3 merges its changes to `first_boot.sh`, to avoid
merge conflicts. The fix is a simple relocation of one line.
