#!/bin/bash

set -euxo pipefail

# Check if manifests is empty
manifest_dir="/etc/kuberblue/manifests/"
HELM_TIMEOUT="${HELM_TIMEOUT:-10m}"

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
        # Ensure temp file is cleaned up on script exit
        trap 'rm -f '"$tmpfile" EXIT

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
        exit 1
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
        exit 1
    fi
    if [[ "$chart" == "null" ]] || [[ -z "$chart" ]]; then
        echo "ERROR: .chart is missing in $metadata_file"
        exit 1
    fi

    # Repo info
    local repo_name repo_url
    repo_name="$(yq ".repo_name" "$metadata_file")"
    repo_url="$(yq ".repo_url" "$metadata_file")"

    if [[ "$repo_name" == "null" ]] || [[ -z "$repo_name" ]] || \
       [[ "$repo_url" == "null" ]] || [[ -z "$repo_url" ]]; then
        echo "ERROR: .repo_name or .repo_url missing in $metadata_file"
        exit 1
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
    local namespace

    # Decrypt if SOPS-encrypted
    local apply_file
    apply_file="$(kuberblue_sops_decrypt_if_needed "$file")"

    echo "Deploying $apply_file via kubectl apply"
    kubectl apply -f "$apply_file"

    # Extract namespace from the manifest (use first document if multi-doc)
    namespace="$(yq -e '.metadata.namespace // "default"' "$apply_file" 2>/dev/null | head -1)" || namespace="default"

    # Wait for Deployments to become available
    local kind
    # Handle multi-document YAML: check all documents
    for kind in $(yq -e '.kind' "$apply_file" 2>/dev/null); do
        case "$kind" in
            Deployment)
                local dep_name
                dep_name="$(yq -e 'select(.kind == "Deployment") | .metadata.name' "$apply_file" 2>/dev/null | head -1)"
                if [[ -n "$dep_name" ]] && [[ "$dep_name" != "null" ]]; then
                    echo "Waiting for Deployment ${dep_name} rollout..."
                    kubectl rollout status deployment/"${dep_name}" \
                        --namespace "${namespace}" --timeout="${HELM_TIMEOUT}" || true
                fi
                ;;
            DaemonSet)
                local ds_name
                ds_name="$(yq -e 'select(.kind == "DaemonSet") | .metadata.name' "$apply_file" 2>/dev/null | head -1)"
                if [[ -n "$ds_name" ]] && [[ "$ds_name" != "null" ]]; then
                    echo "Waiting for DaemonSet ${ds_name} rollout..."
                    kubectl rollout status daemonset/"${ds_name}" \
                        --namespace "${namespace}" --timeout="${HELM_TIMEOUT}" || true
                fi
                ;;
            StatefulSet)
                local sts_name
                sts_name="$(yq -e 'select(.kind == "StatefulSet") | .metadata.name' "$apply_file" 2>/dev/null | head -1)"
                if [[ -n "$sts_name" ]] && [[ "$sts_name" != "null" ]]; then
                    echo "Waiting for StatefulSet ${sts_name} rollout..."
                    kubectl rollout status statefulset/"${sts_name}" \
                        --namespace "${namespace}" --timeout="${HELM_TIMEOUT}" || true
                fi
                ;;
        esac
    done
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
        # Extract resource type and name from patch filename
        local patch_basename
        patch_basename=$(basename "$f")
        if [[ "$patch_basename" == *"default-sc-patch"* ]]; then
            # This is a storage class patch - apply to openebs-hostpath storage class
            kubectl patch storageclass openebs-hostpath --patch-file "$f"
        else
            echo "WARNING: Unknown patch file format: $f"
            echo "Patch files must follow naming convention: *default-sc-patch*"
        fi
        return
    fi
    # Default: kubectl apply with rollout wait
    kubectl_apply_and_wait "$f"
    return
}

deploy_all_manifests(){
    # First process manifests in the root directory
    if compgen -G "${manifest_dir}*.yaml" > /dev/null || compgen -G "${manifest_dir}*.json" > /dev/null; then
        for f in "${manifest_dir}"*.yaml "${manifest_dir}"*.json; do
            # Skip if the file doesn't exist (happens when no matches for one of the patterns)
            [ -e "$f" ] || continue
            determine_file_and_deploy "$f"
        done
    fi

    # Process manifests in subdirectories using find to handle any level of nesting
    # Skip .tpl files from find as well
    find "${manifest_dir}" -mindepth 2 -type f \( -name "*.yaml" -o -name "*.json" \) \
        ! -name "*.tpl" | sort | while read -r f; do
        determine_file_and_deploy "$f"
    done

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
