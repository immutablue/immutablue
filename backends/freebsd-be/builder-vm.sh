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
# Usage:
#   builder-vm.sh <command> [gmake args...]
#
# Commands:
#   create      Download, seed and boot a fresh VM, then prepare it as a build host
#   start       Boot an existing VM
#   stop        Power the VM off
#   ssh [cmd]   Run a command in the VM (interactive shell without one)
#   sync        Copy this checkout into the VM (~/immutablue)
#   make ARGS   sync, then 'sudo gmake ARGS' in the VM
#   deliver     Deliver the built image into a boot environment in the VM
#   destroy     Stop the VM and remove its disk (the download is kept)
#
# Options:
#   -h, --help     Show this help message
#   --license      Show license information
#
# Examples:
#   backends/freebsd-be/builder-vm.sh create
#   backends/freebsd-be/builder-vm.sh make BACKEND=freebsd-be NUCLEUS=1 build
#   backends/freebsd-be/builder-vm.sh make BACKEND=freebsd-be NUCLEUS=1 test
#   backends/freebsd-be/builder-vm.sh deliver
#   backends/freebsd-be/builder-vm.sh ssh 'bectl list'
#
# Environment:
#   FREEBSD_VM_DIR     where the VM lives (default: images/freebsd-vm)
#   FREEBSD_VM_PORT    host port forwarded to the VM's sshd (default: 2222)
#   FREEBSD_VM_MEM     memory in MiB (default: 16384)
#   FREEBSD_VM_CPUS    vCPUs (default: 8)
#
# Host requirements (Fedora package names): qemu-kvm, xorriso,
# openssh-clients, rsync, xz, curl.
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
IMAGE_REF="${FREEBSD_IMAGE_REF:-quay.io/immutablue/immutablue:15.1-freebsd-nucleus}"


show_help() {
    sed -n '2,/^# Exit codes/p' "$0" | sed -e '/^# Exit codes/d' -e 's/^# \{0,1\}//'
}


vm_ssh() {
    ssh -i "${VM_DIR}/vmkey" -p "${PORT}" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o BatchMode=yes builder@127.0.0.1 "$@"
}


vm_start() {
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

    # Wait for sshd and, on first boot, for cloud-init to grant sudo.
    local i
    for i in $(seq 1 120)
    do
        if vm_ssh 'sudo -n true' 2>/dev/null
        then
            echo "VM up (ssh port ${PORT})"
            return 0
        fi
        sleep 5
    done
    echo "ERROR: VM did not come up; see ${VM_DIR}/serial.log" >&2
    return 1
}


vm_stop() {
    if [[ -f "${VM_DIR}/qemu.pid" ]] && kill -0 "$(cat "${VM_DIR}/qemu.pid")" 2>/dev/null
    then
        vm_ssh 'sudo shutdown -p now' > /dev/null 2>&1 || kill "$(cat "${VM_DIR}/qemu.pid")"
    fi
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
    qemu-img resize -q "${VM_DIR}/builder.qcow2" 80G

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

    vm_start

    # Build host requirements: podman + ocijail, GNU make, the repository's
    # tools, /bin/bash for its scripts, a ZFS dataset for container storage,
    # fdescfs, and pf NAT for container networking.
    vm_ssh 'sudo sh -s' <<'EOF'
set -e
env ASSUME_ALWAYS_YES=yes pkg install -y podman-suite ocijail gmake bash git go-yq jq rsync curl skopeo hs-ShellCheck just parallel
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


# Copy the checkout in. deps/ and the submodule histories stay behind:
# freebsd-be builds no in-house dependencies.
vm_sync() {
    rsync -a --delete \
        --exclude /images/ --exclude /deps/ \
        --exclude /.git/modules/deps/ --exclude /.git/modules/artifacts/ \
        --exclude /docs/public/ \
        -e "ssh -i ${VM_DIR}/vmkey -p ${PORT} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes" \
        "${ROOT_DIR}/" builder@127.0.0.1:immutablue/
}


main() {
    local cmd="${1:-}"

    case "${cmd}" in
        -h|--help) show_help; return 0 ;;
        --license) echo 'builder-vm.sh - part of Immutablue. AGPL-3.0-or-later.'; return 0 ;;
        create) vm_create ;;
        start) vm_start ;;
        stop) vm_stop ;;
        ssh) shift; vm_ssh "$@" ;;
        sync) vm_sync ;;
        make)
            shift
            vm_sync
            # Arguments are passed through; quote each for the remote shell.
            vm_ssh "cd immutablue && sudo gmake $(printf '%q ' "$@")"
            ;;
        deliver)
            vm_sync
            vm_ssh "cd immutablue && sudo bash backends/freebsd-be/deliver.sh $(printf '%q' "${IMAGE_REF}")"
            ;;
        destroy)
            vm_stop
            sleep 3
            rm -f "${VM_DIR}/builder.qcow2" "${VM_DIR}/seed.iso" "${VM_DIR}/qemu.pid"
            ;;
        *) show_help >&2; return 2 ;;
    esac
}


main "$@"
