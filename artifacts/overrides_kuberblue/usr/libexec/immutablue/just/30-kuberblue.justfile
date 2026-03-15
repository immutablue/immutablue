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

kube_reset *FLAGS:
    sudo /usr/libexec/kuberblue/kube_setup/kube_reset.sh {{FLAGS}}

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

kube_status:
    sudo /usr/libexec/kuberblue/kube_setup/kube_status.sh

kube_doctor:
    sudo /usr/libexec/kuberblue/kube_setup/kube_doctor.sh

kube_join *ARGS:
    sudo /usr/libexec/kuberblue/kube_setup/kube_join.sh {{ARGS}}

kube_refresh_token *FLAGS:
    sudo /usr/libexec/kuberblue/kube_setup/kube_refresh_token.sh {{FLAGS}}

kube_override file:
    sudo /usr/libexec/kuberblue/kube_setup/kube_override.sh {{file}}

kube_encrypt *FILES:
    sudo /usr/libexec/kuberblue/kube_setup/kube_sops.sh encrypt {{FILES}}

kube_decrypt *FILES:
    sudo /usr/libexec/kuberblue/kube_setup/kube_sops.sh decrypt {{FILES}}

kube_upgrade *ARGS:
    sudo /usr/libexec/kuberblue/kube_setup/kube_upgrade.sh {{ARGS}}

kube_mcp_serve:
    #!/bin/bash
    set -euo pipefail
    if [[ -x /usr/bin/mcp-kuberblue ]]; then
        exec /usr/bin/mcp-kuberblue
    else
        echo "ERROR: /usr/bin/mcp-kuberblue not found."
        echo "The MCP server will be available after Phase 6 implementation."
        exit 1
    fi

