#!/bin/bash
# Fix libvirt VM to disable TPM and Secure Boot
# Usage: ./fix-virsh.sh <vm_name>
#
# This is needed when Cockpit creates a VM with TPM/Secure Boot defaults
# that don't work with unsigned bootloaders (like distroless images)

set -euo pipefail

VM="${1:?Usage: $0 <vm_name>}"

echo "Fixing VM '${VM}' - removing TPM and Secure Boot..."

# Get disk path before undefining
DISK=$(sudo virsh dumpxml "${VM}" 2>/dev/null | grep -oP "source file='\K[^']+\.qcow2" | head -1 || echo "")

if [[ -z "${DISK}" ]]; then
    echo "ERROR: Could not find disk for VM ${VM}"
    exit 1
fi

echo "Found disk: ${DISK}"

# Stop and undefine the VM
sudo virsh destroy "${VM}" 2>/dev/null || true
sudo virsh undefine "${VM}" --nvram 2>/dev/null || true

# Copy OVMF vars template
sudo cp /usr/share/edk2/ovmf/OVMF_VARS.fd "/var/lib/libvirt/qemu/nvram/${VM}_VARS.fd"

# Create new VM XML without TPM/Secure Boot
cat > "/tmp/${VM}-fixed.xml" << VMEOF
<domain type='kvm'>
  <name>${VM}</name>
  <memory unit='KiB'>6291456</memory>
  <currentMemory unit='KiB'>6291456</currentMemory>
  <vcpu placement='static'>2</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-10.1'>hvm</type>
    <loader readonly='yes' type='pflash'>/usr/share/edk2/ovmf/OVMF_CODE.fd</loader>
    <nvram>/var/lib/libvirt/qemu/nvram/${VM}_VARS.fd</nvram>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='on'/>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='${DISK}'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <controller type='usb' index='0' model='qemu-xhci' ports='15'/>
    <controller type='pci' index='0' model='pcie-root'/>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>
    <console type='pty'>
      <target type='virtio' port='0'/>
    </console>
    <channel type='unix'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
    </channel>
    <input type='tablet' bus='usb'/>
    <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'/>
    <video>
      <model type='virtio' heads='1' primary='yes'/>
    </video>
  </devices>
</domain>
VMEOF

# Define and start the VM
sudo virsh define "/tmp/${VM}-fixed.xml"
sudo virsh start "${VM}"

echo "VM '${VM}' fixed and started"
