#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# Service state is changed through the backend's backend_svc (systemctl on
# systemd backends, sysrc on FreeBSD). A systemd backend whose base image has
# no systemctl has nothing to configure.
if [[ "$(backend_has systemd)" == "${TRUE}" ]] && ! command -v systemctl &> /dev/null; then
    echo "systemctl not found, skipping service configuration"
    exit 0
fi

sys_unmask=$(get_immutablue_system_services_to_unmask)
sys_mask=$(get_immutablue_system_services_to_mask)
sys_disable=$(get_immutablue_system_services_to_disable)
sys_enable=$(get_immutablue_system_services_to_enable)
user_unmask=$(get_immutablue_user_services_to_unmask)
user_mask=$(get_immutablue_user_services_to_mask)
user_disable=$(get_immutablue_user_services_to_disable)
user_enable=$(get_immutablue_user_services_to_enable)


for svc in $sys_unmask
do 
    backend_svc unmask "$svc"
done

for svc in $sys_disable 
do 
    backend_svc disable "$svc"
done

for svc in $sys_enable 
do  
    backend_svc enable "$svc"
done 

for svc in $sys_mask 
do 
    backend_svc mask "$svc"
done


# Per user
for svc in $user_unmask
do 
    backend_svc unmask --global "$svc"
done

for svc in $user_disable 
do 
    backend_svc disable --global "$svc"
done

for svc in $user_enable 
do  
    backend_svc enable --global "$svc"
done 

for svc in $user_mask 
do 
    backend_svc mask --global "$svc"
done

