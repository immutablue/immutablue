#!/bin/bash
# builder-vm.sh - A FreeBSD 15.1 VM that builds freebsd-be images from Linux
#
# freebsd-be images can only be built on FreeBSD (podman + ocijail). This runs
# one under QEMU/KVM on the Linux workstation: it downloads the official
# FreeBSD 15.1-RELEASE BASIC-CLOUDINIT ZFS image (checksum-verified), seeds it
# with an SSH key and passwordless sudo through cloud-init, installs the build
# host requirements, and then runs gmake targets in it against a synced copy
# of this checkout. The VM is also a real ZFS FreeBSD system, so deliver.sh
# and the immutablue-backend verbs can be exercised on it.
#
# By default the VM is a plain QEMU process (SSH on a forwarded localhost
# port). With --libvirt it is a libvirt domain on qemu:///system instead --
# visible and usable in virt-manager, with a SPICE console -- on the 'default'
# NAT network, and SSH goes to its DHCP address.
#
# Usage:
#   builder-vm.sh [--libvirt] <command> [gmake args...]
#
# Commands:
#   create      Download, seed and boot a fresh VM, then prepare it as a build host
#   import      (--libvirt) Turn an existing QEMU-mode VM's disk into the domain
#   install     (--libvirt) Install FREEBSD_IMAGE_REF onto a fresh disk with
#               install-disk.sh and define it as its own domain
#               (FREEBSD_INSTALL_DOMAIN, default immutablue-freebsd)
#   start       Boot an existing VM
#   stop        Power the VM off
#   ssh [cmd]   Run a command in the VM (interactive shell without one)
#   sync        Copy this checkout into the VM (~/immutablue)
#   make ARGS   sync, then 'sudo gmake ARGS' in the VM
#   delegate [--push REGISTRY] ARGS
#               What 'make' runs on a Linux host for freebsd-be's build, test,
#               push, build-deps and push-deps: finds the VM (the libvirt
#               domain, else the QEMU disk), starts it if needed, and runs
#               'make ARGS' in it. With no VM it prints how to create one;
#               with --push it first checks the VM is logged in to REGISTRY
#   deliver     Deliver the built image into a boot environment in the VM
#   iso OUT     Build an installer ISO of FREEBSD_IMAGE_REF in the VM with
#               make-iso.sh and copy it back to OUT
#   destroy     Stop the VM and remove its disk (the download is kept)
#
# Options:
#   --libvirt      Run the VM as a libvirt domain (also: FREEBSD_VM_LIBVIRT=1)
#   -h, --help     Show this help message
#   --license      Show license information
#
# Examples:
#   backends/freebsd-be/builder-vm.sh create
#   backends/freebsd-be/builder-vm.sh make BACKEND=freebsd-be NUCLEUS=1 build
#   backends/freebsd-be/builder-vm.sh make BACKEND=freebsd-be NUCLEUS=1 test
#   backends/freebsd-be/builder-vm.sh deliver
#   make FREEBSD=1 NUCLEUS=1 build      # on Linux: delegated to this VM
#   backends/freebsd-be/builder-vm.sh ssh 'bectl list'
#   backends/freebsd-be/builder-vm.sh --libvirt create
#   backends/freebsd-be/builder-vm.sh --libvirt import
#   backends/freebsd-be/builder-vm.sh --libvirt make BACKEND=freebsd-be build
#   FREEBSD_IMAGE_REF=quay.io/immutablue/immutablue:15.1-freebsd \
#       backends/freebsd-be/builder-vm.sh --libvirt install
#
# Environment:
#   FREEBSD_VM_DIR     where the VM lives (default: images/freebsd-vm)
#   FREEBSD_VM_PORT    host port forwarded to the VM's sshd (default: 2222)
#   FREEBSD_VM_MEM     memory in MiB (default: 16384)
#   FREEBSD_VM_CPUS    vCPUs (default: 8)
#   FREEBSD_VM_DISK    disk size (default: 120G; a GNOME build plus its
#                      squash and a delivered boot environment need ~70G)
#   FREEBSD_VM_DOMAIN  libvirt domain name (default: immutablue-freebsd-builder)
#   FREEBSD_INSTALL_DOMAIN  domain 'install' creates (default: immutablue-freebsd)
#   FREEBSD_INSTALL_DISK    its disk size (default: 60G)
#   FREEBSD_VM_MIN_FREE_GB  free space 'make' needs in the VM after its
#                      cleanup of old images (default: 50)
#   FREEBSD_INSTALL_SSH_KEY a public key installed for root on that machine
#   FREEBSD_ISO_AUTOINSTALL  disk the ISO installs to unattended (tests only)
#   LIBVIRT_DEFAULT_URI  libvirt connection (default: qemu:///system)
#
# Host requirements (Fedora package names): qemu-kvm, xorriso,
# openssh-clients, rsync, xz, curl; for --libvirt also libvirt-daemon-kvm,
# virt-install and jq, and membership of the 'libvirt' group.
#
# Exit codes:
#   0 - Success
#   1 - A step failed
#   2 - Usage error

