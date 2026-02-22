# ==============================================================================
# Immutablue Build System - Variant Definitions (Data Tables)
# ==============================================================================
# This file defines all build variants as data tables. The logic in
# 20-variants-logic.mk processes these definitions to set variables.
#
# Format: FLAG|FIELD1|FIELD2|... (pipe-separated, parsed by logic file)
# ==============================================================================

# ------------------------------------------------------------------------------
# Desktop Variants
# ------------------------------------------------------------------------------
# Format: FLAG | GUI_FLAVOR | BASE_IMAGE | TAG_SUFFIX | BUILD_OPTIONS | VARIANT_NAME
#
# These variants replace the entire GUI layer. Only one can be active.
# ------------------------------------------------------------------------------
DESKTOP_VARIANTS := \
	KINOITE|kinoite|quay.io/fedora-ostree-desktops/kinoite|-kinoite|gui,kinoite|Kinoite \
	SERICEA|sway-atomic|quay.io/fedora-ostree-desktops/sway-atomic|-sericea|gui,sericea|Sericea \
	ONYX|budgie-atomic|quay.io/fedora-ostree-desktops/budgie-atomic|-onyx|gui,onyx|Onyx \
	VAUXITE|xfce-atomic|quay.io/fedora-ostree-desktops/xfce-atomic|-vauxite|gui,vauxite|Vauxite \
	LAZURITE|lxqt-atomic|quay.io/fedora-ostree-desktops/lxqt-atomic|-lazurite|gui,lazurite|Lazurite \
	COSMIC|cosmic-atomic|quay.io/fedora-ostree-desktops/cosmic-atomic|-cosmic|gui,cosmic|Cosmic

# ------------------------------------------------------------------------------
# Add-on Variants
# ------------------------------------------------------------------------------
# Format: FLAG | TAG_SUFFIX | BUILD_OPTIONS_APPEND
#
# These variants add features on top of the base. Multiple can be combined.
# ------------------------------------------------------------------------------
ADDON_VARIANTS := \
	CYAN|-cyan|cyan \
	LTS|-lts|lts,zfs \
	ZFS||zfs \
	NIX|-nix|nix \
	KUBERBLUE|-kuberblue|kuberblue

# ------------------------------------------------------------------------------
# Special Variants
# ------------------------------------------------------------------------------
# These require unique handling beyond the standard templates.
# Listed here for documentation; logic is in 20-variants-logic.mk
#
# NUCLEUS        - Minimal server (no GUI), uses base-atomic
# DISTROLESS     - Uses GNOME OS base, no Fedora version tags
# BAZZITE        - Uses ublue bazzite-deck-gnome base (Steam Deck)
# ASAHI          - Apple Silicon, modifies base image path
# TRUEBLUE       - Combines LTS + ZFS with special naming
# BUILD_A_BLUE_WORKSHOP - Special workshop variant
# ------------------------------------------------------------------------------
SPECIAL_VARIANTS := NUCLEUS DISTROLESS BAZZITE ASAHI TRUEBLUE BUILD_A_BLUE_WORKSHOP

# ------------------------------------------------------------------------------
# Image Type Definitions
# ------------------------------------------------------------------------------
# Format: NAME | TYPE | EXT | DISK_PATH | COMPRESS | PREBUILD | POSTBUILD_MSG
#
# NAME        - Target name prefix (e.g., iso, raw, ami)
# TYPE        - bootc-image-builder --type value
# EXT         - Output file extension
# DISK_PATH   - Path within build output to disk file
# COMPRESS    - Whether to compress with zstd (true/false)
# PREBUILD    - Prerequisite target (or empty)
# POSTBUILD   - Message to display after build
# ------------------------------------------------------------------------------
IMAGE_TYPES := \
	iso|iso|iso|bootiso/install.iso|false|| \
	raw|raw|img.zst|image/disk.raw|true||To extract: zstd -d immutablue-$(TAG).img.zst -o immutablue-$(TAG).img \
	ami|ami|ami.raw|image/disk.raw|false||Upload to AWS with: aws ec2 import-image \
	gce|gce|gce.tar.gz|image/disk.tar.gz|false||Upload to GCS with: gsutil cp ... gs://your-bucket/ \
	vhd|vhd|vhd|image/disk.vhd|false||Use with Azure, Hyper-V, or Virtual PC \
	vmdk|vmdk|vmdk|image/disk.vmdk|false||Use with VMware vSphere, Workstation, or Fusion

# ------------------------------------------------------------------------------
# Test Definitions
# ------------------------------------------------------------------------------
# Format: NAME | SCRIPT_PATH
# ------------------------------------------------------------------------------
STANDARD_TESTS := \
	container|./tests/test_container.sh \
	container_qemu|./tests/test_container_qemu.sh \
	artifacts|./tests/test_artifacts.sh \
	setup|./tests/test_setup.sh

KUBERBLUE_TESTS := \
	kuberblue_container|./tests/kuberblue/test_kuberblue_container.sh \
	kuberblue_cluster|./tests/kuberblue/test_kuberblue_cluster.sh \
	kuberblue_components|./tests/kuberblue/test_kuberblue_components.sh \
	kuberblue_integration|./tests/kuberblue/test_kuberblue_integration.sh \
	kuberblue_security|./tests/kuberblue/test_kuberblue_security.sh


