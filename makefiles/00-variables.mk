# ==============================================================================
# Immutablue Build System - Core Variables
# ==============================================================================
# This file contains all fundamental variable definitions used throughout
# the build system. Variables are organized by category.
# ==============================================================================

# ------------------------------------------------------------------------------
# Registry and Image Configuration
# ------------------------------------------------------------------------------
ifndef REGISTRY
    REGISTRY := quay.io/immutablue
endif

BASE_IMAGE := quay.io/fedora-ostree-desktops/silverblue
IMAGE_BASE_TAG := immutablue
IMAGE := $(REGISTRY)/$(IMAGE_BASE_TAG)
CURRENT := 43
MANIFEST := $(IMAGE_BASE_TAG)
VARIANT := Silverblue

# ------------------------------------------------------------------------------
# Build Configuration
# ------------------------------------------------------------------------------
ifndef GUI_FLAVOR
    GUI_FLAVOR := silverblue
endif

ifndef BUILD_OPTIONS
    BUILD_OPTIONS := gui,silverblue
endif

ifndef PLATFORM
    PLATFORM := linux/amd64
endif

ifndef VERSION
    VERSION = $(CURRENT)
endif

ifndef TAG
    TAG = $(VERSION)
endif

ifndef SET_AS_LATEST
    SET_AS_LATEST = 0
endif

# ------------------------------------------------------------------------------
# Test Control
# ------------------------------------------------------------------------------
ifndef SKIP_TEST
    SKIP_TEST := 0
endif

ifndef SKIP
    SKIP :=
endif

# ------------------------------------------------------------------------------
# Runtime Options
# ------------------------------------------------------------------------------
ifndef REBOOT
    REBOOT := 0
endif

ifndef LIMA
    LIMA := 0
endif

ifndef CLASSIC_ISO
    CLASSIC_ISO := 0
endif

# ------------------------------------------------------------------------------
# Feature Flags (Defaults)
# ------------------------------------------------------------------------------
ifndef LTS
    LTS := 0
    DO_INSTALL_LTS := false
endif

ifndef DO_INSTALL_AKMODS
    DO_INSTALL_AKMODS := false
endif

ifndef ZFS
    ZFS := 0
    DO_INSTALL_ZFS := false
endif

# ------------------------------------------------------------------------------
# Distroless Configuration
# ------------------------------------------------------------------------------
IS_DISTROLESS := false
BASE_IMAGE_TAG := $(VERSION)

ifndef BASE_IMAGE_DEVEL
    BASE_IMAGE_DEVEL := registry.fedoraproject.org/fedora:latest
endif

# ------------------------------------------------------------------------------
# Container Images
# ------------------------------------------------------------------------------
BOOTC_IMAGE_BUILDER := quay.io/centos-bootc/bootc-image-builder:latest
SYFT_IMAGE := docker.io/anchore/syft:latest
DEPS_CONTAINER := $(IMAGE):$(VERSION)-deps
CYAN_DEPS_CONTAINER := $(IMAGE):$(VERSION)-cyan-deps

# ------------------------------------------------------------------------------
# Output Directories
# ------------------------------------------------------------------------------
ISO_DIR := ./iso
RAW_DIR := ./raw
AMI_DIR := ./ami
GCE_DIR := ./gce
VHD_DIR := ./vhd
VMDK_DIR := ./vmdk
ANACONDA_ISO_DIR := ./anaconda-iso
QCOW2_DIR := ./images/qcow2/$(TAG)
SBOM_DIR := ./sbom
LIMA_DIR := ./.lima
DISTROLESS_DIR := ./distroless-images

# ------------------------------------------------------------------------------
# S3 Configuration
# ------------------------------------------------------------------------------
S3_HOST := us-east-1.linodeobjects.com
S3_BUCKET := immutablue
S3_COMMON_OPTS := --host=$(S3_HOST) --host-bucket='%(bucket)s.$(S3_HOST)' --acl-public

# ------------------------------------------------------------------------------
# Distroless Image Settings
# ------------------------------------------------------------------------------
DISTROLESS_IMG := $(DISTROLESS_DIR)/bootable-$(TAG).img
DISTROLESS_IMG_SIZE := 50G
DISTROLESS_FILESYSTEM := btrfs
