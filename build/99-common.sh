#!/bin/bash 

PACKAGES_YAML="${INSTALL_DIR}/packages.yaml"
MARCH="$(uname -m)"

MODULES_CONF="/etc/modules-load.d/10-immutablue.conf"

ZFS_RPM_URL="https://zfsonlinux.org/fedora/zfs-release-2-6.fc41.noarch.rpm"
LTS_VERSION="6.6"
LTS_REPO_URL="https://copr.fedorainfracloud.org/coprs/kwizart/kernel-longterm-6.6/repo/fedora-41/kwizart-kernel-longterm-${LTS_VERSION}-fedora-41.repo"

get_yaml_array() {
    local key="$1"
    cat <(yq "$key[]" < "${PACKAGES_YAML}") <(yq "${key}_${MARCH}[]" < "${PACKAGES_YAML}")
}


get_immutablue_packages() {
    get_yaml_array '.immutablue.rpm'
}


get_immutablue_pip_packages() {
    get_yaml_array '.immutablue.pip_packages'
}


get_immutablue_packages_to_remove() {
    get_yaml_array '.immutablue.rpm_rm'
}


get_immutablue_package_urls() {
    get_yaml_array '.immutablue.rpm_url'
}


get_immutablue_files_to_remove() {
    get_yaml_array '.immutablue.rpm_rm'
}


get_immutablue_system_services_to_unmask() {
    get_yaml_array '.immutablue.services_unmask_sys'
}


get_immutablue_system_services_to_disable() {
    get_yaml_array '.immutablue.services_disable_sys'
}


get_immutablue_system_services_to_enable() {
    get_yaml_array '.immutablue.services_enable_sys'
}


get_immutablue_system_services_to_mask() {
    get_yaml_array '.immutablue.services_mask_sys'
}


get_immutablue_user_services_to_unmask() {
    get_yaml_array '.immutablue.services_unmask_user'
}


get_immutablue_user_services_to_disable() {
    get_yaml_array '.immutablue.services_disable_user'
}


get_immutablue_user_services_to_enable() {
    get_yaml_array '.immutablue.services_enable_user'
}


get_immutablue_user_services_to_mask() {
    get_yaml_array '.immutablue.services_mask_user'
}