set -euo pipefail

RELEASE="15.1-RELEASE"
IMAGE_NAME="FreeBSD-${RELEASE}-amd64-BASIC-CLOUDINIT-zfs.qcow2"
BASE_URL="https://download.freebsd.org/releases/VM-IMAGES/${RELEASE}/amd64/Latest"
ROOT_DIR="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VM_DIR="${FREEBSD_VM_DIR:-${ROOT_DIR}/images/freebsd-vm}"
PORT="${FREEBSD_VM_PORT:-2222}"
MEM="${FREEBSD_VM_MEM:-16384}"
CPUS="${FREEBSD_VM_CPUS:-8}"
DISK="${FREEBSD_VM_DISK:-120G}"
IMAGE_REF="${FREEBSD_IMAGE_REF:-quay.io/immutablue/immutablue:15.1-freebsd-nucleus}"
LIBVIRT="${FREEBSD_VM_LIBVIRT:-0}"
LIBVIRT_CHOSEN=0
DOMAIN="${FREEBSD_VM_DOMAIN:-immutablue-freebsd-builder}"
URI="${LIBVIRT_DEFAULT_URI:-qemu:///system}"
INSTALL_DOMAIN="${FREEBSD_INSTALL_DOMAIN:-immutablue-freebsd}"
INSTALL_DISK="${FREEBSD_INSTALL_DISK:-60G}"
MIN_FREE_GB="${FREEBSD_VM_MIN_FREE_GB:-50}"


show_help() {
    sed -n '2,/^# Exit codes/p' "$0" | sed -e '/^# Exit codes/d' -e 's/^# \{0,1\}//'
}


vsh() {
    virsh -q -c "${URI}" "$@"
}


# Where sshd is reachable: the forwarded localhost port for a QEMU VM, the
# DHCP lease on libvirt's 'default' network for a domain.
#
# returns: "<host> <port>" on stdout (host empty while no lease exists)
vm_target() {
    local ip

    if [[ "${LIBVIRT}" -eq 1 ]]
    then
        ip="$(vsh domifaddr "${DOMAIN}" --source lease 2>/dev/null | awk '$3 == "ipv4" { sub(/\/.*/, "", $4); print $4; exit }')"
        echo "${ip} 22"
    else
        echo "127.0.0.1 ${PORT}"
    fi
}


vm_ssh() {
    local host
    local port

    read -r host port < <(vm_target)
    [[ -n "${host}" ]] || return 255
    ssh -i "${VM_DIR}/vmkey" -p "${port}" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o BatchMode=yes "builder@${host}" "$@"
}


# Wait for sshd and, on first boot, for cloud-init to grant sudo.
vm_wait() {
    local i

    for i in $(seq 1 120)
    do
        if vm_ssh 'sudo -n true' 2>/dev/null
        then
            echo "VM up ($(vm_target))"
            return 0
        fi
        sleep 5
    done
    echo "ERROR: VM did not come up" >&2
    return 1
}


