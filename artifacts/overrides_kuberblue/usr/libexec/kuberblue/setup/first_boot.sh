#!/bin/bash
set -euo pipefail

source /usr/libexec/kuberblue/99-common.sh
source /usr/libexec/kuberblue/variables.sh
source /usr/libexec/kuberblue/kube_setup/kube_state.sh

FIRST_BOOT_MARKER="/etc/kuberblue/did_first_boot"

mkdir -p /etc/kuberblue "${STATE_DIR}"
kuberblue_state_init

if [[ -f "${FIRST_BOOT_MARKER}" ]]; then
    echo "First boot already completed. Skipping init."
    exit 0
fi

# First boot needs all config values — load eagerly
kuberblue_load_all

echo "=== Kuberblue first boot: topology=${KUBERBLUE_TOPOLOGY}, role=${KUBERBLUE_NODE_ROLE} ==="

# --- Tailscale (host-level, must run before kubeadm) ---
if [[ "${KUBERBLUE_TAILSCALE_ENABLED}" == "true" ]]; then
    echo "Setting up Tailscale..."
    /usr/libexec/kuberblue/kube_setup/kube_tailscale_setup.sh
    kuberblue_state_set "tailscale-configured" "true"
fi

# If advertise_address is 'tailscale', verify we actually have a Tailscale IP
if [[ "${KUBERBLUE_ADVERTISE_ADDR}" == "tailscale" ]] && [[ ! -f "${STATE_DIR}/tailscale-ip" ]]; then
    echo "ERROR: advertise_address=tailscale but Tailscale IP not available"
    echo "Ensure networking.tailscale.enabled=true in cni.yaml and an authkey is configured"
    exit 1
fi

# Read multi-node config
TOKEN_DISTRIBUTION="$(kuberblue_config_get cluster.yaml .cluster.multi.token_distribution "manual")"
WORKER_AUTO_JOIN="$(kuberblue_config_get cluster.yaml .cluster.multi.worker_auto_join "false")"

# -----------------------------------------------------------------------
# Helper: run post-init steps common to all control-plane nodes
# -----------------------------------------------------------------------
cp_post_init () {
    export KUBECONFIG=/etc/kubernetes/admin.conf

    # Untaint before deploying so workloads can schedule on the control-plane
    if [[ "${KUBERBLUE_TOPOLOGY}" == "single" ]]; then
        echo "Single-node topology: removing control-plane taint..."
        /usr/libexec/kuberblue/kube_setup/kube_untaint_master.sh
    fi

    # Deploy core manifests (Cilium CNI, OpenEBS, metrics-server) before waiting
    # for node Ready — the node cannot become Ready without Cilium installed first.
    KUBECONFIG="${KUBECONFIG}" /usr/libexec/kuberblue/kube_setup/kube_post_install.sh

    # Now wait for the node to become Ready (Cilium makes this happen)
    echo "Waiting for node to become Ready..."
    sleep 5
    wait_for_node_ready_state

    # SOPS+Age key setup (after cluster is ready)
    if [[ "${KUBERBLUE_SOPS_ENABLED}" == "true" ]]; then
        echo "Setting up SOPS+Age secrets..."
        KUBECONFIG="${KUBECONFIG}" /usr/libexec/kuberblue/kube_setup/kube_sops_setup.sh
        kuberblue_state_set "sops-configured" "true"
    fi

    # Flux bootstrap (after core manifests are deployed)
    if [[ "${KUBERBLUE_GITOPS_ENABLED}" == "true" ]]; then
        echo "Bootstrapping Flux CD..."
        KUBECONFIG="${KUBECONFIG}" /usr/libexec/kuberblue/kube_setup/kube_flux_bootstrap.sh
        kuberblue_state_set "flux-bootstrapped" "true"
    fi
}

