#!/bin/bash
set -euxo pipefail
if [[ -f "${INSTALL_DIR}/build/99-common.sh" ]]; then source "${INSTALL_DIR}/build/99-common.sh"; fi
if [[ -f "./99-common.sh" ]]; then source "./99-common.sh"; fi

# Check if systemctl is available (should be on both Fedora and GNOME OS)
if ! command -v systemctl &> /dev/null; then
    echo "systemctl not found, skipping service configuration"
    exit 0
fi

# -----------------------------------
# Distroless builds: skip service configuration
# GNOME OS doesn't have the same services as Fedora (tailscale, etc.)
# -----------------------------------
if [[ "$(is_option_in_build_options distroless)" == "${TRUE}" ]]
then
    echo "=== Distroless build: skipping service configuration ==="
    echo "GNOME OS base has different services than Fedora"
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
    systemctl unmask "$svc"
done

for svc in $sys_disable 
do 
    systemctl disable "$svc"
done

for svc in $sys_enable 
do  
    systemctl enable "$svc"
done 

for svc in $sys_mask 
do 
    systemctl mask "$svc"
done


# Per user
for svc in $user_unmask
do 
    systemctl --global unmask "$svc"
done

for svc in $user_disable 
do 
    systemctl --global disable "$svc"
done

for svc in $user_enable 
do  
    systemctl --global enable "$svc"
done 

for svc in $user_mask 
do 
    systemctl --global mask "$svc"
done