vm_start() {
    if [[ "${LIBVIRT}" -eq 1 ]]
    then
        if [[ "$(vsh domstate "${DOMAIN}")" != "running" ]]
        then
            vsh start "${DOMAIN}"
        fi
        vm_wait
        return
    fi

    if [[ -f "${VM_DIR}/qemu.pid" ]] && kill -0 "$(cat "${VM_DIR}/qemu.pid")" 2>/dev/null
    then
        echo "VM already running"
        return 0
    fi
    : > "${VM_DIR}/serial.log"
    qemu-system-x86_64 -machine q35 -enable-kvm -cpu host -m "${MEM}" -smp "${CPUS}" \
        -drive "file=${VM_DIR}/builder.qcow2,format=qcow2,if=virtio" \
        -drive "file=${VM_DIR}/seed.iso,format=raw,if=virtio,readonly=on" \
        -nic "user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${PORT}-:22" \
        -display none -serial "file:${VM_DIR}/serial.log" \
        -daemonize -pidfile "${VM_DIR}/qemu.pid"
    vm_wait
}


# Power off and wait for QEMU to exit, so its forwarded port is free for the
# next start; a VM that does not shut down within a minute is killed.
vm_stop() {
    local pid
    local i

    if [[ "${LIBVIRT}" -eq 1 ]]
    then
        vsh dominfo "${DOMAIN}" > /dev/null 2>&1 || return 0
        [[ "$(vsh domstate "${DOMAIN}")" == "running" ]] || return 0
        vsh shutdown "${DOMAIN}" > /dev/null
        for i in $(seq 1 60)
        do
            [[ "$(vsh domstate "${DOMAIN}")" == "shut off" ]] && return 0
            sleep 1
        done
        vsh destroy "${DOMAIN}" > /dev/null
        return 0
    fi

    [[ -f "${VM_DIR}/qemu.pid" ]] || return 0
    pid="$(cat "${VM_DIR}/qemu.pid")"
    kill -0 "${pid}" 2>/dev/null || return 0

    vm_ssh 'sudo shutdown -p now' > /dev/null 2>&1 || true
    for i in $(seq 1 60)
    do
        kill -0 "${pid}" 2>/dev/null || return 0
        sleep 1
    done
    kill "${pid}" 2>/dev/null || true
    sleep 2
}


# Download and verify the official image, write the cloud-init seed, boot,
# and install the build host requirements.
vm_create() {
    mkdir -p "${VM_DIR}/seed"

    if [[ ! -f "${VM_DIR}/${IMAGE_NAME}.xz" ]]
    then
        curl -fsSL -o "${VM_DIR}/CHECKSUM.SHA256" "${BASE_URL}/CHECKSUM.SHA256"
        curl -fSL -o "${VM_DIR}/${IMAGE_NAME}.xz" "${BASE_URL}/${IMAGE_NAME}.xz"
    fi
    (
        cd "${VM_DIR}"
        grep "(${IMAGE_NAME}.xz)" CHECKSUM.SHA256 | awk -v f="${IMAGE_NAME}.xz" '{ print $4 "  " f }' | sha256sum -c -
    )

    xz -dkc "${VM_DIR}/${IMAGE_NAME}.xz" > "${VM_DIR}/builder.qcow2"
    qemu-img resize -q "${VM_DIR}/builder.qcow2" "${DISK}"

    if [[ ! -f "${VM_DIR}/vmkey" ]]
    then
        ssh-keygen -q -t ed25519 -N '' -f "${VM_DIR}/vmkey" -C immutablue-freebsd-builder
    fi

    # The BASIC-CLOUDINIT image has no sudo; runcmd (run as root on first
    # boot) installs it and grants the builder user passwordless sudo.
    cat > "${VM_DIR}/seed/user-data" <<EOF
#cloud-config
hostname: fbsd-builder
users:
  - name: builder
    groups: wheel
    shell: /bin/sh
    ssh_authorized_keys:
      - $(cat "${VM_DIR}/vmkey.pub")
ssh_pwauth: false
runcmd:
  - env ASSUME_ALWAYS_YES=yes pkg bootstrap -f
  - env ASSUME_ALWAYS_YES=yes pkg install -y sudo
  - mkdir -p /usr/local/etc/sudoers.d
  - echo 'builder ALL=(ALL) NOPASSWD:ALL' > /usr/local/etc/sudoers.d/builder
EOF
    printf 'instance-id: fbsd-builder-%s\nlocal-hostname: fbsd-builder\n' "$(date +%s)" > "${VM_DIR}/seed/meta-data"
    rm -f "${VM_DIR}/seed.iso"
    xorriso -as mkisofs -quiet -o "${VM_DIR}/seed.iso" -V cidata -J -r "${VM_DIR}/seed" 2>/dev/null

    if [[ "${LIBVIRT}" -eq 1 ]]
    then
        vm_import
    else
        vm_start
    fi

    # Build host requirements: podman + ocijail, GNU make, the repository's
    # tools, /bin/bash for its scripts, a ZFS dataset for container storage,
    # fdescfs, and pf NAT for container networking.
    vm_ssh 'sudo sh -s' <<'EOF'
set -e
env ASSUME_ALWAYS_YES=yes pkg install -y podman-suite ocijail gmake bash git go-yq jq rsync curl skopeo hs-ShellCheck just parallel xorriso
ln -sf /usr/local/bin/bash /bin/bash
zfs list zroot/containers > /dev/null 2>&1 || zfs create -o mountpoint=/var/db/containers zroot/containers
grep -q fdescfs /etc/fstab || echo "fdesc /dev/fd fdescfs rw 0 0" >> /etc/fstab
mount | grep -q fdescfs || mount -t fdescfs fdesc /dev/fd
sed -e s/ix0/vtnet0/ /usr/local/etc/containers/pf.conf.sample > /etc/pf.conf
sysrc -q pf_enable=YES
grep -q filter_local /etc/sysctl.conf || echo net.pf.filter_local=1 >> /etc/sysctl.conf
service pf start || true
sysctl net.pf.filter_local=1
EOF
    echo "FreeBSD builder ready"
}


