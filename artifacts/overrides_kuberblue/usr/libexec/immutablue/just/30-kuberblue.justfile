install_dir := "/usr/immutablue"
config_dir := "/etc/kuberblue"
kuberblue_uid := "970"


run_post_install: 
    sudo /usr/libexec/kuberblue/setup/run_post_install.sh {{install_dir}}

systemd_settings:
    sudo /usr/libexec/kuberblue/setup/systemd_settings.sh

first_boot:
    sudo /usr/libexec/kuberblue/setup/first_boot.sh


# This is ran as root at boot time
on_boot: 
    sudo /usr/libexec/kuberblue/setup/on_boot.sh


on_shutdown: 
    sudo /usr/libexec/kuberblue/setup/on_shutdown.sh

kube_reset:
    sudo /usr/libexec/kuberblue/kube_setup/kube_reset.sh

kube_init:
    sudo /usr/libexec/kuberblue/kube_setup/kube_init.sh


# Reset cni0 interface with incorrect ip
# kube_fix_cni_bad_ip:
#    #!/bin/bash
#    set -euxo pipefail
#
#    sudo ip link set cni0 down && ip link set flannel.1 down 
#    sudo ip link delete cni0 && ip link delete flannel.1
#    sudo systemctl restart crio && systemctl restart kubelet


kube_untaint_master:
    sudo /usr/libexec/kuberblue/kube_setup/kube_untaint_master.sh

kube_post_install: kube_untaint_master
    sudo /usr/libexec/kuberblue/kube_setup/kube_post_install.sh

kube_add_kuberblue_user: 
    sudo /usr/libexec/kuberblue/kube_setup/kube_add_kuberblue_user.sh

# This is an internal helper function
_run_command_as_kuberblue command message:
    sudo /usr/libexec/kuberblue/kube_setup/run_command_as_kuberblue_user.sh {{command}} {{message}}

# used internally
_kube_put_config:
    sudo /usr/libexec/kuberblue/kube_setup/kube_put_config.sh


kube_get_config:
    /usr/libexec/kuberblue/kube_setup/kube_get_config.sh

deploy file_path:
    #!/bin/bash
    set -euo pipefail
    source /usr/libexec/kuberblue/kube_setup/kube_deploy.sh
    deploy_manifest {{file_path}}

deploy_all:
    #!/bin/bash
    set -euo pipefail
    source /usr/libexec/kuberblue/kube_setup/kube_deploy.sh
    deploy_all_manifests

