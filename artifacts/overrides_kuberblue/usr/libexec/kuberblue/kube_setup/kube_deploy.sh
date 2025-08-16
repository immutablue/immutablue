#!/bin/bash

set -euxo pipefail

manifest_dir="/etc/kuberblue/manifests/"

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


get_metadata_value() {
    local metadata_file="$1"
    local key="$2"

    if [[ ! -e "$metadata_file" ]]; then
        echo "ERROR: Missing metadata file: $metadata_file" >&2
        exit 1
    fi

    local value
    value="$(yq -r ".$key" "$metadata_file")"

    if [[ "$value" == "null" || "$value" == "" ]]; then
        echo "ERROR: Missing required metadata key '$key' in $metadata_file" >&2
        exit 1
    fi

    echo "$value"
}

deploy_prerequisites() {
    local filename="$1"
    local metadata_file
    metadata_file="$(dirname "$filename")/00-metadata.yaml"
    
    local name
    local namespace
    
    name="$(get_metadata_value "$metadata_file" "name")"
    namespace="$(get_metadata_value "$metadata_file" "namespace")"
    
    echo "Deploying prerequisites for component '$name' in namespace '$namespace'"
    kubectl apply -f "$filename"
}

deploy_helm_chart() {
    local filename="$1"
    local metadata_file
    metadata_file="$(dirname "$filename")/00-metadata.yaml"
    
    
    local name
    local chart
    local namespace
    local create_namespace
    local repo_name
    local repo_url
    
    name="$(get_metadata_value "$metadata_file" "name")"
    chart="$(get_metadata_value "$metadata_file" "chart")"
    namespace="$(get_metadata_value "$metadata_file" "namespace")"
    create_namespace="$(get_metadata_value "$metadata_file" "create_namespace")"
    repo_name="$(get_metadata_value "$metadata_file" "repo_name")"
    repo_url="$(get_metadata_value "$metadata_file" "repo_url")"
    
    
    echo "Deploying Helm chart '$chart' as '$name' in namespace '$namespace'"
    
    if [[ "$repo_name" != "" && "$repo_url" != "" ]]; then
        helm repo add "$repo_name" "$repo_url"
        helm repo update
    fi
    
    if [[ "$create_namespace" == "true" ]]; then
        helm upgrade -i "${name}" "${chart}" --namespace "${namespace}" --create-namespace -f "$filename"
    else
        helm upgrade -i "${name}" "${chart}" --namespace "${namespace}" -f "$filename"
    fi
}

deploy_patch() {
    local filename="$1"
    
    echo "Applying patch from $filename"
    local patch_basename
    patch_basename="$(basename "$filename")"
    
    if [[ "$patch_basename" == *"default-sc-patch"* ]]; then
        kubectl patch storageclass openebs-hostpath --patch-file "$filename"
    else
        echo "WARNING: Unknown patch file format: $filename"
        echo "Patch files must follow naming convention: *default-sc-patch*"
    fi
}

deploy_raw_manifest() {
    local filename="$1"
    
    echo "Deploying raw manifest $filename"
    kubectl apply -f "$filename"
}

deploy_kustomize() {
    local filename="$1"
    
    echo "Deploying using Kustomize"
    kubectl apply -k "$(dirname "$filename")"
}

determine_deployment_strategy() {
    local filename="$1"
    local basename
    basename="$(basename "$filename")"
    
    if [[ "$basename" == *metadata.yaml ]]; then
        echo "Skipping metadata file: $basename (used for context only)"
        return
    fi
    
    if [[ "$basename" == *_test.yaml ]]; then
        echo "Skipping Chainsaw test file: $basename"
        return
    fi
    
    case "$basename" in
        *prerequisites*.yaml | *prerequisites*.json)
            deploy_prerequisites "$filename"
            ;;
        *values.yaml)
            deploy_helm_chart "$filename"
            ;;
        *kustomization.yaml)
            deploy_kustomize "$filename"
            ;;
        *patch.yaml | *patch.json)
            deploy_patch "$filename"
            ;;
        *)
            deploy_raw_manifest "$filename"
            ;;
    esac
}

deploy_all_manifests(){
    # First process manifests in the root directory
    if compgen -G "${manifest_dir}*.yaml" > /dev/null || compgen -G "${manifest_dir}*.json" > /dev/null; then
        for f in "${manifest_dir}"*.yaml "${manifest_dir}"*.json; do
            # Skip if the file doesn't exist (happens when no matches for one of the patterns)
            [ -e "$f" ] || continue
            determine_deployment_strategy "$f"
            # Wait for resources to propagate
            sleep 5
        done
    fi

    # Process manifests in subdirectories with smart ordering
    find "${manifest_dir}" -mindepth 2 -type f \( -name "*prerequisites*.yaml" -o -name "*prerequisites*.json" \) | sort | while read f; do
        determine_deployment_strategy "$f"
        # Wait for resources to propagate
        sleep 5
    done
    
    find "${manifest_dir}" -mindepth 2 -type f \( -name "*.yaml" -o -name "*.json" \) \
        ! -name "*prerequisites*" | sort | while read f; do
        determine_deployment_strategy "$f"
        # Wait for resources to propagate
        sleep 5
    done
}

deploy_manifest() {
    local filename="$1"
    
    if [[ ! -f "$filename" ]]; then
        echo "File $filename does not exist. Cannot deploy."
        return 1
    fi
    
    determine_deployment_strategy "$filename"
}