# Make the VM's disk (and cloud-init seed) a libvirt domain and boot it.
#
# The system libvirt cannot read files in a home directory, so
# backends/lib/libvirt-import.sh uploads them into the 'default' pool. The
# local copies are left in place; from here on the pool volume is the disk.
vm_import() {
    local qemu_mode_running=0

    if [[ -f "${VM_DIR}/qemu.pid" ]] && kill -0 "$(cat "${VM_DIR}/qemu.pid")" 2>/dev/null
    then
        qemu_mode_running=1
    fi
    if [[ ${qemu_mode_running} -eq 1 ]]
    then
        echo "Stopping the QEMU-mode VM so its disk is consistent"
        LIBVIRT=0 vm_stop
    fi

    bash "${ROOT_DIR}/backends/lib/libvirt-import.sh" --replace \
        --osinfo "$(yq '.osinfo' "${ROOT_DIR}/backends/freebsd-be/backend.yaml")" --memory "${MEM}" --vcpus "${CPUS}" \
        --seed "${VM_DIR}/seed.iso" "${DOMAIN}" "${VM_DIR}/builder.qcow2"
    vm_wait
}


# Install an image onto a new disk and make that disk its own domain.
#
# A fresh pool volume is hot-plugged into the builder, which runs
# install-disk.sh on it (the builder has the image in its podman storage),
# then unplugged and booted as INSTALL_DOMAIN: a standalone Immutablue
# FreeBSD machine, UEFI with Secure Boot off.
vm_install() {
    local vol="${INSTALL_DOMAIN}.qcow2"
    local path
    local before
    local after
    local dev
    local i

    vm_sync

    if vsh dominfo "${INSTALL_DOMAIN}" > /dev/null 2>&1
    then
        vsh destroy "${INSTALL_DOMAIN}" > /dev/null 2>&1 || true
        vsh undefine "${INSTALL_DOMAIN}" --nvram > /dev/null 2>&1 || vsh undefine "${INSTALL_DOMAIN}" > /dev/null
    fi
    vsh vol-delete --pool default "${vol}" > /dev/null 2>&1 || true
    vsh vol-create-as default "${vol}" "${INSTALL_DISK}" --format qcow2 > /dev/null
    path="$(vsh vol-path --pool default "${vol}")"

    # Which device the new disk becomes inside the builder: whatever appears.
    before="$(vm_ssh 'sysctl -n kern.disks')"
    vsh attach-disk "${DOMAIN}" "${path}" vdz --driver qemu --subdriver qcow2 --targetbus virtio --live
    for i in $(seq 1 30)
    do
        after="$(vm_ssh 'sysctl -n kern.disks')"
        dev="$(comm -13 <(tr ' ' '\n' <<< "${before}" | sort) <(tr ' ' '\n' <<< "${after}" | sort) | head -n 1)"
        [[ -n "${dev}" ]] && break
        sleep 1
    done
    if [[ -z "${dev}" ]]
    then
        echo "ERROR: the new disk did not appear in the builder" >&2
        vsh detach-disk "${DOMAIN}" vdz --live > /dev/null 2>&1 || true
        return 1
    fi
    echo "Installing ${IMAGE_REF} onto the builder's ${dev}"

    local key_opt=""
    if [[ -n "${FREEBSD_INSTALL_SSH_KEY:-}" ]]
    then
        vm_ssh 'cat > /tmp/immutablue-install-key.pub' < "${FREEBSD_INSTALL_SSH_KEY}"
        key_opt="--ssh-key /tmp/immutablue-install-key.pub"
    fi

    if ! vm_ssh "cd immutablue && sudo bash backends/freebsd-be/install-disk.sh --yes ${key_opt} --hostname $(printf '%q' "${INSTALL_DOMAIN}") $(printf '%q' "${IMAGE_REF}") ${dev}"
    then
        vsh detach-disk "${DOMAIN}" vdz --live > /dev/null 2>&1 || true
        return 1
    fi
    vsh detach-disk "${DOMAIN}" vdz --live > /dev/null

    bash "${ROOT_DIR}/backends/lib/libvirt-import.sh" --volume --uefi \
        --osinfo "$(yq '.osinfo' "${ROOT_DIR}/backends/freebsd-be/backend.yaml")" \
        --memory 8192 --vcpus 4 "${INSTALL_DOMAIN}" "${vol}"
}


