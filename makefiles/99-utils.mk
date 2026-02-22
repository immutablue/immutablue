# ==============================================================================
# Immutablue Build System - Utility Macros and Functions
# ==============================================================================
# This file contains reusable templates and helper functions used throughout
# the build system.
# ==============================================================================

# ------------------------------------------------------------------------------
# Containerized QEMU Run Template
# ------------------------------------------------------------------------------
# QEMU in a container (qemux/qemu) for running images without native QEMU
# Parameters: $(1) = disk file path
# ------------------------------------------------------------------------------
define CONTAINERIZED_QEMU_TEMPLATE
podman run --rm --cap-add NET_ADMIN \
	-p 127.0.0.1:8006:8006 \
	--env CPU_CORES=8 --env RAM_SIZE=8G --env DISK_SIZE=64G --env BOOT_MODE=uefi \
	--device=/dev/kvm \
	--device=/dev/net/tun \
	-v $(1):/boot.img:Z \
	docker.io/qemux/qemu
endef

# ------------------------------------------------------------------------------
# PHONY Target List
# ------------------------------------------------------------------------------
# Accumulated list of all PHONY targets (populated by other files)
# ------------------------------------------------------------------------------
ALL_PHONY_TARGETS := list tag-string all all_upgrade install update upgrade install_or_update reboot \
	build push iso iso-config raw raw-config ami ami-config gce gce-config vhd vhd-config vmdk vmdk-config anaconda-iso anaconda-iso-config \
	upgrade rebase clean \
	install_distrobox install_flatpak install_brew \
	post_install_notes test test_container test_container_qemu test_artifacts test_shellcheck test_setup \
	test_kuberblue_container test_kuberblue_cluster test_kuberblue_components test_kuberblue_integration test_kuberblue_security test_kuberblue test_kuberblue_chainsaw test_chainsaw \
	sbom qcow2 qcow2-config run_qcow2 lima lima-start lima-shell lima-stop lima-delete run_iso run_iso_qemu run_raw run_raw_qemu push_raw push_ami push_gce push_vhd push_vmdk \
	_check_not_distroless distroless-img run-distroless-img distroless-qcow2 distroless-clean \
	build-deps push-deps build-cyan-deps push-cyan-deps retag flatpak_refs/flatpaks push_iso \
	run_all_tests pre_test post_install install_services fix-virsh manifest manifest_rm
