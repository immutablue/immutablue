#!/bin/bash
set -euxo pipefail

source /usr/libexec/kuberblue/variables.sh
source /usr/libexec/kuberblue/99-common.sh

export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

/usr/libexec/kuberblue/kube_setup/kube_add_kuberblue_user.sh
/usr/libexec/kuberblue/kube_setup/kube_put_config.sh
# Deploy core manifests as the kuberblue user
/usr/libexec/kuberblue/kube_setup/run_command_as_kuberblue_user.sh '/usr/libexec/kuberblue/kube_setup/kube_deploy.sh deploy_all' 'Deploying all manifests...'