# Copy the checkout in. The submodule histories stay behind (2.7G), so deps/
# goes across as its tracked files only -- the source build-deps compiles,
# without build output a host checkout may hold -- and the deps manifest,
# which needs those histories, is generated here first
# (DEPS_MANIFEST_PREBUILT=1 on the VM's make).
vm_sync() {
    local host
    local port
    local ssh_cmd

    read -r host port < <(vm_target)
    ssh_cmd="ssh -i ${VM_DIR}/vmkey -p ${port} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes"

    bash "${ROOT_DIR}/scripts/gen-dep-info.sh" "${ROOT_DIR}/deps-container/dep_info.json"
    rsync -a --delete \
        --exclude /images/ --exclude /deps/ \
        --exclude /.git/modules/deps/ --exclude /.git/modules/artifacts/ \
        --exclude /docs/public/ --exclude /iso/ --exclude /.image-source.json \
        -e "${ssh_cmd}" \
        "${ROOT_DIR}/" "builder@${host}:immutablue/"
    git -C "${ROOT_DIR}" ls-files -z --recurse-submodules deps \
        | rsync -a --from0 --files-from=- \
            -e "${ssh_cmd}" \
            "${ROOT_DIR}/" "builder@${host}:immutablue/"
}


# Free the VM's container storage before a build: a GNOME image is ~12 GB,
# a deps image ~9 GB, and the commit of a squashed build needs roughly the
# image's size again on top, so a few builds fill the disk. Removes stopped
# containers and buildah working containers (a failed build leaves its own),
# the dated tags every build adds (<tag>-YYYYMMDD) once a newer build owns
# the undated tag,
# and every image no tag refers to any more. Then refuses to go on with
# less than MIN_FREE_GB free, saying what is left.
vm_cleanup() {
    vm_ssh "sudo sh -s ${MIN_FREE_GB}" <<'CLEAN'
min_gb="$1"
podman container prune -f > /dev/null 2>&1
buildah rm --all > /dev/null 2>&1
# A dated tag goes only when its image is no longer the undated tag's: the
# current build's dated tag is what 'push' sends next to the undated one.
podman images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -E -- '-[0-9]{8} ' | while read -r tag id; do
	current=$(podman image inspect --format '{{.Id}}' "${tag%-*}" 2> /dev/null | cut -c1-12)
	if [ "${current}" != "${id}" ]; then
		podman rmi "${tag}" > /dev/null 2>&1
	fi
done
podman image prune -f > /dev/null 2>&1
# An image replaced under its tag keeps its repository name ('<repo>:<none>')
# and is not dangling to 'prune'; it is just as unreachable.
podman images --format '{{.ID}} {{.Tag}}' | awk '$2 == "<none>" { print $1 }' | xargs -r podman rmi > /dev/null 2>&1
free_kb=$(df -k /var/db/containers | awk 'NR == 2 { print $4 }')
free_gb=$(( free_kb / 1024 / 1024 ))
echo "==> builder VM: ${free_gb} GB free after cleanup" >&2
if [ "${free_gb}" -lt "${min_gb}" ]; then
	echo "ERROR: less than ${min_gb} GB free in the builder VM; images left:" >&2
	podman images --format '  {{.Repository}}:{{.Tag}} {{.Size}}' >&2
	echo "Remove what is not needed (builder-vm.sh ssh 'sudo podman rmi <image>') or lower FREEBSD_VM_MIN_FREE_GB." >&2
	exit 1
fi
CLEAN
}


