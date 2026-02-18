#!/bin/bash

set -euxo pipefail

# Check if manifests is empty
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


deploy_helm_repo_and_chart() {
    filename="$1"
    metadata_file="$(dirname "$filename")/00-metadata.yaml"
    if [[ ! -e "$metadata_file" ]]
    then
        echo "Missing metadata.yaml with values file. Cannot continue."
        exit 1
    fi
    # Deployment info
    name="$(yq ".name" "$metadata_file")"
    chart="$(yq ".chart" "$metadata_file")"
    namespace="$(yq ".namespace" "$metadata_file")"
    create_namespace="$(yq ".create_namespace" "$metadata_file")"
    args="$(yq ".args" "$metadata_file")"

    # Repo info
    repo_name="$(yq ".repo_name" "$metadata_file")"
    repo_url="$(yq ".repo_url" "$metadata_file")"

    # Add and update helm repo
    helm repo add "$repo_name" "$repo_url"
    helm repo update 
    # Ignore all args for now
    if [[ "$create_namespace" == "true" ]]
    then
        helm upgrade -i "${name}" "${chart}" --namespace "${namespace}" --create-namespace -f "$filename"
    else
        helm upgrade -i "${name}" "${chart}" --namespace "${namespace}" -f "$filename"
    fi
}

determine_file_and_deploy(){
    f="$1"
    if [[ $(basename "$f") == *metadata.yaml ]]
    then 
        # Do nothing here, just keep it from attempting deployment.
        # We just need this for deploying helm charts.
       return
    fi
    if [[ $(basename "$f") == *_test.yaml ]]
    then
        # Skip Chainsaw test files - these are local test definitions, not Kubernetes resources
        echo "Skipping Chainsaw test file $(basename "$f")"
        return
    fi
    if [[ $(basename "$f") == *values.yaml ]]
    then
        echo "Deploying using Helm"
        deploy_helm_repo_and_chart "$f"
        return
    fi
    if [[ $(basename "$f") == *kustomization.yaml ]]
    then
        echo "Deploying using Kustomize"
        kubectl apply -k "$(dirname "$f")"
        return
    fi
    if [[ $(basename "$f") == *patch.yaml || $(basename "$f") == *patch.json ]]
    then
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
    echo "Deploying $f"
    kubectl apply -f "$f"
    return
}

deploy_all_manifests(){
    # First process manifests in the root directory
    if compgen -G "${manifest_dir}*.yaml" > /dev/null || compgen -G "${manifest_dir}*.json" > /dev/null; then
        for f in "${manifest_dir}"*.yaml "${manifest_dir}"*.json; do
            # Skip if the file doesn't exist (happens when no matches for one of the patterns)
            [ -e "$f" ] || continue
            determine_file_and_deploy "$f"
            # Wait for resources to propagate
            sleep 5
        done
    fi

    # Process manifests in subdirectories using find to handle any level of nesting
    find "${manifest_dir}" -mindepth 2 -type f \( -name "*.yaml" -o -name "*.json" \) | sort | while read f; do
        determine_file_and_deploy "$f"
        # Wait for resources to propagate
        sleep 5
    done
}

deploy_manifest() {
    f="$1"
    
    # Make sure the file exists
    if [[ ! -f "$f" ]]; then
        echo "File $f does not exist. Cannot deploy."
        return 1
    fi
    
    determine_file_and_deploy "$f"
}
