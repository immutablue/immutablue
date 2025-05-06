#!/bin/bash 
set -euxo pipefail


source /usr/libexec/kuberblue/kube_setup/kube_deploy.sh
source /usr/libexec/kuberblue/99-common.sh

sudo /usr/libexec/kuberblue/kube_setup/kube_add_kuberblue_user.sh
sudo /usr/libexec/kuberblue/kube_setup/kube_put_config.sh
# Deploy here
sudo /usr/libexec/kuberblue/kube_setup/run_command_as_kuberblue_user.sh deploy_all_manifests 'Deploying all manifests...'