# Run 'sudo gmake ARGS' in the VM against a fresh sync of this checkout,
# after vm_cleanup (except for push targets).
#
# Every image build leaves the one it replaced untagged (~11 GB for GNOME);
# they are pruned afterwards too. The deps manifest is the one vm_sync
# generated on the host.
#
# param $@: gmake arguments
vm_make() {
    local arg
    local pushing=0

    # Pushes need no space, and the dated tags the cleanup removes are
    # among what push and push-deps send.
    for arg in "$@"
    do
        case "${arg}" in
            push|push-deps) pushing=1 ;;
            *) ;;
        esac
    done
    if [[ ${pushing} -eq 0 ]]
    then
        vm_cleanup
    fi
    vm_sync
    # Arguments are passed through; quote each for the remote shell.
    vm_ssh "cd immutablue && sudo gmake DEPS_MANIFEST_PREBUILT=1 $(printf '%q ' "$@"); rc=\$?; sudo podman image prune -f > /dev/null 2>&1; exit \$rc"
}


# Which builder VM exists. --libvirt or FREEBSD_VM_LIBVIRT decide the mode
# when given; otherwise the libvirt domain wins if one is defined ('import'
# leaves the QEMU disk behind, so the domain is checked first), else the
# QEMU-mode disk.
#
# returns: 0 with LIBVIRT set, 1 when there is no VM
vm_detect() {
    if [[ -n "${FREEBSD_VM_LIBVIRT:-}" ]] || [[ "${LIBVIRT_CHOSEN}" -eq 1 ]]
    then
        if [[ "${LIBVIRT}" -eq 1 ]]
        then
            vsh dominfo "${DOMAIN}" > /dev/null 2>&1
        else
            [[ -f "${VM_DIR}/builder.qcow2" ]]
        fi
        return
    fi

    if command -v virsh > /dev/null && vsh dominfo "${DOMAIN}" > /dev/null 2>&1
    then
        LIBVIRT=1
        return 0
    fi
    if [[ -f "${VM_DIR}/builder.qcow2" ]]
    then
        LIBVIRT=0
        return 0
    fi
    return 1
}


# How to let the VM push: buildah push runs as root there, so root needs the
# registry login (kept in /run/containers/0/auth.json on the VM's disk, so it
# survives reboots).
#
# param $1: registry, e.g. quay.io
print_push_login_help() {
    local registry="$1"
    local flag=""

    if [[ "${LIBVIRT}" -eq 1 ]]
    then
        flag=" --libvirt"
    fi
    cat >&2 <<HELP
To push from the builder VM, log its root user in to ${registry} once:

    backends/freebsd-be/builder-vm.sh${flag} ssh
    sudo podman login ${registry}
HELP
}


# There is no builder VM: say how to make one.
print_create_help() {
    cat >&2 <<HELP
freebsd-be images are built on FreeBSD; on this host 'make' runs them in the
builder VM, and there is none yet (no libvirt domain '${DOMAIN}' and no
${VM_DIR}/builder.qcow2). Create it once -- it downloads FreeBSD 15.1
(~1 GB) and makes a ${DISK} disk:

    backends/freebsd-be/builder-vm.sh --libvirt create   # libvirt domain, visible in virt-manager
    backends/freebsd-be/builder-vm.sh create             # or a plain QEMU process

then run the same make command again.

HELP
}