# -----------------------------------------------------------------------
# Helper: generate + serve join token for multi/ha topologies
# -----------------------------------------------------------------------
cp_generate_and_serve_token () {
    local token_ttl
    token_ttl="$(kuberblue_config_get cluster.yaml .cluster.multi.token_ttl "24h")"

    echo "Generating worker join token (TTL=${token_ttl})..."
    kubeadm token create --print-join-command --ttl "${token_ttl}" > "${STATE_DIR}/worker-join-command"
    chmod 0640 "${STATE_DIR}/worker-join-command"
    chown root:kuberblue "${STATE_DIR}/worker-join-command" 2>/dev/null \
        || echo "WARNING: chown to kuberblue group failed — group may not exist yet"
    echo "Worker join command stored at ${STATE_DIR}/worker-join-command"

    # If using Tailscale distribution, serve the token
    if [[ "${TOKEN_DISTRIBUTION}" == "tailscale" ]]; then
        export TOKEN_TTL="${token_ttl}"
        source /usr/libexec/kuberblue/kube_setup/kube_token_distribute.sh
        kuberblue_token_serve "${STATE_DIR}/worker-join-command"
    else
        echo "Run 'kuberblue refresh-token' to retrieve the join command."
    fi
}

# -----------------------------------------------------------------------
# Detect HA first-CP vs non-first-CP
# First CP: no existing state AND no existing CP discovered via Tailscale
# -----------------------------------------------------------------------
ha_is_first_cp () {
    # If we already have state, this isn't first boot
    if kuberblue_state_check "cluster-initialized"; then
        return 1
    fi

    # If Tailscale is enabled and we can find an existing CP, we're not first
    if [[ "${KUBERBLUE_TAILSCALE_ENABLED}" == "true" ]]; then
        local ts_tag
        ts_tag="$(kuberblue_config_get cni.yaml .networking.tailscale.tag "")"
        if [[ -n "${ts_tag}" ]] && [[ "${ts_tag}" != "null" ]]; then
            if tailscale status --json 2>/dev/null \
                | yq -e '.Peer[] | select(.Tags // [] | .[] == "tag:'"${ts_tag}"'")' &>/dev/null; then
                return 1  # Found existing CP — we are NOT the first
            fi
        fi
    fi

    return 0  # No existing CP found — we ARE the first
}


# =======================================================================
# MAIN FLOW
# =======================================================================

