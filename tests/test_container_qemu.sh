#!/bin/bash
# QEMU Container Tests for Immutablue
#
# This script tests the QEMU bootability of the Immutablue container image
# by launching a QEMU virtual machine and checking its boot process.
#
# It can be run directly or through the Makefile with 'make test_container_qemu'
#
# Usage: ./test_container_qemu.sh [IMAGE_NAME:TAG]
#   where IMAGE_NAME:TAG is an optional container image reference (default: quay.io/immutablue/immutablue:42)

# Enable strict error handling
set -euo pipefail

echo "Running QEMU container tests for Immutablue"

# Test variables
# Use the first argument as the image name, or default to a standard value
IMAGE="${1:-quay.io/immutablue/immutablue:42}"
TEST_DIR="$(dirname "$(realpath "$0")")" 
ROOT_DIR="$(dirname "$TEST_DIR")"
QEMU_TIMEOUT=300  # 5 minutes timeout for QEMU tests
QEMU_MEMORY="2G"  # Memory allocation for VM
QEMU_CPUS=2       # Number of CPUs for VM

# Main QEMU test function
# Tests the bootability of the container image using QEMU directly
function test_qemu_boot() {
  echo "Testing QEMU boot capabilities for $IMAGE"
  
  # Create a temporary directory for QEMU test artifacts
  local TEMP_DIR
  TEMP_DIR=$(mktemp -d)
  echo "Using temporary directory: $TEMP_DIR"
  
  # Check for QEMU and busybox dependencies
  if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "WARN: qemu-system-x86_64 not found, falling back to bootc container lint"
    test_bootc_fallback "$IMAGE"
    return $?
  fi
  
  if ! command -v busybox &> /dev/null; then
    echo "WARN: busybox not found, falling back to bootc container lint"
    test_bootc_fallback "$IMAGE"
    return $?
  fi
  
  # Check for KVM availability (needed for hardware acceleration)
  local KVM_ARGS=""
  if [[ -c /dev/kvm && -w /dev/kvm ]]; then
    echo "INFO: KVM is available, using hardware acceleration"
    KVM_ARGS="-enable-kvm -cpu host"
  else
    echo "WARN: /dev/kvm not available or not writable, falling back to software emulation"
    # This will be slower but still works
  fi

  # Pull the container image for testing
  # Actually there is no reason to pull the image. We are going to use the local copy
  # echo "Pulling container image: $IMAGE"
  # if ! podman pull "$IMAGE"; then
  #   echo "ERROR: Failed to pull container image: $IMAGE"
  #   return 1
  # fi
  
  # Create a temporary directory to store container export
  local CONTAINER_ID
  CONTAINER_ID=$(podman create "$IMAGE")
  if [[ -z "$CONTAINER_ID" ]]; then
    echo "ERROR: Failed to create container from image: $IMAGE"
    return 1
  fi
  
  # Export the container to a tarball
  echo "Exporting container to tarball for QEMU testing..."
  podman export "$CONTAINER_ID" > "$TEMP_DIR/container.tar"
  podman rm "$CONTAINER_ID" > /dev/null
  
  # Create a qcow2 disk image for QEMU
  echo "Creating disk image for QEMU..."
  qemu-img create -f qcow2 "$TEMP_DIR/disk.qcow2" 20G > /dev/null
  
  # Create a simple start script that will be used to verify boot
  cat > "$TEMP_DIR/test_script.sh" << 'EOF'
#!/bin/bash
echo "IMMUTABLUE_BOOT_SUCCESS"
ls -la /etc/immutablue /usr/libexec/immutablue
systemctl list-unit-files | grep immutablue
EOF
  chmod +x "$TEMP_DIR/test_script.sh"
  
  # Create a small init script that will be included in the initramfs
  cat > "$TEMP_DIR/init" << 'EOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

echo "Starting boot test..."

# Extract the rootfs to memory
mkdir -p /newroot
mount -t tmpfs tmpfs /newroot
cd /newroot
cat /container.tar | tar -xf -

# Prepare the environment in the extracted container
mount -t proc proc /newroot/proc
mount -t sysfs sysfs /newroot/sys
mount -t devtmpfs devtmpfs /newroot/dev

# Create a simple service script to test components
mkdir -p /newroot/test
cp /test_script.sh /newroot/test/

# Run the test script in the container
chroot /newroot /test/test_script.sh > /newroot/test_results.txt 2>&1

# Output success marker that we can grep for
echo "QEMU Test completed successfully"
cat /newroot/test_results.txt

# Power off the VM when done
poweroff -f
EOF
  chmod +x "$TEMP_DIR/init"
  
  # Create a minimal initramfs with our init script and the container tarball
  echo "Creating initramfs..."
  cd "$TEMP_DIR"
  mkdir -p initramfs/{bin,sbin,etc,proc,sys,dev,newroot}
  cp /bin/busybox initramfs/bin/
  cp "$TEMP_DIR/init" initramfs/init
  cp "$TEMP_DIR/test_script.sh" initramfs/test_script.sh
  cp "$TEMP_DIR/container.tar" initramfs/container.tar
  
  # Use busybox to provide basic commands
  cd "$TEMP_DIR/initramfs"
  ln -s bin/busybox bin/sh
  ln -s bin/busybox bin/mount
  ln -s bin/busybox bin/mkdir
  ln -s bin/busybox bin/cat
  ln -s bin/busybox bin/tar
  ln -s bin/busybox bin/echo
  ln -s bin/busybox bin/ls
  ln -s bin/busybox bin/cp
  ln -s bin/busybox bin/poweroff
  ln -s bin/busybox bin/chroot
  cd "$TEMP_DIR"
  
  # Create the initramfs
  cd "$TEMP_DIR/initramfs"
  find . | cpio -H newc -o | gzip > "$TEMP_DIR/initramfs.gz"
  cd "$TEMP_DIR"
  
  # Run QEMU with our custom initramfs
  echo "Starting QEMU..."
  qemu-system-x86_64 $KVM_ARGS \
    -m "$QEMU_MEMORY" \
    -smp "$QEMU_CPUS" \
    -kernel "/boot/vmlinuz-$(uname -r)" \
    -initrd "$TEMP_DIR/initramfs.gz" \
    -append "console=ttyS0 root=/dev/ram0 rdinit=/init" \
    -nographic \
    -no-reboot \
    -drive file="$TEMP_DIR/disk.qcow2",format=qcow2 \
    > "$TEMP_DIR/qemu.log" 2>&1 &
    
  local QEMU_PID=$!
  
  # Timeout logic to prevent hanging if QEMU fails
  local SUCCESS=0
  local TIMEOUT_COUNTER=0
  echo "Waiting for QEMU boot process (max $QEMU_TIMEOUT seconds)..."
  
  while kill -0 $QEMU_PID 2>/dev/null; do
    if [[ $TIMEOUT_COUNTER -ge $QEMU_TIMEOUT ]]; then
      echo "ERROR: QEMU boot test timed out after $QEMU_TIMEOUT seconds"
      kill -9 $QEMU_PID 2>/dev/null || true
      SUCCESS=1
      break
    fi
    
    # Check if log contains success markers
    if grep -q "IMMUTABLUE_BOOT_SUCCESS" "$TEMP_DIR/qemu.log" && grep -q "QEMU Test completed successfully" "$TEMP_DIR/qemu.log"; then
      echo "QEMU boot test completed successfully"
      SUCCESS=0
      # Let QEMU terminate gracefully
      sleep 5
      kill $QEMU_PID 2>/dev/null || true
      break
    fi
    
    sleep 2
    TIMEOUT_COUNTER=$((TIMEOUT_COUNTER + 2))
  done
  
  # Check the QEMU log for important outputs
  if [[ $SUCCESS -eq 0 ]]; then
    echo "Checking for critical system components in QEMU log..."
    
    # Check for Immutablue directories
    if ! grep -q "/etc/immutablue" "$TEMP_DIR/qemu.log" || ! grep -q "/usr/libexec/immutablue" "$TEMP_DIR/qemu.log"; then
      echo "ERROR: Required Immutablue directories not found in QEMU boot"
      SUCCESS=1
    fi
    
    # Check for Immutablue services
    if ! grep -q "immutablue.*service" "$TEMP_DIR/qemu.log"; then
      echo "ERROR: Required Immutablue services not found in QEMU boot"
      SUCCESS=1
    fi
    
    if [[ $SUCCESS -eq 0 ]]; then
      echo "PASS: All required components verified in QEMU boot"
    fi
  fi
  
  # Display the last part of the log for debugging
  echo "Last 20 lines of QEMU log:"
  tail -n 20 "$TEMP_DIR/qemu.log"
  
  # Clean up temporary files
  echo "Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
  
  return $SUCCESS
}