# 'make' on a Linux host for freebsd-be: run the target in the builder VM.
#
# param --push REGISTRY: (optional) the target pushes to REGISTRY; refuse
#                        early unless the VM is logged in to it
# param $@: gmake arguments (the target and the command-line variables)
vm_delegate() {
    local registry=""
    local where

    if [[ "${1:-}" == "--push" ]]
    then
        registry="$2"
        shift 2
    fi

    if ! vm_detect
    then
        print_create_help
        print_push_login_help "${registry:-quay.io}"
        return 1
    fi

    if [[ "${LIBVIRT}" -eq 1 ]]
    then
        where="libvirt domain ${DOMAIN}"
    else
        where="QEMU, ${VM_DIR}"
    fi
    echo "==> freebsd-be: running 'make $*' in the builder VM (${where})" >&2
    vm_start

    if [[ -n "${registry}" ]] && ! vm_ssh "sudo podman login --get-login $(printf '%q' "${registry}")" > /dev/null 2>&1
    then
        echo "ERROR: the builder VM is not logged in to ${registry}" >&2
        print_push_login_help "${registry}"
        return 1
    fi

    vm_make "$@"
}


# Build an installer ISO of IMAGE_REF in the VM and copy it to the host.
#
# param $1: output path on the host
vm_iso() {
    local out="$1"
    local remote="/var/tmp/immutablue-installer.iso"
    local auto=""
    local host
    local port

    vm_sync
    if [[ -n "${FREEBSD_ISO_AUTOINSTALL:-}" ]]
    then
        auto="--autoinstall $(printf '%q' "${FREEBSD_ISO_AUTOINSTALL}")"
    fi
    vm_ssh "cd immutablue && sudo bash backends/freebsd-be/make-iso.sh ${auto} $(printf '%q' "${IMAGE_REF}") ${remote}"
    read -r host port < <(vm_target)
    mkdir -p "$(dirname "${out}")"
    scp -i "${VM_DIR}/vmkey" -P "${port}" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o BatchMode=yes "builder@${host}:${remote}" "${out}"
    vm_ssh "sudo rm -f ${remote}"
    echo "ISO: ${out}"
}


main() {
    if [[ "${1:-}" == "--libvirt" ]]
    then
        LIBVIRT=1
        LIBVIRT_CHOSEN=1
        shift
    fi
    local cmd="${1:-}"

    case "${cmd}" in
        -h|--help) show_help; return 0 ;;
        --license) echo 'builder-vm.sh - part of Immutablue. AGPL-3.0-or-later.'; return 0 ;;
        create) vm_create ;;
        import)
            if [[ "${LIBVIRT}" -ne 1 ]]
            then
                echo "import makes the libvirt domain: use --libvirt import" >&2
                return 2
            fi
            vm_import
            ;;
        install)
            if [[ "${LIBVIRT}" -ne 1 ]]
            then
                echo "install needs --libvirt (the new disk becomes a libvirt domain)" >&2
                return 2
            fi
            vm_install
            ;;
        start) vm_start ;;
        stop) vm_stop ;;
        ssh) shift; vm_ssh "$@" ;;
        sync) vm_sync ;;
        make)
            shift
            vm_make "$@"
            ;;
        delegate)
            shift
            vm_delegate "$@"
            ;;
        deliver)
            vm_sync
            vm_ssh "cd immutablue && sudo bash backends/freebsd-be/deliver.sh $(printf '%q' "${IMAGE_REF}")"
            ;;
        iso)
            if [[ $# -ne 2 ]]
            then
                echo "usage: builder-vm.sh iso <output.iso>" >&2
                return 2
            fi
            if ! vm_detect
            then
                print_create_help
                return 1
            fi
            vm_start
            vm_iso "$2"
            ;;
        destroy)
            vm_stop
            if [[ "${LIBVIRT}" -eq 1 ]]
            then
                vsh undefine "${DOMAIN}" --nvram > /dev/null 2>&1 || vsh undefine "${DOMAIN}" > /dev/null 2>&1 || true
                vsh vol-delete --pool default "${DOMAIN}.qcow2" > /dev/null 2>&1 || true
                vsh vol-delete --pool default "${DOMAIN}-seed.iso" > /dev/null 2>&1 || true
            fi
            rm -f "${VM_DIR}/builder.qcow2" "${VM_DIR}/seed.iso" "${VM_DIR}/qemu.pid"
            ;;
        *) show_help >&2; return 2 ;;
    esac
}


main "$@"