# --- HA control-plane ---
if [[ "${KUBERBLUE_TOPOLOGY}" == "ha" ]] && [[ "${KUBERBLUE_NODE_ROLE}" == "control-plane" ]]; then

    # Kube-vip must be set up BEFORE kubeadm init (VIP needs to be reachable)
    echo "Setting up kube-vip for HA VIP..."
    source /usr/libexec/kuberblue/kube_setup/kube_vip_setup.sh
    kuberblue_vip_setup

    if ha_is_first_cp; then
        # Race condition guard: wait briefly for other CPs that may also
        # think they are first.  If another CP appears during the contention
        # window we back off and fall through to the join flow instead.
        #
        # KNOWN LIMITATION: This window narrows but does not eliminate the
        # split-brain risk. Two CPs booting within the same ~30s window that
        # both complete kubeadm init before the other is discoverable via
        # Tailscale could still each initialize a separate cluster. A true fix
        # requires a distributed lease/lock (e.g., a Tailscale-served mutex)
        # before init. For typical HA deployments (manual sequential bring-up,
        # not simultaneous boot), this protection is sufficient.
        echo "HA topology: claiming first-CP role..."
        echo "Waiting 30s for other potential first-CP candidates to announce..."
        sleep 30
        # Re-check: if another CP appeared during the wait, we are NOT first
        if ! ha_is_first_cp; then
            echo "Another CP was detected during the contention window — falling through to join flow"
            _ha_is_first=false
        else
            _ha_is_first=true
        fi
    else
        _ha_is_first=false
    fi

    if [[ "${_ha_is_first}" == "true" ]]; then
        # --- First control-plane: initialize the cluster ---
        echo "HA topology: this is the FIRST control-plane node — initializing cluster..."
        /usr/libexec/kuberblue/kube_setup/kube_init.sh

        kuberblue_state_set "node-role" "control-plane"
        kuberblue_state_set "cluster-initialized" "true"
        kuberblue_state_set "ha-role" "init-cp"

        cp_post_init

        # Upload certs so other CPs can join with --control-plane
        echo "Uploading certificates for HA join..."
        export KUBECONFIG=/etc/kubernetes/admin.conf
        CERT_KEY="$(kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1)"
        kuberblue_state_set "ha-certificate-key" "${CERT_KEY}"

        # Generate join token for other CPs and workers
        cp_generate_and_serve_token

        # If using Tailscale distribution, also serve the certificate key
        if [[ "${TOKEN_DISTRIBUTION}" == "tailscale" ]]; then
            # Write cert key to a file and serve it alongside the join token
            printf '%s\n' "${CERT_KEY}" > "${STATE_DIR}/ha-certificate-key"
            chmod 0640 "${STATE_DIR}/ha-certificate-key"
            chown root:kuberblue "${STATE_DIR}/ha-certificate-key" 2>/dev/null \
                || echo "WARNING: chown to kuberblue group failed — group may not exist yet"

            tailscale serve --bg \
                --https=443 \
                --set-path=/kuberblue/ha-cert-key \
                "${STATE_DIR}/ha-certificate-key"
            echo "Certificate key served via Tailscale at /kuberblue/ha-cert-key"
        fi

        echo "HA first control-plane initialized. Other CPs can now join."

        # Mark first boot complete ONLY after entire flow succeeds
        touch "${FIRST_BOOT_MARKER}"

    else
        # --- Non-first control-plane: join existing HA cluster ---
        echo "HA topology: joining existing cluster as control-plane..."

        source /usr/libexec/kuberblue/kube_setup/kube_token_distribute.sh

        # Discover the first CP
        cp_ip="$(kuberblue_token_discover_cp)"
        echo "Found existing control-plane at: ${cp_ip}"

        # Fetch join token
        kuberblue_token_fetch "${STATE_DIR}/worker-join-command"
        join_cmd="$(<"${STATE_DIR}/worker-join-command")"

        # Fetch certificate key
        echo "Fetching certificate key from first CP..."
        cert_key=""
        max_retries=12
        attempt=0
        while [[ -z "${cert_key}" ]]; do
            attempt=$((attempt + 1))
            if [[ ${attempt} -gt ${max_retries} ]]; then
                echo "ERROR: Could not fetch certificate key after ${max_retries} attempts" >&2
                exit 1
            fi
            cert_key="$(curl --silent --fail --insecure --connect-timeout 10 \
                "https://${cp_ip}/kuberblue/ha-cert-key" 2>/dev/null)" || true
            if [[ -z "${cert_key}" ]]; then
                echo "Waiting for certificate key... (${attempt}/${max_retries})"
                sleep 10
            fi
        done

        # Validate cert key looks reasonable (64 hex chars)
        if ! [[ "${cert_key}" =~ ^[0-9a-f]{64}$ ]]; then
            echo "ERROR: Fetched certificate key does not look valid" >&2
            echo "Received: ${cert_key:0:80}" >&2
            exit 1
        fi

        # Join as control-plane (safe parse — no eval on network data)
        echo "Joining HA cluster as control-plane..."
        kubeadm_join_safe "${join_cmd}" --control-plane --certificate-key "${cert_key}"

        kuberblue_state_set "node-role" "control-plane"
        kuberblue_state_set "cluster-initialized" "true"
        kuberblue_state_set "ha-role" "join-cp"

        # Non-first CPs need the kuberblue user and kubeconfig for kubectl access,
        # but NOT the full cp_post_init (which would re-deploy manifests, re-bootstrap
        # Flux, etc. — those are only needed on the first CP).
        export KUBECONFIG=/etc/kubernetes/admin.conf
        /usr/libexec/kuberblue/kube_setup/kube_add_kuberblue_user.sh
        /usr/libexec/kuberblue/kube_setup/kube_put_config.sh

        echo "HA control-plane join complete."

        # Mark first boot complete ONLY after entire flow succeeds
        touch "${FIRST_BOOT_MARKER}"
    fi

