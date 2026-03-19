#!/bin/bash

set -euxo pipefail

source /usr/libexec/kuberblue/variables.sh

# Check if manifests is empty
manifest_dir="/etc/kuberblue/manifests/"
HELM_TIMEOUT="${HELM_TIMEOUT:-10m}"

# Track all SOPS temp files for cleanup
_sops_tmpfiles=()
_sops_cleanup() {
    for f in "${_sops_tmpfiles[@]}"; do
        rm -f "$f"
    done
}
trap _sops_cleanup EXIT

if [[ ! -d "$manifest_dir" ]]
then
    echo "Manifest dir does not exist. Nothing to do."
    exit 1
fi

if [[ -z "$(find "$manifest_dir" -type f \( -name "*.yaml" -o -name "*.json" \) | head -1)" ]]
then
    echo "Manifest dir is empty. Nothing to do."
    exit 0
fi


# --- Package tier filtering ---
# Reads packages.yaml to enforce the tier system:
#   Tier 1 (core)     — always deploy, regardless of enabled flag
#   Tier 2 (optional) — only deploy when enabled: true
#   Tier 3 (custom)   — user files not listed in packages.yaml deploy unconditionally

declare -A _ENABLED_MANIFESTS
declare -A _DISABLED_MANIFESTS
_PACKAGES_LOADED="false"

kuberblue_load_packages() {
    if [[ "$_PACKAGES_LOADED" == "true" ]]; then
        return
    fi

    local packages_file=""
    for dir in "${SYSTEM_CONFIG_DIR}" "${VENDOR_CONFIG_DIR}"; do
        if [[ -f "${dir}/packages.yaml" ]]; then
            packages_file="${dir}/packages.yaml"
            break
        fi
    done

    if [[ -z "$packages_file" ]]; then
        echo "WARNING: packages.yaml not found; deploying all manifests"
        _PACKAGES_LOADED="true"
        return
    fi

    echo "Loading package tiers from $packages_file"

    # Tier 1 (core): always enabled
    local core_count
    core_count="$(yq '.packages.core | length' "$packages_file")"
    local i
    for (( i = 0; i < core_count; i++ )); do
        local mpath
        mpath="$(yq ".packages.core[$i].manifest" "$packages_file")"
        if [[ -n "$mpath" ]] && [[ "$mpath" != "null" ]]; then
            _ENABLED_MANIFESTS["$mpath"]=1
        fi
    done

    # Tier 2 (optional): respect enabled flag
    local opt_count
    opt_count="$(yq '.packages.optional | length' "$packages_file")"
    for (( i = 0; i < opt_count; i++ )); do
        local mpath enabled pkg_name
        mpath="$(yq ".packages.optional[$i].manifest" "$packages_file")"
        enabled="$(yq ".packages.optional[$i].enabled" "$packages_file")"
        pkg_name="$(yq ".packages.optional[$i].name" "$packages_file")"
        if [[ -z "$mpath" ]] || [[ "$mpath" == "null" ]]; then
            continue
        fi
        if [[ "$enabled" == "true" ]]; then
            _ENABLED_MANIFESTS["$mpath"]=1
        else
            _DISABLED_MANIFESTS["$mpath"]="$pkg_name"
        fi
    done

    _PACKAGES_LOADED="true"
}

