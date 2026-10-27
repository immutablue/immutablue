# ==============================================================================
# Immutablue Build System - Backend Selection
# ==============================================================================
# A backend is the operating system Immutablue is layered onto. Each lives in
# backends/<name>/ with its own Containerfile, deps Containerfile and
# backend.yaml; see backends/lib/interface.sh for the contract.
#
#   make build                          # BACKEND=fedora-bootc (default)
#   make BACKEND=arch-bootc build
#
# Included after 20-variants-logic.mk, so variant flags that imply a backend
# have already been applied.
# ==============================================================================

BACKEND_DIR := backends/$(BACKEND)

# Base image set by backends/<backend>/backend.mk wins over the Fedora base
# images the variant flags (NUCLEUS, ...) select.
ifdef BACKEND_BASE_IMAGE
    BASE_IMAGE := $(BACKEND_BASE_IMAGE)
endif
ifdef BACKEND_BASE_IMAGE_TAG
    BASE_IMAGE_TAG := $(BACKEND_BASE_IMAGE_TAG)
endif

# Backends that build the in-house C projects get the digest-pinned deps image;
# the others build against their Containerfile's empty 'no-deps' stage.
BACKEND_INHOUSE_DEPS := $(shell yq '.provides // [] | contains(["inhouse_deps"])' $(BACKEND_DIR)/backend.yaml 2>/dev/null)
CONTAINERFILE := $(BACKEND_DIR)/Containerfile
# A backend may reuse another backend's deps image (gnomeos runs the binaries
# built for Fedora): backend.yaml 'deps_backend'.
BACKEND_DEPS_FROM := $(shell yq '.deps_backend // "$(BACKEND)"' $(BACKEND_DIR)/backend.yaml 2>/dev/null)
DEPS_CONTAINERFILE := backends/$(or $(BACKEND_DEPS_FROM),$(BACKEND))/deps.Containerfile

# ------------------------------------------------------------------------------
# backend_check: refuse a build that cannot work before podman starts.
#
# Verifies the backend exists, that this host can build it, and that every
# build option is supported by it (variants/<option>.yaml 'requires').
# ------------------------------------------------------------------------------
.PHONY: backend_check
backend_check:
	@bash scripts/check-backend.sh "$(BACKEND)" "$(BUILD_OPTIONS)"

.PHONY: backend
backend:
	@echo "$(BACKEND)"

# ------------------------------------------------------------------------------
# bootc-disk-image: a UEFI-bootable raw disk from the built image, for bootc
# backends bootc-image-builder does not support (arch-bootc). Uses
# 'bootc install to-disk' from the image itself; needs sudo.
#
#   make BACKEND=arch-bootc NUCLEUS=1 bootc-disk-image
#   make BACKEND=arch-bootc NUCLEUS=1 run-bootc-disk-image
# ------------------------------------------------------------------------------
BOOTC_DISK_IMAGE := ./images/disk/$(TAG).img
OVMF_CODE ?= /usr/share/edk2/ovmf/OVMF_CODE.fd

.PHONY: bootc-disk-image run-bootc-disk-image
bootc-disk-image:
	bash backends/lib/bootc-disk-image.sh "$(IMAGE):$(TAG)" "$(BOOTC_DISK_IMAGE)"

run-bootc-disk-image:
	qemu-system-x86_64 -machine q35 -enable-kvm -cpu host -m 4096 -smp 2 \
		-drive if=pflash,format=raw,readonly=on,file=$(OVMF_CODE) \
		-drive file=$(BOOTC_DISK_IMAGE),format=raw,if=virtio \
		-nic user,model=virtio-net-pci \
		-nographic

# A backend without a deps.Containerfile (freebsd-be, for now) has no deps
# image to build; say so instead of failing inside buildah.
$(DEPS_CONTAINERFILE):
	@echo "ERROR: BACKEND=$(BACKEND) has no deps container ($(DEPS_CONTAINERFILE) does not exist)" >&2
	@exit 1