# --- Single / Multi control-plane init ---
elif [[ "${KUBERBLUE_NODE_ROLE}" == "control-plane" ]]; then
    if kuberblue_state_check "cluster-initialized"; then
        echo "Cluster already initialized (kubeadm ran on a previous boot) — skipping kubeadm init"
        export KUBECONFIG=/etc/kubernetes/admin.conf
    else
        echo "Initializing Kubernetes control-plane..."
        /usr/libexec/kuberblue/kube_setup/kube_init.sh
        kuberblue_state_set "node-role" "control-plane"
        kuberblue_state_set "cluster-initialized" "true"
    fi

    cp_post_init

    # Generate join token for multi-node topologies
    if [[ "${KUBERBLUE_TOPOLOGY}" == "multi" ]]; then
        cp_generate_and_serve_token
    fi

    # Mark first boot complete ONLY after entire flow succeeds
    touch "${FIRST_BOOT_MARKER}"

# --- Worker node join ---
elif [[ "${KUBERBLUE_NODE_ROLE}" == "worker" ]]; then

    # Path 1: Auto-join via Tailscale token distribution
    if [[ "${WORKER_AUTO_JOIN}" == "true" ]] && [[ "${TOKEN_DISTRIBUTION}" == "tailscale" ]]; then
        echo "Worker auto-join enabled with Tailscale token distribution..."

        if [[ "${KUBERBLUE_TAILSCALE_ENABLED}" != "true" ]]; then
            echo "ERROR: token_distribution=tailscale requires networking.tailscale.enabled=true" >&2
            exit 1
        fi

        source /usr/libexec/kuberblue/kube_setup/kube_token_distribute.sh

        # Fetch join token from CP
        kuberblue_token_fetch "${STATE_DIR}/worker-join-command"
        join_cmd="$(<"${STATE_DIR}/worker-join-command")"

        echo "Joining cluster as worker node..."
        kubeadm_join_safe "${join_cmd}"

        kuberblue_state_set "node-role" "worker"
        kuberblue_state_set "cluster-initialized" "true"

        touch "${FIRST_BOOT_MARKER}"

    # Path 2: Join command already present (manual copy or pre-provisioned)
    elif [[ -f "${STATE_DIR}/worker-join-command" ]]; then
        if [[ ! -s "${STATE_DIR}/worker-join-command" ]]; then
            echo "ERROR: worker-join-command exists but is empty"
            exit 1
        fi
        echo "Joining cluster as worker node..."
        kubeadm_join_safe "$(<"${STATE_DIR}/worker-join-command")"

        kuberblue_state_set "node-role" "worker"
        kuberblue_state_set "cluster-initialized" "true"

        touch "${FIRST_BOOT_MARKER}"

    # Path 3: Manual join required — print instructions and exit
    else
        echo "============================================================"
        echo "  Worker node — manual join required"
        echo "============================================================"
        echo ""
        echo "This node is configured as a worker but no join token is available."
        echo ""
        if [[ "${TOKEN_DISTRIBUTION}" == "tailscale" ]] && [[ "${WORKER_AUTO_JOIN}" != "true" ]]; then
            echo "Auto-join is disabled. To enable it, set in cluster.yaml:"
            echo "  cluster.multi.worker_auto_join: true"
            echo ""
        fi
        echo "To join manually:"
        echo "  1. On the control-plane node, run: kuberblue refresh-token"
        echo "  2. Copy the join command to this node:"
        echo "     kuberblue join <kubeadm join command...>"
        echo "  3. Or copy to: ${STATE_DIR}/worker-join-command"
        echo "     and reboot"
        echo ""
        exit 0
    fi
fi

echo "=== Kuberblue first boot complete ==="