# kuberblue_is_manifest_enabled <file_path>
# Returns 0 if the file should be deployed, 1 if it belongs to a disabled package.
kuberblue_is_manifest_enabled() {
    local file="$1"
    local rel_path="${file#"$manifest_dir"}"

    # If no packages were loaded, deploy everything
    if [[ ${#_ENABLED_MANIFESTS[@]} -eq 0 ]] && [[ ${#_DISABLED_MANIFESTS[@]} -eq 0 ]]; then
        return 0
    fi

    # Check if file belongs to a disabled package
    local mpath
    for mpath in "${!_DISABLED_MANIFESTS[@]}"; do
        if [[ "$rel_path" == "$mpath"/* ]] || [[ "$rel_path" == "$mpath" ]]; then
            echo "Skipping disabled package: ${_DISABLED_MANIFESTS[$mpath]} ($mpath)"
            return 1
        fi
    done

    return 0
}


# --- SOPS decryption helper ---
# Decrypts SOPS-encrypted files (*.sops.yaml, *.sops.json) using the cluster Age key.
# Returns: path to the decrypted temp file, or the original path if not SOPS-encrypted.
kuberblue_sops_decrypt_if_needed() {
    local file="$1"
    local age_key="${KUBERBLUE_AGE_KEY_PATH:-/var/lib/kuberblue/secrets/age.key}"

    # Check if file is SOPS-encrypted by extension
    if [[ "$file" == *.sops.yaml ]] || [[ "$file" == *.sops.json ]]; then
        if [[ ! -f "$age_key" ]]; then
            echo "ERROR: SOPS-encrypted file found ($file) but Age key not available at $age_key" >&2
            echo "Decrypt manually or configure SOPS Age key first." >&2
            return 1
        fi

        local tmpfile
        tmpfile="$(mktemp /tmp/kuberblue-sops-XXXXXX.yaml)"
        _sops_tmpfiles+=("$tmpfile")

        if ! SOPS_AGE_KEY_FILE="$age_key" sops --decrypt "$file" > "$tmpfile"; then
            echo "ERROR: Failed to decrypt SOPS file: $file" >&2
            rm -f "$tmpfile"
            return 1
        fi

        echo "$tmpfile"
        return 0
    fi

    # Not a SOPS file — return original path
    echo "$file"
    return 0
}


# --- Helm deploy with --wait, --timeout, and rollback on failure ---
deploy_helm_repo_and_chart() {
    local filename="$1"
    local metadata_file
    metadata_file="$(dirname "$filename")/00-metadata.yaml"
    if [[ ! -e "$metadata_file" ]]
    then
        echo "Missing metadata.yaml with values file. Cannot continue."
        return 1
    fi
    # Deployment info
    local name chart namespace create_namespace args
    name="$(yq ".name" "$metadata_file")"
    chart="$(yq ".chart" "$metadata_file")"
    namespace="$(yq ".namespace" "$metadata_file")"
    create_namespace="$(yq ".create_namespace" "$metadata_file")"
    args="$(yq ".args" "$metadata_file")"

    # Validate required fields
    if [[ "$name" == "null" ]] || [[ -z "$name" ]]; then
        echo "ERROR: .name is missing in $metadata_file"
        return 1
    fi
    if [[ "$chart" == "null" ]] || [[ -z "$chart" ]]; then
        echo "ERROR: .chart is missing in $metadata_file"
        return 1
    fi

    # Repo info
    local repo_name repo_url
    repo_name="$(yq ".repo_name" "$metadata_file")"
    repo_url="$(yq ".repo_url" "$metadata_file")"

    if [[ "$repo_name" == "null" ]] || [[ -z "$repo_name" ]] || \
       [[ "$repo_url" == "null" ]] || [[ -z "$repo_url" ]]; then
        echo "ERROR: .repo_name or .repo_url missing in $metadata_file"
        return 1
    fi

    # Decrypt values file if SOPS-encrypted
    local values_file
    values_file="$(kuberblue_sops_decrypt_if_needed "$filename")"

    # Add and update helm repo
    helm repo add "$repo_name" "$repo_url"
    helm repo update "$repo_name"

    # Build helm command with --wait and --timeout
    local helm_cmd=(helm upgrade -i "${name}" "${chart}"
        --namespace "${namespace}"
        --wait
        --timeout "${HELM_TIMEOUT}"
        -f "$values_file"
    )
    if [[ "$create_namespace" == "true" ]]; then
        helm_cmd+=(--create-namespace)
    fi
    if [[ -n "$args" ]] && [[ "$args" != "null" ]]; then
        # shellcheck disable=SC2206
        helm_cmd+=($args)
    fi

    # Execute helm upgrade with rollback on failure
    echo "Helm upgrade: ${name} (chart: ${chart}, namespace: ${namespace}, timeout: ${HELM_TIMEOUT})"
    if ! "${helm_cmd[@]}"; then
        echo "ERROR: Helm upgrade failed for ${name}. Attempting rollback..."
        if helm rollback "${name}" --namespace "${namespace}" --wait --timeout "${HELM_TIMEOUT}" 2>/dev/null; then
            echo "Rollback of ${name} succeeded. Previous revision restored."
        else
            echo "WARNING: Rollback of ${name} failed or no previous revision exists."
        fi
        return 1
    fi
    echo "Helm deploy of ${name} succeeded."
}


# --- kubectl apply with rollout status wait ---
kubectl_apply_and_wait() {
    local file="$1"
    local rollout_failed=0

    # Decrypt if SOPS-encrypted
    local apply_file
    apply_file="$(kuberblue_sops_decrypt_if_needed "$file")"

    echo "Deploying $apply_file via kubectl apply"
    kubectl apply -f "$apply_file"

    # Extract per-resource name, namespace, and kind from each YAML document
    # This handles multi-doc YAML correctly instead of using a single namespace
    local doc_index=0
    local doc_count
    doc_count="$(yq 'document_index' "$apply_file" 2>/dev/null | tail -1)" || doc_count=0
    doc_count=$((doc_count + 1))

    while [[ ${doc_index} -lt ${doc_count} ]]; do
        local kind res_name res_ns
        kind="$(yq "select(document_index == ${doc_index}) | .kind" "$apply_file" 2>/dev/null)" || kind=""
        res_name="$(yq "select(document_index == ${doc_index}) | .metadata.name" "$apply_file" 2>/dev/null)" || res_name=""
        res_ns="$(yq "select(document_index == ${doc_index}) | .metadata.namespace // \"default\"" "$apply_file" 2>/dev/null)" || res_ns="default"

        if [[ -z "$res_name" ]] || [[ "$res_name" == "null" ]]; then
            doc_index=$((doc_index + 1))
            continue
        fi

        case "$kind" in
            Deployment)
                echo "Waiting for Deployment ${res_name} rollout in ${res_ns}..."
                if ! kubectl rollout status deployment/"${res_name}" \
                    --namespace "${res_ns}" --timeout="${HELM_TIMEOUT}"; then
                    echo "WARNING: rollout check failed for Deployment/${res_name} in ${res_ns}"
                    rollout_failed=1
                fi
                ;;
            DaemonSet)
                echo "Waiting for DaemonSet ${res_name} rollout in ${res_ns}..."
                if ! kubectl rollout status daemonset/"${res_name}" \
                    --namespace "${res_ns}" --timeout="${HELM_TIMEOUT}"; then
                    echo "WARNING: rollout check failed for DaemonSet/${res_name} in ${res_ns}"
                    rollout_failed=1
                fi
                ;;
            StatefulSet)
                echo "Waiting for StatefulSet ${res_name} rollout in ${res_ns}..."
                if ! kubectl rollout status statefulset/"${res_name}" \
                    --namespace "${res_ns}" --timeout="${HELM_TIMEOUT}"; then
                    echo "WARNING: rollout check failed for StatefulSet/${res_name} in ${res_ns}"
                    rollout_failed=1
                fi
                ;;
        esac
        doc_index=$((doc_index + 1))
    done

    return "${rollout_failed}"
}


determine_file_and_deploy(){
    local f="$1"
    local base
    base="$(basename "$f")"

    if [[ "$base" == *metadata.yaml ]]; then
        # Do nothing here, just keep it from attempting deployment.
        # We just need this for deploying helm charts.
        return
    fi
    if [[ "$base" == *_test.yaml ]]; then
        # Skip Chainsaw test files - these are local test definitions, not Kubernetes resources
        echo "Skipping Chainsaw test file $base"
        return
    fi
    if [[ "$base" == README* ]] || [[ "$base" == *.md ]]; then
        # Skip documentation files
        return
    fi
    if [[ "$base" == *.tpl ]]; then
        # Skip template files — these are user-fillable templates, not deployable resources
        echo "Skipping template file $base"
        return
    fi
    if [[ "$base" == *values.yaml ]] || [[ "$base" == *values.sops.yaml ]]; then
        echo "Deploying using Helm"
        deploy_helm_repo_and_chart "$f"
        return
    fi
    if [[ "$base" == *kustomization.yaml ]]; then
        echo "Deploying using Kustomize"
        kubectl apply -k "$(dirname "$f")"
        return
    fi
    if [[ "$base" == *patch.yaml ]] || [[ "$base" == *patch.json ]]; then
        echo "Applying patch from $f"
        local metadata_file
        metadata_file="$(dirname "$f")/00-metadata.yaml"
        local patch_kind="" patch_name=""

        # Read patch target from metadata.yaml (.patches.<filename>.kind / .name)
        if [[ -f "$metadata_file" ]]; then
            patch_kind="$(yq ".patches.\"${base}\".kind // \"\"" "$metadata_file" 2>/dev/null)"
            patch_name="$(yq ".patches.\"${base}\".name // \"\"" "$metadata_file" 2>/dev/null)"
        fi

        if [[ -n "$patch_kind" ]] && [[ -n "$patch_name" ]] \
            && [[ "$patch_kind" != "null" ]] && [[ "$patch_name" != "null" ]]; then
            kubectl patch "$patch_kind" "$patch_name" --patch-file "$f"
        else
            echo "WARNING: No patch target defined for $base in $metadata_file"
            echo "Add a .patches.\"${base}\" entry with kind and name fields."
        fi
        return
    fi
    # Default: kubectl apply with rollout wait
    kubectl_apply_and_wait "$f"
    return
}

deploy_all_manifests(){
    # Load package tier configuration before deploying
    kuberblue_load_packages

    # First process manifests in the root directory (not under any package path)
    if compgen -G "${manifest_dir}*.yaml" > /dev/null || compgen -G "${manifest_dir}*.json" > /dev/null; then
        for f in "${manifest_dir}"*.yaml "${manifest_dir}"*.json; do
            # Skip if the file doesn't exist (happens when no matches for one of the patterns)
            [ -e "$f" ] || continue
            if kuberblue_is_manifest_enabled "$f"; then
                determine_file_and_deploy "$f"
            fi
        done
    fi

    # Process manifests in subdirectories using find to handle any level of nesting
    # Skip .tpl files from find as well
    # Filter out disabled packages before deploying
    while IFS= read -r f; do
        if kuberblue_is_manifest_enabled "$f"; then
            determine_file_and_deploy "$f"
        fi
    done < <(find "${manifest_dir}" -mindepth 2 -type f \( -name "*.yaml" -o -name "*.json" \) \
        ! -name "*.tpl" | sort)

    # Post-deploy validation: check for non-Running/non-Succeeded pods
    echo ""
    echo "=== Post-deploy validation ==="
    local problem_pods
    problem_pods="$(kubectl get pods -A --no-headers \
        --field-selector 'status.phase!=Running,status.phase!=Succeeded' 2>/dev/null)" || true
    if [[ -n "$problem_pods" ]]; then
        echo "WARNING: The following pods are not in Running/Succeeded state:"
        echo "$problem_pods"
    else
        echo "All pods are Running or Succeeded."
    fi
}

deploy_manifest() {
    local f="$1"

    # Make sure the file exists
    if [[ ! -f "$f" ]]; then
        echo "File $f does not exist. Cannot deploy."
        return 1
    fi

    determine_file_and_deploy "$f"
}

# --- Entry point for direct execution ---
# When called as an executable (not sourced), dispatch subcommands:
#   kube_deploy.sh deploy_all          - deploy all manifests
#   kube_deploy.sh deploy <file>       - deploy a single manifest
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euxo pipefail
    case "${1:-}" in
        deploy_all)
            deploy_all_manifests
            ;;
        deploy)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 deploy <file_path>"
                exit 1
            fi
            deploy_manifest "$2"
            ;;
        *)
            echo "Usage: $0 {deploy_all|deploy <file>}"
            exit 1
            ;;
    esac
fi
