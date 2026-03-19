#!/bin/bash
# kube_flux_bootstrap.sh
#
# Bootstraps Flux CD after the cluster is ready.
# Run after kube_post_install.sh (requires kubeconfig in place).
#
# If gitops.enabled is false, installs Flux CRDs and controllers only
# (passive install — no GitOps reconciliation yet).
# If gitops.enabled is true, performs a full bootstrap against the configured repo.
#
# Must be run as the kuberblue user (has kubeconfig at ~/.kube/config).
set -euxo pipefail

source /usr/libexec/kuberblue/variables.sh

if ! command -v flux &>/dev/null; then
    echo "ERROR: flux CLI not found. Is it installed?"
    exit 1
fi

GITOPS_ENABLED="$(kuberblue_gitops_enabled)"
FLUX_NS="$(kuberblue_config_get gitops.yaml .gitops.namespace "flux-system")"

if [[ "${GITOPS_ENABLED}" == "true" ]]; then
    REPO_URL="$(kuberblue_config_get gitops.yaml .gitops.repo.url "")"
    REPO_BRANCH="$(kuberblue_config_get gitops.yaml .gitops.repo.branch "main")"
    REPO_PATH="$(kuberblue_config_get gitops.yaml .gitops.repo.path "clusters/my-cluster")"
    PROVIDER="$(kuberblue_config_get gitops.yaml .gitops.provider "generic")"
    AUTH_SECRET="$(kuberblue_config_get gitops.yaml .gitops.auth_secret "flux-git-auth")"

    # Validate required fields
    if [[ -z "${REPO_URL}" ]] || [[ "${REPO_URL}" == "null" ]]; then
        echo "ERROR: gitops.repo.url not configured. Set it in /etc/kuberblue/gitops.yaml"
        exit 1
    fi
    if [[ "${REPO_BRANCH}" == "null" ]]; then
        REPO_BRANCH="main"
    fi
    if [[ "${REPO_PATH}" == "null" ]]; then
        REPO_PATH="clusters/my-cluster"
    fi
    if [[ "${AUTH_SECRET}" == "null" ]]; then
        AUTH_SECRET="flux-git-auth"
    fi

    echo "Bootstrapping Flux against ${REPO_URL} (${REPO_BRANCH}:${REPO_PATH})"

    local -a flux_cmd=(flux bootstrap git
        --url="${REPO_URL}"
        --branch="${REPO_BRANCH}"
        --path="${REPO_PATH}"
        --secret-ref="${AUTH_SECRET}"
        --namespace="${FLUX_NS}"
        --components-extra=image-reflector-controller,image-automation-controller
    )
    if [[ -n "${PROVIDER}" ]] && [[ "${PROVIDER}" != "null" ]]; then
        flux_cmd+=(--provider="${PROVIDER}")
    fi

    "${flux_cmd[@]}"
else
    # Passive install: install Flux without bootstrapping a repo
    echo "Installing Flux (passive — no GitOps repo configured)"
    flux install \
        --namespace="${FLUX_NS}" \
        --components-extra=image-reflector-controller,image-automation-controller
fi

# Wait for Flux controllers to be ready
echo "Waiting for Flux controllers to be ready..."
kubectl wait --for=condition=available \
    --timeout=120s \
    -n "${FLUX_NS}" \
    deployment/source-controller \
    deployment/kustomize-controller \
    deployment/helm-controller \
    deployment/notification-controller

echo "Flux is ready."