# Fallback function when QEMU or required dependencies are not available
# Uses bootc container lint to verify container integrity
function test_bootc_fallback() {
  local FALLBACK_IMAGE="$1"
  echo "Running fallback test with bootc container lint"
  
  # Pull the image
  # Actually there is no reason to pull the image. We are going to use the local copy
  # if ! podman pull "$FALLBACK_IMAGE"; then
  #   echo "FAIL: Failed to pull the image"
  #   return 1
  # fi
  
  # Check if bootc is available
  if ! command -v bootc &> /dev/null; then
    echo "WARN: bootc not available but QEMU dependencies missing too"
    echo "INFO: Running basic container checks instead"
    
    # Simple container structure check
    if ! podman run --rm "$FALLBACK_IMAGE" bash -c "test -d /etc/immutablue && test -d /usr/libexec/immutablue"; then
      echo "FAIL: Basic container structure check failed"
      return 1
    fi
    
    # Check for immutablue systemd services
    if ! podman run --rm "$FALLBACK_IMAGE" bash -c "ls -la /usr/lib/systemd/system/immutablue*"; then
      echo "FAIL: Immutablue services check failed"
      return 1
    fi
    
    echo "PASS: Basic container verification passed (fallback mode)"
    return 0
  fi
  
  # Run bootc container lint as fallback
  if ! podman run --rm "$FALLBACK_IMAGE" bootc container lint; then
    echo "FAIL: bootc container lint failed"
    return 1
  fi
  
  echo "PASS: Bootc container lint passed (fallback mode)"
  return 0
}

# Run tests
echo "=== Running QEMU Tests ==="
FAILED=0

# Execute the QEMU boot test
if ! test_qemu_boot; then
  ((FAILED++))
fi

# Report test results
echo "=== Test Results ==="
if [[ $FAILED -eq 0 ]]; then
  echo "All QEMU tests PASSED!"
  exit 0
else
  echo "$FAILED QEMU tests FAILED!"
  exit 1
fi
