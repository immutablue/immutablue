# ==============================================================================
# Immutablue Build System - Variant Processing Logic
# ==============================================================================
# This file processes the variant definitions from 10-variants-data.mk
# and sets the appropriate variables based on which flags are set.
# ==============================================================================

# ------------------------------------------------------------------------------
# Desktop Variant Template
# ------------------------------------------------------------------------------
# Processes each desktop variant from DESKTOP_VARIANTS
# Sets: GUI_FLAVOR, BASE_IMAGE, TAG, BUILD_OPTIONS, VARIANT
# ------------------------------------------------------------------------------
define DESKTOP_VARIANT_TEMPLATE
ifeq ($$(strip $$(filter-out 0 00,$$($(1)))),)
else
    GUI_FLAVOR := $(2)
    BASE_IMAGE := $(3)
    TAG := $$(TAG)$(4)
    BUILD_OPTIONS := $(5)
    VARIANT := $(6)
endif
endef

# Process desktop variants
$(foreach v,$(DESKTOP_VARIANTS),\
	$(eval $(call DESKTOP_VARIANT_TEMPLATE,$(word 1,$(subst |, ,$v)),$(word 2,$(subst |, ,$v)),$(word 3,$(subst |, ,$v)),$(word 4,$(subst |, ,$v)),$(word 5,$(subst |, ,$v)),$(word 6,$(subst |, ,$v)))))

# ------------------------------------------------------------------------------
# Add-on Variant Template
# ------------------------------------------------------------------------------
# Processes each add-on variant from ADDON_VARIANTS
# Appends to: TAG, BUILD_OPTIONS
# ------------------------------------------------------------------------------
define ADDON_VARIANT_TEMPLATE
ifeq ($$(strip $$(filter-out 0 00,$$($(1)))),)
else
    TAG := $$(TAG)$(2)
    BUILD_OPTIONS := $$(BUILD_OPTIONS),$(3)
endif
endef

# Process add-on variants
$(foreach v,$(ADDON_VARIANTS),\
	$(eval $(call ADDON_VARIANT_TEMPLATE,$(word 1,$(subst |, ,$v)),$(word 2,$(subst |, ,$v)),$(word 3,$(subst |, ,$v)))))

# ------------------------------------------------------------------------------
# Special Variants
# ------------------------------------------------------------------------------
# These require unique handling and cannot use the standard templates.
# Order matters: some special variants need to be processed before others.
# ------------------------------------------------------------------------------

# NUCLEUS - Minimal server (no GUI)
ifeq ($(strip $(filter-out 0 00,$(NUCLEUS))),)
else
    BASE_IMAGE := quay.io/fedora-ostree-desktops/base-atomic
    TAG := $(TAG)-nucleus
    BUILD_OPTIONS := nucleus
    VARIANT := Server
endif

# DISTROLESS - GNOME OS base (no Fedora version tags)
ifeq ($(strip $(filter-out 0 00,$(DISTROLESS))),)
else
    GUI_FLAVOR := distroless
    BASE_IMAGE := quay.io/gnome_infrastructure/gnome-build-meta
    BASE_IMAGE_TAG := gnomeos-nightly
    BASE_IMAGE_DEVEL := quay.io/gnome_infrastructure/gnome-build-meta:gnomeos-devel-nightly
    TAG := $(TAG)-distroless
    BUILD_OPTIONS := gui,distroless
    VARIANT := None
    IS_DISTROLESS := true
endif

# BAZZITE - Steam Deck gaming (only supports GNOME)
ifeq ($(strip $(filter-out 0 00,$(BAZZITE))),)
else
    GUI_FLAVOR := bazzite
    BASE_IMAGE := ghcr.io/ublue-os/bazzite-deck-gnome
    TAG := $(TAG)-bazzite
    BUILD_OPTIONS := gui,bazzite
    VARIANT := Bazzite
endif

# ASAHI - Apple Silicon (modifies base image path)
ifeq ($(strip $(filter-out 0 00,$(ASAHI))),)
else
    BASE_IMAGE := quay.io/fedora-asahi-remix-atomic-desktops/$(GUI_FLAVOR)
    TAG := $(TAG)-asahi
    BUILD_OPTIONS := $(BUILD_OPTIONS),asahi
    VARIANT := Asahi
endif

# TRUEBLUE - ZFS + LTS (combined variant with special defaults)
ifeq ($(strip $(filter-out 0 00,$(TRUEBLUE))),)
else
    TAG := $(TAG)-trueblue
    BUILD_OPTIONS := $(BUILD_OPTIONS),trueblue,lts,zfs
    DO_INSTALL_LTS := true
    DO_INSTALL_ZFS := true
endif

# BUILD_A_BLUE_WORKSHOP - Special workshop edition
ifeq ($(strip $(filter-out 0 00,$(BUILD_A_BLUE_WORKSHOP))),)
else
    BASE_IMAGE := quay.io/fedora-ostree-desktops/base-atomic
    TAG := $(TAG)-build-a-blue-workshop
    BUILD_OPTIONS := build_a_blue_workshop
endif

# ------------------------------------------------------------------------------
# Post-Processing for Feature Flags
# ------------------------------------------------------------------------------
# These handle the standalone flags that modify behavior

# LTS kernel
ifeq ($(strip $(filter-out 0 00,$(LTS))),)
else
    DO_INSTALL_LTS := true
endif

# ZFS modules (no tag suffix — installs ZFS on top of any variant without renaming)
ifeq ($(strip $(filter-out 0 00,$(ZFS))),)
else
    DO_INSTALL_ZFS := true
    BUILD_OPTIONS := $(BUILD_OPTIONS),zfs
endif

# ------------------------------------------------------------------------------
# Computed Values
# ------------------------------------------------------------------------------
# These must be computed AFTER all variant processing is complete
# ------------------------------------------------------------------------------
DATE_TAG := $(TAG)-$(shell date +%Y%m%d)
FULL_TAG := $(IMAGE):$(TAG)

# Update QCOW2_DIR to use computed TAG
QCOW2_DIR := ./images/qcow2/$(TAG)

# Lima instance name uses computed TAG
LIMA_INSTANCE := immutablue-$(TAG)
LIMA_YAML := $(LIMA_DIR)/$(LIMA_INSTANCE).yaml
