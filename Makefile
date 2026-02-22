# ==============================================================================
# Immutablue Build System
# ==============================================================================
# A modular, customizable Fedora Silverblue image builder.
#
# Quick Start:
#   make build                    # Build default image
#   make CYAN=1 build             # Build NVIDIA variant
#   make test                     # Run tests
#   make help                     # Show available targets
#
# For full documentation, see docs/ or run 'make help'
# ==============================================================================

MAKEFLAGS += --no-builtin-rules
SHELL := /bin/bash

# ==============================================================================
# Include Modules (order matters)
# ==============================================================================
include makefiles/00-variables.mk
include makefiles/10-variants-data.mk
include makefiles/20-variants-logic.mk
include makefiles/99-utils.mk
include makefiles/30-build.mk
include makefiles/40-images.mk
include makefiles/50-tests.mk
include makefiles/60-vm.mk
include makefiles/70-install.mk

# ==============================================================================
# Utility Targets
# ==============================================================================
list:
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | grep -E -v -e '^[^[:alnum:]]' -e '^@$$'

tag-string:
	@echo "$(TAG)"

help:
	@echo "Immutablue Build System"
	@echo ""
	@echo "Usage: make [VARIABLE=value] <target>"
	@echo ""
	@echo "Build Targets:"
	@echo "  build              Build container image"
	@echo "  push               Push image to registry"
	@echo "  build-deps         Build dependency container"
	@echo ""
	@echo "Image Generation:"
	@echo "  iso                Generate ISO (bootc-image-builder)"
	@echo "  CLASSIC_ISO=1 iso  Generate ISO (build-container-installer)"
	@echo "  raw                Generate raw disk image"
	@echo "  ami                Generate AMI (Amazon)"
	@echo "  gce                Generate GCE (Google Cloud)"
	@echo "  vhd                Generate VHD (Azure/Hyper-V)"
	@echo "  vmdk               Generate VMDK (VMware)"
	@echo "  qcow2              Generate QCOW2 (QEMU)"
	@echo ""
	@echo "VM Targets:"
	@echo "  lima               Generate Lima VM config"
	@echo "  lima-start         Start Lima VM"
	@echo "  lima-shell         Shell into Lima VM"
	@echo "  lima-stop          Stop Lima VM"
	@echo ""
	@echo "Test Targets:"
	@echo "  test               Run all tests"
	@echo "  pre_test           Run pre-build shellcheck"
	@echo "  test_container     Run container tests"
	@echo "  test_artifacts     Run artifact tests"
	@echo ""
	@echo "Install/Update:"
	@echo "  install            Install packages"
	@echo "  update             Update system"
	@echo "  rebase             Rebase to new image"
	@echo ""
	@echo "Variant Flags:"
	@echo "  NUCLEUS=1          Minimal (no GUI)"
	@echo "  KINOITE=1          KDE Plasma"
	@echo "  SERICEA=1          Sway"
	@echo "  CYAN=1             NVIDIA support"
	@echo "  ASAHI=1            Apple Silicon"
	@echo "  LTS=1              LTS kernel"
	@echo "  ZFS=1              ZFS modules"
	@echo "  NIX=1              Nix package manager"
	@echo "  KUBERBLUE=1        Kubernetes support"
	@echo "  TRUEBLUE=1         ZFS + LTS"
	@echo ""
	@echo "Examples:"
	@echo "  make CYAN=1 build"
	@echo "  make TRUEBLUE=1 LTS=1 build"
	@echo "  make KUBERBLUE=1 test"
	@echo ""
	@echo "Options:"
	@echo "  SKIP_TEST=1        Skip tests"
	@echo "  VERSION=42         Fedora version"
	@echo "  PLATFORM=linux/arm64"
	@echo ""
	@echo "Run 'make list' for all targets"

.PHONY: $(ALL_PHONY_TARGETS) help
