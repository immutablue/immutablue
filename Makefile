ifndef $(REGISTRY)
    REGISTRY := quay.io/immutablue
endif

BASE_IMAGE := quay.io/fedora-ostree-desktops/silverblue
IMAGE_BASE_TAG := immutablue
IMAGE := $(REGISTRY)/$(IMAGE_BASE_TAG)
CURRENT := 43
MANIFEST := $(IMAGE_BASE_TAG)
VARIANT := Silverblue


# by default the version tagged build is silverblue
ifndef $(GUI_FLAVOR)	
	GUI_FLAVOR := silverblue
endif

# Default to gui,silverblue
ifndef $(BUILD_OPTIONS)
	BUILD_OPTIONS := gui,silverblue
endif

# Default to running tests (set to 1 to skip tests)
# This variable controls whether pre-build and post-build tests are executed
# Usage: make build SKIP_TEST=1 (skips all tests)
#        make test SKIP_TEST=1 (skips post-build tests only)
ifndef $(SKIP_TEST)
	SKIP_TEST := 0
endif


ifndef $(PLATFORM)
	PLATFORM := linux/amd64 
endif


# Reboot system after completion of install, upgrade, or update
ifndef $(REBOOT)
	REBOOT := 0
endif

ifndef $(VERSION)
	VERSION = $(CURRENT)
endif

ifndef $(TAG)
	TAG = $(VERSION)
endif

ifndef $(SET_AS_LATEST)
	SET_AS_LATEST = 0
endif
	

# Builds Options
# Flavors to start
# You can only pick one of these
#
# No desktop environment
ifeq ($(NUCLEUS),1)
	# BASE_IMAGE := quay.io/fedora/fedora-bootc
	BASE_IMAGE := quay.io/fedora-ostree-desktops/base-atomic
	TAG := $(TAG)-nucleus
	# We don't want gui or anything else, just replace with nucleus
	BUILD_OPTIONS := nucleus
	VARIANT := Server
endif

# KDE desktop
ifeq ($(KINOITE),1)
	GUI_FLAVOR := kinoite
	BASE_IMAGE := quay.io/fedora-ostree-desktops/$(GUI_FLAVOR)
	TAG := $(TAG)-kinoite
	# Replace everything
	BUILD_OPTIONS := gui,kinoite
endif

# Sway desktop
ifeq ($(SERICEA),1)
	GUI_FLAVOR := sway-atomic
	BASE_IMAGE := quay.io/fedora-ostree-desktops/$(GUI_FLAVOR)
	TAG := $(TAG)-sericea
	# Replace everything
	BUILD_OPTIONS := gui,sericea
endif

# Budgie desktop
ifeq ($(ONYX),1)
	GUI_FLAVOR := budgie-atomic
	BASE_IMAGE := quay.io/fedora-ostree-desktops/$(GUI_FLAVOR)
	TAG := $(TAG)-kinoite
	# Replace everything
	BUILD_OPTIONS := gui,onyx
endif

# XFCE desktop
ifeq ($(VAUXITE),1)
	GUI_FLAVOR := xfce-atomic
	BASE_IMAGE := quay.io/fedora-ostree-desktops/$(GUI_FLAVOR)
	TAG := $(TAG)-vauxite
	# Replace everything
	BUILD_OPTIONS := gui,vauxite
endif

# LXQt desktop
ifeq ($(LAZURITE),1)
	GUI_FLAVOR := lxqt-atomic
	BASE_IMAGE := quay.io/fedora-ostree-desktops/$(GUI_FLAVOR)
	TAG := $(TAG)-lazurite
	# Replace everything
	BUILD_OPTIONS := gui,lazurite
endif

# LXQt desktop
ifeq ($(COSMIC),1)
	GUI_FLAVOR := cosmic-atomic
	BASE_IMAGE := quay.io/fedora-ostree-desktops/$(GUI_FLAVOR)
	TAG := $(TAG)-cosmic
	# Replace everything
	BUILD_OPTIONS := gui,cosmic
endif

# Bazzite (only support gnome)
# Immutablue on the steamdeck??
ifeq ($(BAZZITE),1)
	GUI_FLAVOR := bazzite
	BASE_IMAGE := ghcr.io/ublue-os/bazzite-deck-gnome
	TAG := $(TAG)-bazzite
	# Replace everything
	BUILD_OPTIONS := gui,bazzite
endif



# Build-time customizations from build options
ifeq ($(ASAHI),1)
	BASE_IMAGE := quay.io/fedora-asahi-remix-atomic-desktops/${GUI_FLAVOR}
	TAG := $(TAG)-asahi
	BUILD_OPTIONS := $(BUILD_OPTIONS),asahi
endif

ifeq ($(CYAN),1)
	TAG := $(TAG)-cyan
	BUILD_OPTIONS := $(BUILD_OPTIONS),cyan
endif


# Default to non-LTS build
ifndef $(LTS)
	LTS := 0 
    DO_INSTALL_LTS := false
endif

ifeq ($(LTS), 1)
	TAG := $(TAG)-lts
    DO_INSTALL_LTS := true
	# LTS auto-adds zfs
	BUILD_OPTIONS := $(BUILD_OPTIONS),lts,zfs
endif

ifndef $(DO_INSTALL_AKMODS)
	DO_INSTALL_AKMODS := false
endif 

ifndef $(ZFS)
	ZFS := 0 
	DO_INSTALL_ZFS := false
endif

ifeq ($(ZFS),1)
	DO_INSTALL_ZFS := true
	BUILD_OPTIONS := $(BUILD_OPTIONS),zfs
endif

ifeq ($(NIX),1)
	TAG := $(TAG)-nix
	BUILD_OPTIONS := $(BUILD_OPTIONS),nix
endif


# A special edition so divine, it's been ordained by the Blue Council.
ifeq ($(BUILD_A_BLUE_WORKSHOP),1)
	# BASE_IMAGE := quay.io/fedora/fedora-bootc
	BASE_IMAGE := quay.io/fedora-ostree-desktops/base-atomic
	TAG := $(TAG)-build-a-blue-workshop
	BUILD_OPTIONS := build_a_blue_workshop
endif


ifeq ($(KUBERBLUE),1)
	TAG := $(TAG)-kuberblue
	BUILD_OPTIONS := $(BUILD_OPTIONS),kuberblue
endif

ifeq ($(TRUEBLUE),1)
	TAG := $(TAG)-trueblue
	BUILD_OPTIONS := $(BUILD_OPTIONS),trueblue,lts,zfs
	# set to install lts and zfs by default with trueblue 
    DO_INSTALL_LTS := true
    DO_INSTALL_ZFS := true
endif

# Date tag for versioned snapshots (e.g., 43-lts-20260130)
# Must be defined after all variant processing so TAG includes variant suffixes
DATE_TAG := $(TAG)-$(shell date +%Y%m%d)


FULL_TAG := $(IMAGE):$(TAG)

.PHONY: list tag-string all all_upgrade install update upgrade install_or_update reboot \
	build push iso iso-config raw raw-config ami ami-config gce gce-config vhd vhd-config vmdk vmdk-config anaconda-iso anaconda-iso-config upgrade rebase clean \
	install_distrobox install_flatpak install_brew \
	post_install_notes test test_container test_container_qemu test_artifacts test_shellcheck test_setup \
	test_kuberblue_container test_kuberblue_cluster test_kuberblue_components test_kuberblue_integration test_kuberblue_security test_kuberblue test_kuberblue_chainsaw test_chainsaw \
	sbom qcow2 run_qcow2 lima lima-start lima-shell lima-stop lima-delete run_iso run_iso_qemu run_raw run_raw_qemu push_raw push_ami push_gce push_vhd push_vmdk


list:
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | grep -E -v -e '^[^[:alnum:]]' -e '^$@$$'

# Output the computed tag string based on current build options
# Used by immutablue-lima-gen and immutablue-qcow2-gen scripts
# Usage: make tag-string
#        make NUCLEUS=1 LTS=1 tag-string  # outputs: 43-nucleus-lts
tag-string:
	@echo "$(TAG)"


all: build test push
all_upgrade: all update

ifeq ($(REBOOT),1)
install_targets := install_flatpak install_distrobox post_install post_install_notes reboot
upgrade: rpmostree_upgrade reboot
else
install_targets := install_flatpak install_distrobox post_install post_install_notes
upgrade: rpmostree_upgrade
endif

install_or_update :$(install_targets)
install: install_or_update
update: install_or_update


DEPS_CONTAINER := $(IMAGE):$(VERSION)-deps
build-deps:
	buildah \
		build \
		--ignorefile ./.containerignore \
		--no-cache \
		-t $(DEPS_CONTAINER) \
		-f ./deps/Containerfile \
		--build-arg=BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg=FEDORA_VERSION=$(VERSION) \
		--build-arg=IMAGE_TAG=$(IMAGE_BASE_TAG):$(TAG) \
		--build-arg=DO_INSTALL_LTS=$(DO_INSTALL_LTS) \
		--build-arg=DO_INSTALL_ZFS=$(DO_INSTALL_ZFS) \
		--build-arg=DO_INSTALL_AKMODS=$(DO_INSTALL_AKMODS) \
		--build-arg=IMMUTABLUE_BUILD_OPTIONS=$(BUILD_OPTIONS)

push-deps:
	buildah \
		push \
		$(DEPS_CONTAINER)

# Build NVIDIA kernel modules for Cyan variant
CYAN_DEPS_CONTAINER := $(IMAGE):$(VERSION)-cyan-deps
build-cyan-deps:
	buildah \
		build \
		--no-cache \
		-t $(CYAN_DEPS_CONTAINER) \
		-f ./deps/cyan/Containerfile \
		--build-arg=FEDORA_VERSION=$(VERSION)

push-cyan-deps:
	buildah \
		push \
		$(CYAN_DEPS_CONTAINER)


# Build the Immutablue container image
# This target first runs pre-build tests (shellcheck) to ensure code quality
# Pre-tests can be skipped by setting SKIP_TEST=1
build: pre_test
	buildah \
		build \
		--ignorefile ./.containerignore \
		--no-cache \
		-t $(IMAGE):$(TAG) \
		-t $(IMAGE):$(DATE_TAG) \
		-f ./Containerfile \
		--build-arg=BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg=FEDORA_VERSION=$(VERSION) \
		--build-arg=IMAGE_TAG=$(IMAGE_BASE_TAG):$(TAG) \
		--build-arg=DO_INSTALL_LTS=$(DO_INSTALL_LTS) \
		--build-arg=DO_INSTALL_ZFS=$(DO_INSTALL_ZFS) \
		--build-arg=DO_INSTALL_AKMODS=$(DO_INSTALL_AKMODS) \
		--build-arg=IMMUTABLUE_BUILD_OPTIONS=$(BUILD_OPTIONS)

		

push:
ifeq ($(SET_AS_LATEST), 1)
	buildah \
		push \
		$(IMAGE):latest
		
endif
	buildah \
		push \
		$(IMAGE):$(TAG)
	buildah \
		push \
		$(IMAGE):$(DATE_TAG)


retag:
	buildah tag $(IMAGE):$(TAG) $(IMAGE):$(RETAG)


flatpak_refs/flatpaks: packages.yaml
	mkdir -p ./flatpak_refs
	bash -c 'source ./scripts/packages.sh && flatpak_make_refs'


# ISO Image Generation
# Default: Uses bootc-image-builder (same tooling as qcow2 generation)
# Classic: Use CLASSIC_ISO=1 for the legacy build-container-installer approach
#
# Usage:
#   make iso                    # Default: bootc-image-builder ISO
#   make CLASSIC_ISO=1 iso      # Classic: build-container-installer ISO
#   make TRUEBLUE=1 iso         # Variant build with bootc-image-builder
#
# Note: bootc-image-builder ISOs are "install-to-disk" installers.
#       Classic ISOs use Anaconda with more configuration options.
ifndef $(CLASSIC_ISO)
	CLASSIC_ISO := 0
endif

ISO_DIR := ./iso
ISO_BUILD_DIR := $(ISO_DIR)/.build-$(TAG)
ISO_CONFIG := $(ISO_DIR)/config-$(TAG).toml
ISO_OUTPUT := $(ISO_DIR)/immutablue-$(TAG).iso

# Shared bootc-image-builder container (used by iso, raw, and qcow2 targets)
BOOTC_IMAGE_BUILDER := quay.io/centos-bootc/bootc-image-builder:latest

iso:
ifeq ($(CLASSIC_ISO),1)
	@echo "Building classic ISO using build-container-installer..."
	$(MAKE) _iso_classic
else
	@echo "Building ISO using bootc-image-builder..."
	$(MAKE) _iso_bootc
endif

# Interactive ISO configuration generator
# Creates a config.toml with user credentials and optional SSH key
# Usage: make iso-config
#        make TRUEBLUE=1 iso-config
iso-config:
	@echo "=== Immutablue ISO Configuration ==="
	@echo "Config file: $(ISO_CONFIG)"
	@echo ""
	@mkdir -p $(ISO_DIR)
	@echo "# Immutablue ISO configuration" > $(ISO_CONFIG)
	@echo "# Generated by: make iso-config" >> $(ISO_CONFIG)
	@echo "" >> $(ISO_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [immutablue]: " username; \
		username=$${username:-immutablue}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(ISO_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(ISO_CONFIG); \
		echo "[[customizations.user]]" >> $(ISO_CONFIG); \
		echo "name = \"$$username\"" >> $(ISO_CONFIG); \
		echo "password = \"$$password\"" >> $(ISO_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(ISO_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			if [ -f "$$HOME/.lima/_config/user.pub" ]; then \
				echo "  $$HOME/.lima/_config/user.pub (Lima)"; \
			fi; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(ISO_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(ISO_CONFIG)"
	@echo "Run 'make iso' to build the ISO."

# bootc-image-builder ISO target (default)
# Uses the same container and config approach as qcow2 generation
# Generates an install-to-disk ISO with embedded Anaconda
# If no user is configured, enables firstboot for interactive setup
_iso_bootc:
	@echo "Building bootc ISO for $(IMAGE):$(TAG)..."
	@mkdir -p $(ISO_BUILD_DIR)
	@# Use existing config or create one with firstboot enabled
	@if [ -f "$(ISO_CONFIG)" ]; then \
		echo "Using existing config: $(ISO_CONFIG)"; \
		cp $(ISO_CONFIG) $(ISO_BUILD_DIR)/config.toml; \
	else \
		echo "No user config found - enabling interactive first-boot setup"; \
		echo "# Immutablue ISO config - interactive first-boot setup" > $(ISO_BUILD_DIR)/config.toml; \
		echo "" >> $(ISO_BUILD_DIR)/config.toml; \
		echo "# Enable GNOME Initial Setup on first boot for:" >> $(ISO_BUILD_DIR)/config.toml; \
		echo "# - User account creation" >> $(ISO_BUILD_DIR)/config.toml; \
		echo "# - Timezone selection" >> $(ISO_BUILD_DIR)/config.toml; \
		echo "# - Language/keyboard settings" >> $(ISO_BUILD_DIR)/config.toml; \
		echo "[customizations.installer.kickstart]" >> $(ISO_BUILD_DIR)/config.toml; \
		echo 'contents = """' >> $(ISO_BUILD_DIR)/config.toml; \
		echo "firstboot --enable" >> $(ISO_BUILD_DIR)/config.toml; \
		echo '"""' >> $(ISO_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(ISO_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(ISO_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type iso \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(ISO_BUILD_DIR)
	@# Move ISO to final location
	mv $(ISO_BUILD_DIR)/bootiso/install.iso $(ISO_OUTPUT)
	@# Cleanup build directory
	rm -rf $(ISO_BUILD_DIR)
	@echo ""
	@echo "ISO built: $(ISO_OUTPUT)"
	@if [ -f "$(ISO_CONFIG)" ]; then \
		echo "Configured with: $(ISO_CONFIG)"; \
	else \
		echo "First-boot setup enabled - user will configure account on first login"; \
	fi

# Classic ISO target (build-container-installer)
# Use with: make CLASSIC_ISO=1 iso
# Provides more Anaconda configuration options and flatpak bundling
_iso_classic: flatpak_refs/flatpaks
	@echo "Building classic ISO for $(IMAGE):$(TAG)..."
	mkdir -p $(ISO_DIR)
	sudo podman run \
		--name immutablue-build \
		--rm \
		--privileged \
		--volume $(ISO_DIR):/build-container-installer/build \
		ghcr.io/jasonn3/build-container-installer:latest \
		VERSION=$(VERSION) \
		IMAGE_NAME=$(IMAGE_BASE_TAG) \
		IMAGE_TAG=$(TAG) \
		IMAGE_REPO=$(REGISTRY) \
		IMAGE_SIGNED=false \
		VARIANT=$(VARIANT) \
		ISO_NAME="build/immutablue-$(TAG).iso"
	@echo ""
	@echo "Classic ISO built: $(ISO_OUTPUT)"

# Push ISO to S3
push_iso:
	@if [ ! -f "$(ISO_OUTPUT)" ]; then \
		echo "Error: No ISO found at $(ISO_OUTPUT). Run 'make iso' first."; \
		exit 1; \
	fi
	@echo "Pushing ISO: $(ISO_OUTPUT)"
	@cd $(ISO_DIR) && sha256sum immutablue-$(TAG).iso > immutablue-$(TAG).iso-CHECKSUM
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put $(ISO_OUTPUT) s3://immutablue/immutablue-$(TAG).iso
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put $(ISO_DIR)/immutablue-$(TAG).iso-CHECKSUM s3://immutablue/immutablue-$(TAG).iso-CHECKSUM

# Run ISO in QEMU for testing (containerized)
run_iso:
	@if [ ! -f "$(ISO_OUTPUT)" ]; then \
		echo "Error: No ISO found at $(ISO_OUTPUT). Run 'make iso' first."; \
		exit 1; \
	fi
	@echo "Booting ISO: $(ISO_OUTPUT)"
	@echo "Web console: http://localhost:8006"
	podman run --rm --cap-add NET_ADMIN \
		-p 127.0.0.1:8006:8006 \
		--env CPU_CORES=8 --env RAM_SIZE=8G --env DISK_SIZE=64G --env BOOT_MODE=uefi \
		--device=/dev/kvm \
		--device=/dev/net/tun \
		-v $(CURDIR)/$(ISO_OUTPUT):/boot.iso:Z \
		docker.io/qemux/qemu

# Run ISO in native QEMU (requires qemu-system-x86_64)
run_iso_qemu:
	@if [ ! -f "$(ISO_OUTPUT)" ]; then \
		echo "Error: No ISO found at $(ISO_OUTPUT). Run 'make iso' first."; \
		exit 1; \
	fi
	@if [ ! -f "$(ISO_DIR)/.install-disk.qcow2" ]; then \
		echo "Creating installation target disk..."; \
		qemu-img create -f qcow2 $(ISO_DIR)/.install-disk.qcow2 64G; \
	fi
	@echo "Booting ISO: $(ISO_OUTPUT)"
	@echo "SSH: ssh -p 2222 <user>@localhost (after install)"
	@echo "Exit: Ctrl-A X"
	sudo qemu-system-x86_64 \
		-enable-kvm \
		-m 4G \
		-smp 4 \
		-cpu host \
		-cdrom $(ISO_OUTPUT) \
		-drive file=$(ISO_DIR)/.install-disk.qcow2,format=qcow2,if=virtio \
		-boot d \
		-nic user,hostfwd=tcp::2222-:22 \
		-nographic \
		-serial mon:stdio


# Raw Disk Image Generation
# Generates a raw disk image using bootc-image-builder
# Usage: make raw (after pushing the image to registry)
#        make TRUEBLUE=1 raw (for variant builds)
#        make raw-config (configure user accounts before building)
# Raw images are suitable for dd'ing to USB drives or using with cloud providers
RAW_DIR := ./raw
RAW_BUILD_DIR := $(RAW_DIR)/.build-$(TAG)
RAW_CONFIG := $(RAW_DIR)/config-$(TAG).toml
RAW_OUTPUT := $(RAW_DIR)/immutablue-$(TAG).img.zst

# Interactive raw image configuration generator
# Creates a config.toml with user credentials and optional SSH key
# Usage: make raw-config
#        make TRUEBLUE=1 raw-config
raw-config:
	@echo "=== Immutablue Raw Image Configuration ==="
	@echo "Config file: $(RAW_CONFIG)"
	@echo ""
	@mkdir -p $(RAW_DIR)
	@echo "# Immutablue raw image configuration" > $(RAW_CONFIG)
	@echo "# Generated by: make raw-config" >> $(RAW_CONFIG)
	@echo "" >> $(RAW_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [immutablue]: " username; \
		username=$${username:-immutablue}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(RAW_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(RAW_CONFIG); \
		echo "[[customizations.user]]" >> $(RAW_CONFIG); \
		echo "name = \"$$username\"" >> $(RAW_CONFIG); \
		echo "password = \"$$password\"" >> $(RAW_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(RAW_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			if [ -f "$$HOME/.lima/_config/user.pub" ]; then \
				echo "  $$HOME/.lima/_config/user.pub (Lima)"; \
			fi; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(RAW_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(RAW_CONFIG)"
	@echo "Run 'make raw' to build the raw image."

# Raw image build target using bootc-image-builder
# If no user is configured, creates a minimal config (may require console access)
raw:
	@echo "Building raw disk image for $(IMAGE):$(TAG)..."
	@mkdir -p $(RAW_BUILD_DIR)
	@# Use existing config or create a minimal one
	@if [ -f "$(RAW_CONFIG)" ]; then \
		echo "Using existing config: $(RAW_CONFIG)"; \
		cp $(RAW_CONFIG) $(RAW_BUILD_DIR)/config.toml; \
	else \
		echo "No user config found - creating minimal config"; \
		echo "Warning: Without a user configured, you may need console access"; \
		echo "# Immutablue raw image config - no users configured" > $(RAW_BUILD_DIR)/config.toml; \
		echo "# Run 'make raw-config' to add user accounts" >> $(RAW_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(RAW_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(RAW_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type raw \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(RAW_BUILD_DIR)
	@# Compress with zstd
	@echo "Compressing with zstd..."
	zstd -T4 -5 $(RAW_BUILD_DIR)/image/disk.raw -o $(RAW_OUTPUT)
	@# Cleanup build directory
	rm -rf $(RAW_BUILD_DIR)
	@echo ""
	@echo "Raw image built: $(RAW_OUTPUT)"
	@if [ -f "$(RAW_CONFIG)" ]; then \
		echo "Configured with: $(RAW_CONFIG)"; \
	else \
		echo "Warning: No user configured - console access may be required"; \
	fi
	@echo ""
	@echo "To extract: zstd -d $(RAW_OUTPUT) -o immutablue-$(TAG).img"

# Run raw image in QEMU for testing (containerized)
# Note: Extracts the compressed image to a temp location first
run_raw:
	@if [ ! -f "$(RAW_OUTPUT)" ]; then \
		echo "Error: No raw image found at $(RAW_OUTPUT). Run 'make raw' first."; \
		exit 1; \
	fi
	@echo "Extracting compressed image..."
	zstd -d $(RAW_OUTPUT) -o $(RAW_DIR)/.run-tmp.img -f
	@echo "Booting raw image: $(RAW_OUTPUT)"
	@echo "Web console: http://localhost:8006"
	podman run --rm --cap-add NET_ADMIN \
		-p 127.0.0.1:8006:8006 \
		--env CPU_CORES=8 --env RAM_SIZE=8G --env BOOT_MODE=uefi \
		--device=/dev/kvm \
		--device=/dev/net/tun \
		-v $(CURDIR)/$(RAW_DIR)/.run-tmp.img:/boot.img:Z \
		docker.io/qemux/qemu
	@rm -f $(RAW_DIR)/.run-tmp.img

# Run raw image in native QEMU (requires qemu-system-x86_64)
run_raw_qemu:
	@if [ ! -f "$(RAW_OUTPUT)" ]; then \
		echo "Error: No raw image found at $(RAW_OUTPUT). Run 'make raw' first."; \
		exit 1; \
	fi
	@echo "Extracting compressed image..."
	zstd -d $(RAW_OUTPUT) -o $(RAW_DIR)/.run-tmp.img -f
	@echo "Booting raw image: $(RAW_OUTPUT)"
	@echo "SSH: ssh -p 2222 immutablue@localhost (if configured)"
	@echo "Exit: Ctrl-A X"
	sudo qemu-system-x86_64 \
		-enable-kvm \
		-m 4G \
		-smp 4 \
		-cpu host \
		-drive file=$(RAW_DIR)/.run-tmp.img,format=raw \
		-boot c \
		-nic user,hostfwd=tcp::2222-:22 \
		-nographic \
		-serial mon:stdio
	@rm -f $(RAW_DIR)/.run-tmp.img

# Push raw image to S3
push_raw:
	@if [ ! -f "$(RAW_OUTPUT)" ]; then \
		echo "Error: No raw image found at $(RAW_OUTPUT). Run 'make raw' first."; \
		exit 1; \
	fi
	@echo "Pushing raw image: $(RAW_OUTPUT)"
	@cd $(RAW_DIR) && sha256sum immutablue-$(TAG).img.zst > immutablue-$(TAG).img.zst-CHECKSUM
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put $(RAW_OUTPUT) s3://immutablue/immutablue-$(TAG).img.zst
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put $(RAW_DIR)/immutablue-$(TAG).img.zst-CHECKSUM s3://immutablue/immutablue-$(TAG).img.zst-CHECKSUM


# AMI (Amazon Machine Image) Generation
# Generates an AMI-compatible image using bootc-image-builder
# Usage: make ami (after pushing the image to registry)
#        make TRUEBLUE=1 ami (for variant builds)
#        make ami-config (configure user accounts before building)
# Can be uploaded to AWS using the AWS CLI or bootc-image-builder's native upload
AMI_DIR := ./ami
AMI_BUILD_DIR := $(AMI_DIR)/.build-$(TAG)
AMI_CONFIG := $(AMI_DIR)/config-$(TAG).toml
AMI_OUTPUT := $(AMI_DIR)/immutablue-$(TAG).ami.raw

# Interactive AMI configuration generator
ami-config:
	@echo "=== Immutablue AMI Configuration ==="
	@echo "Config file: $(AMI_CONFIG)"
	@echo ""
	@mkdir -p $(AMI_DIR)
	@echo "# Immutablue AMI configuration" > $(AMI_CONFIG)
	@echo "# Generated by: make ami-config" >> $(AMI_CONFIG)
	@echo "" >> $(AMI_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [immutablue]: " username; \
		username=$${username:-immutablue}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(AMI_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(AMI_CONFIG); \
		echo "[[customizations.user]]" >> $(AMI_CONFIG); \
		echo "name = \"$$username\"" >> $(AMI_CONFIG); \
		echo "password = \"$$password\"" >> $(AMI_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(AMI_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(AMI_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(AMI_CONFIG)"
	@echo "Run 'make ami' to build the AMI."

# AMI build target
ami:
	@echo "Building AMI for $(IMAGE):$(TAG)..."
	@mkdir -p $(AMI_BUILD_DIR)
	@if [ -f "$(AMI_CONFIG)" ]; then \
		echo "Using existing config: $(AMI_CONFIG)"; \
		cp $(AMI_CONFIG) $(AMI_BUILD_DIR)/config.toml; \
	else \
		echo "No user config found - creating minimal config"; \
		echo "# Immutablue AMI config - no users configured" > $(AMI_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(AMI_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(AMI_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type ami \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(AMI_BUILD_DIR)
	mv $(AMI_BUILD_DIR)/image/disk.raw $(AMI_OUTPUT)
	rm -rf $(AMI_BUILD_DIR)
	@echo ""
	@echo "AMI built: $(AMI_OUTPUT)"
	@echo "Upload to AWS with: aws ec2 import-image"

# Push AMI to S3 (for manual AWS import)
push_ami:
	@if [ ! -f "$(AMI_OUTPUT)" ]; then \
		echo "Error: No AMI found at $(AMI_OUTPUT). Run 'make ami' first."; \
		exit 1; \
	fi
	@echo "Pushing AMI: $(AMI_OUTPUT)"
	@cd $(AMI_DIR) && sha256sum immutablue-$(TAG).ami.raw > immutablue-$(TAG).ami.raw-CHECKSUM
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put $(AMI_OUTPUT) s3://immutablue/immutablue-$(TAG).ami.raw
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put $(AMI_DIR)/immutablue-$(TAG).ami.raw-CHECKSUM s3://immutablue/immutablue-$(TAG).ami.raw-CHECKSUM


# GCE (Google Compute Engine) Image Generation
# Generates a GCE-compatible image using bootc-image-builder
# Usage: make gce (after pushing the image to registry)
#        make TRUEBLUE=1 gce (for variant builds)
#        make gce-config (configure user accounts before building)
# Output is a tar.gz file ready for upload to Google Cloud Storage
GCE_DIR := ./gce
GCE_BUILD_DIR := $(GCE_DIR)/.build-$(TAG)
GCE_CONFIG := $(GCE_DIR)/config-$(TAG).toml
GCE_OUTPUT := $(GCE_DIR)/immutablue-$(TAG).gce.tar.gz

# Interactive GCE configuration generator
gce-config:
	@echo "=== Immutablue GCE Configuration ==="
	@echo "Config file: $(GCE_CONFIG)"
	@echo ""
	@mkdir -p $(GCE_DIR)
	@echo "# Immutablue GCE configuration" > $(GCE_CONFIG)
	@echo "# Generated by: make gce-config" >> $(GCE_CONFIG)
	@echo "" >> $(GCE_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [immutablue]: " username; \
		username=$${username:-immutablue}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(GCE_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(GCE_CONFIG); \
		echo "[[customizations.user]]" >> $(GCE_CONFIG); \
		echo "name = \"$$username\"" >> $(GCE_CONFIG); \
		echo "password = \"$$password\"" >> $(GCE_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(GCE_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(GCE_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(GCE_CONFIG)"
	@echo "Run 'make gce' to build the GCE image."

# GCE build target
gce:
	@echo "Building GCE image for $(IMAGE):$(TAG)..."
	@mkdir -p $(GCE_BUILD_DIR)
	@if [ -f "$(GCE_CONFIG)" ]; then \
		echo "Using existing config: $(GCE_CONFIG)"; \
		cp $(GCE_CONFIG) $(GCE_BUILD_DIR)/config.toml; \
	else \
		echo "No user config found - creating minimal config"; \
		echo "# Immutablue GCE config - no users configured" > $(GCE_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(GCE_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(GCE_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type gce \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(GCE_BUILD_DIR)
	mv $(GCE_BUILD_DIR)/image/disk.tar.gz $(GCE_OUTPUT)
	rm -rf $(GCE_BUILD_DIR)
	@echo ""
	@echo "GCE image built: $(GCE_OUTPUT)"
	@echo "Upload to GCS with: gsutil cp $(GCE_OUTPUT) gs://your-bucket/"

# Push GCE image to S3
push_gce:
	@if [ ! -f "$(GCE_OUTPUT)" ]; then \
		echo "Error: No GCE image found at $(GCE_OUTPUT). Run 'make gce' first."; \
		exit 1; \
	fi
	@echo "Pushing GCE image: $(GCE_OUTPUT)"
	@cd $(GCE_DIR) && sha256sum immutablue-$(TAG).gce.tar.gz > immutablue-$(TAG).gce.tar.gz-CHECKSUM
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put $(GCE_OUTPUT) s3://immutablue/immutablue-$(TAG).gce.tar.gz
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put $(GCE_DIR)/immutablue-$(TAG).gce.tar.gz-CHECKSUM s3://immutablue/immutablue-$(TAG).gce.tar.gz-CHECKSUM


# VHD (Virtual Hard Disk) Image Generation
# Generates a VHD image for Azure, Hyper-V, or Virtual PC
# Usage: make vhd (after pushing the image to registry)
#        make TRUEBLUE=1 vhd (for variant builds)
#        make vhd-config (configure user accounts before building)
VHD_DIR := ./vhd
VHD_BUILD_DIR := $(VHD_DIR)/.build-$(TAG)
VHD_CONFIG := $(VHD_DIR)/config-$(TAG).toml
VHD_OUTPUT := $(VHD_DIR)/immutablue-$(TAG).vhd

# Interactive VHD configuration generator
vhd-config:
	@echo "=== Immutablue VHD Configuration ==="
	@echo "Config file: $(VHD_CONFIG)"
	@echo ""
	@mkdir -p $(VHD_DIR)
	@echo "# Immutablue VHD configuration" > $(VHD_CONFIG)
	@echo "# Generated by: make vhd-config" >> $(VHD_CONFIG)
	@echo "" >> $(VHD_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [immutablue]: " username; \
		username=$${username:-immutablue}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(VHD_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(VHD_CONFIG); \
		echo "[[customizations.user]]" >> $(VHD_CONFIG); \
		echo "name = \"$$username\"" >> $(VHD_CONFIG); \
		echo "password = \"$$password\"" >> $(VHD_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(VHD_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(VHD_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(VHD_CONFIG)"
	@echo "Run 'make vhd' to build the VHD image."

# VHD build target
vhd:
	@echo "Building VHD image for $(IMAGE):$(TAG)..."
	@mkdir -p $(VHD_BUILD_DIR)
	@if [ -f "$(VHD_CONFIG)" ]; then \
		echo "Using existing config: $(VHD_CONFIG)"; \
		cp $(VHD_CONFIG) $(VHD_BUILD_DIR)/config.toml; \
	else \
		echo "No user config found - creating minimal config"; \
		echo "# Immutablue VHD config - no users configured" > $(VHD_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(VHD_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(VHD_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type vhd \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(VHD_BUILD_DIR)
	mv $(VHD_BUILD_DIR)/image/disk.vhd $(VHD_OUTPUT)
	rm -rf $(VHD_BUILD_DIR)
	@echo ""
	@echo "VHD image built: $(VHD_OUTPUT)"
	@echo "Use with Azure, Hyper-V, or Virtual PC"

# Push VHD to S3
push_vhd:
	@if [ ! -f "$(VHD_OUTPUT)" ]; then \
		echo "Error: No VHD image found at $(VHD_OUTPUT). Run 'make vhd' first."; \
		exit 1; \
	fi
	@echo "Pushing VHD image: $(VHD_OUTPUT)"
	@cd $(VHD_DIR) && sha256sum immutablue-$(TAG).vhd > immutablue-$(TAG).vhd-CHECKSUM
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put $(VHD_OUTPUT) s3://immutablue/immutablue-$(TAG).vhd
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put $(VHD_DIR)/immutablue-$(TAG).vhd-CHECKSUM s3://immutablue/immutablue-$(TAG).vhd-CHECKSUM


# VMDK (VMware Disk) Image Generation
# Generates a VMDK image for VMware vSphere, Workstation, or Fusion
# Usage: make vmdk (after pushing the image to registry)
#        make TRUEBLUE=1 vmdk (for variant builds)
#        make vmdk-config (configure user accounts before building)
VMDK_DIR := ./vmdk
VMDK_BUILD_DIR := $(VMDK_DIR)/.build-$(TAG)
VMDK_CONFIG := $(VMDK_DIR)/config-$(TAG).toml
VMDK_OUTPUT := $(VMDK_DIR)/immutablue-$(TAG).vmdk

# Interactive VMDK configuration generator
vmdk-config:
	@echo "=== Immutablue VMDK Configuration ==="
	@echo "Config file: $(VMDK_CONFIG)"
	@echo ""
	@mkdir -p $(VMDK_DIR)
	@echo "# Immutablue VMDK configuration" > $(VMDK_CONFIG)
	@echo "# Generated by: make vmdk-config" >> $(VMDK_CONFIG)
	@echo "" >> $(VMDK_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [immutablue]: " username; \
		username=$${username:-immutablue}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(VMDK_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(VMDK_CONFIG); \
		echo "[[customizations.user]]" >> $(VMDK_CONFIG); \
		echo "name = \"$$username\"" >> $(VMDK_CONFIG); \
		echo "password = \"$$password\"" >> $(VMDK_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(VMDK_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(VMDK_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(VMDK_CONFIG)"
	@echo "Run 'make vmdk' to build the VMDK image."

# VMDK build target
vmdk:
	@echo "Building VMDK image for $(IMAGE):$(TAG)..."
	@mkdir -p $(VMDK_BUILD_DIR)
	@if [ -f "$(VMDK_CONFIG)" ]; then \
		echo "Using existing config: $(VMDK_CONFIG)"; \
		cp $(VMDK_CONFIG) $(VMDK_BUILD_DIR)/config.toml; \
	else \
		echo "No user config found - creating minimal config"; \
		echo "# Immutablue VMDK config - no users configured" > $(VMDK_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(VMDK_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(VMDK_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type vmdk \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(VMDK_BUILD_DIR)
	mv $(VMDK_BUILD_DIR)/image/disk.vmdk $(VMDK_OUTPUT)
	rm -rf $(VMDK_BUILD_DIR)
	@echo ""
	@echo "VMDK image built: $(VMDK_OUTPUT)"
	@echo "Use with VMware vSphere, Workstation, or Fusion"

# Push VMDK to S3
push_vmdk:
	@if [ ! -f "$(VMDK_OUTPUT)" ]; then \
		echo "Error: No VMDK image found at $(VMDK_OUTPUT). Run 'make vmdk' first."; \
		exit 1; \
	fi
	@echo "Pushing VMDK image: $(VMDK_OUTPUT)"
	@cd $(VMDK_DIR) && sha256sum immutablue-$(TAG).vmdk > immutablue-$(TAG).vmdk-CHECKSUM
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put $(VMDK_OUTPUT) s3://immutablue/immutablue-$(TAG).vmdk
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put $(VMDK_DIR)/immutablue-$(TAG).vmdk-CHECKSUM s3://immutablue/immutablue-$(TAG).vmdk-CHECKSUM


# Anaconda ISO Image Generation
# Generates an unattended Anaconda installer ISO (RPM-based, different from bootc-installer)
# Usage: make anaconda-iso (after pushing the image to registry)
#        make TRUEBLUE=1 anaconda-iso (for variant builds)
#        make anaconda-iso-config (configure user accounts before building)
# This creates an installer that auto-installs to the first disk
ANACONDA_ISO_DIR := ./anaconda-iso
ANACONDA_ISO_BUILD_DIR := $(ANACONDA_ISO_DIR)/.build-$(TAG)
ANACONDA_ISO_CONFIG := $(ANACONDA_ISO_DIR)/config-$(TAG).toml
ANACONDA_ISO_OUTPUT := $(ANACONDA_ISO_DIR)/immutablue-$(TAG)-anaconda.iso

# Interactive Anaconda ISO configuration generator
anaconda-iso-config:
	@echo "=== Immutablue Anaconda ISO Configuration ==="
	@echo "Config file: $(ANACONDA_ISO_CONFIG)"
	@echo ""
	@mkdir -p $(ANACONDA_ISO_DIR)
	@echo "# Immutablue Anaconda ISO configuration" > $(ANACONDA_ISO_CONFIG)
	@echo "# Generated by: make anaconda-iso-config" >> $(ANACONDA_ISO_CONFIG)
	@echo "" >> $(ANACONDA_ISO_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [immutablue]: " username; \
		username=$${username:-immutablue}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(ANACONDA_ISO_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(ANACONDA_ISO_CONFIG); \
		echo "[[customizations.user]]" >> $(ANACONDA_ISO_CONFIG); \
		echo "name = \"$$username\"" >> $(ANACONDA_ISO_CONFIG); \
		echo "password = \"$$password\"" >> $(ANACONDA_ISO_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(ANACONDA_ISO_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(ANACONDA_ISO_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(ANACONDA_ISO_CONFIG)"
	@echo "Run 'make anaconda-iso' to build the Anaconda ISO."

# Anaconda ISO build target
anaconda-iso:
	@echo "Building Anaconda ISO for $(IMAGE):$(TAG)..."
	@mkdir -p $(ANACONDA_ISO_BUILD_DIR)
	@if [ -f "$(ANACONDA_ISO_CONFIG)" ]; then \
		echo "Using existing config: $(ANACONDA_ISO_CONFIG)"; \
		cp $(ANACONDA_ISO_CONFIG) $(ANACONDA_ISO_BUILD_DIR)/config.toml; \
	else \
		echo "No user config found - creating minimal config"; \
		echo "# Immutablue Anaconda ISO config - no users configured" > $(ANACONDA_ISO_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(ANACONDA_ISO_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(ANACONDA_ISO_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type anaconda-iso \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(ANACONDA_ISO_BUILD_DIR)
	mv $(ANACONDA_ISO_BUILD_DIR)/bootiso/install.iso $(ANACONDA_ISO_OUTPUT)
	rm -rf $(ANACONDA_ISO_BUILD_DIR)
	@echo ""
	@echo "Anaconda ISO built: $(ANACONDA_ISO_OUTPUT)"
	@echo "This ISO auto-installs to the first disk found"


# QCOW2 VM Image Generation
# Generates a bootable qcow2 VM image using bootc-image-builder
# Usage: make qcow2-config (interactive configuration)
#        make qcow2 (after pushing the image to registry)
#        make TRUEBLUE=1 qcow2 (for variant builds)
#        make LIMA=1 qcow2 (include SSH keys for Lima VM access)
# Default credentials: immutablue / immutablue
QCOW2_DIR := ./images/qcow2/$(TAG)
QCOW2_CONFIG := $(QCOW2_DIR)/config-$(TAG).toml

ifndef $(LIMA)
	LIMA := 0
endif

# Interactive qcow2 image configuration generator
# Creates a config.toml with user credentials and optional SSH key
# Usage: make qcow2-config
#        make TRUEBLUE=1 qcow2-config
#        make LIMA=1 qcow2-config (auto-adds Lima/SSH key)
qcow2-config:
	@echo "=== Immutablue QCOW2 Image Configuration ==="
	@echo "Config file: $(QCOW2_CONFIG)"
	@echo ""
	@mkdir -p $(QCOW2_DIR)
	@echo "# Immutablue qcow2 image configuration" > $(QCOW2_CONFIG)
	@echo "# Generated by: make qcow2-config" >> $(QCOW2_CONFIG)
	@echo "" >> $(QCOW2_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [immutablue]: " username; \
		username=$${username:-immutablue}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(QCOW2_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(QCOW2_CONFIG); \
		echo "[[customizations.user]]" >> $(QCOW2_CONFIG); \
		echo "name = \"$$username\"" >> $(QCOW2_CONFIG); \
		echo "password = \"$$password\"" >> $(QCOW2_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(QCOW2_CONFIG); \
		fi; \
		add_ssh="n"; \
		if [ "$(LIMA)" = "1" ]; then \
			echo ""; \
			echo "LIMA=1 detected - auto-adding SSH key..."; \
			if [ -f "$$HOME/.lima/_config/user.pub" ]; then \
				ssh_key=$$(cat "$$HOME/.lima/_config/user.pub"); \
				echo "key = \"$$ssh_key\"" >> $(QCOW2_CONFIG); \
				echo "Added Lima SSH key from ~/.lima/_config/user.pub"; \
				add_ssh="done"; \
			elif [ -f "$$HOME/.ssh/id_ed25519.pub" ]; then \
				ssh_key=$$(cat "$$HOME/.ssh/id_ed25519.pub"); \
				echo "key = \"$$ssh_key\"" >> $(QCOW2_CONFIG); \
				echo "Added SSH key from ~/.ssh/id_ed25519.pub"; \
				add_ssh="done"; \
			elif [ -f "$$HOME/.ssh/id_rsa.pub" ]; then \
				ssh_key=$$(cat "$$HOME/.ssh/id_rsa.pub"); \
				echo "key = \"$$ssh_key\"" >> $(QCOW2_CONFIG); \
				echo "Added SSH key from ~/.ssh/id_rsa.pub"; \
				add_ssh="done"; \
			else \
				echo "Warning: LIMA=1 but no SSH key found."; \
			fi; \
		fi; \
		if [ "$$add_ssh" != "done" ]; then \
			read -p "Add SSH public key? [y/N]: " add_ssh_prompt; \
			if [ "$$add_ssh_prompt" = "y" ] || [ "$$add_ssh_prompt" = "Y" ]; then \
				echo ""; \
				echo "Available SSH keys:"; \
				ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
				if [ -f "$$HOME/.lima/_config/user.pub" ]; then \
					echo "  $$HOME/.lima/_config/user.pub (Lima)"; \
				fi; \
				echo ""; \
				read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
				ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
				ssh_key_path=$$(eval echo $$ssh_key_path); \
				if [ -f "$$ssh_key_path" ]; then \
					ssh_key=$$(cat "$$ssh_key_path"); \
					echo "key = \"$$ssh_key\"" >> $(QCOW2_CONFIG); \
					echo "Added SSH key from $$ssh_key_path"; \
				else \
					echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
				fi; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(QCOW2_CONFIG)"
	@echo "Run 'make qcow2' to build the qcow2 image."

qcow2:
	@echo "Building qcow2 VM image for $(IMAGE):$(TAG)..."
	@mkdir -p $(QCOW2_DIR)
	@# Use existing config or generate one
	@if [ -f "$(QCOW2_CONFIG)" ]; then \
		echo "Using existing config: $(QCOW2_CONFIG)"; \
		cp $(QCOW2_CONFIG) $(QCOW2_DIR)/config.toml; \
	elif [ "$(LIMA)" = "1" ]; then \
		echo "LIMA=1: Generating config with SSH keys..."; \
		echo "# Auto-generated bootc-image-builder config (LIMA=1)" > $(QCOW2_DIR)/config.toml; \
		echo "" >> $(QCOW2_DIR)/config.toml; \
		echo "[[customizations.user]]" >> $(QCOW2_DIR)/config.toml; \
		echo 'name = "immutablue"' >> $(QCOW2_DIR)/config.toml; \
		echo 'password = "immutablue"' >> $(QCOW2_DIR)/config.toml; \
		echo 'groups = ["wheel"]' >> $(QCOW2_DIR)/config.toml; \
		if [ -f "$$HOME/.lima/_config/user.pub" ]; then \
			echo "key = \"$$(cat $$HOME/.lima/_config/user.pub)\"" >> $(QCOW2_DIR)/config.toml; \
			echo "Added Lima SSH key to config"; \
		elif [ -f "$$HOME/.ssh/id_ed25519.pub" ]; then \
			echo "key = \"$$(cat $$HOME/.ssh/id_ed25519.pub)\"" >> $(QCOW2_DIR)/config.toml; \
			echo "Added SSH key (id_ed25519) to config"; \
		elif [ -f "$$HOME/.ssh/id_rsa.pub" ]; then \
			echo "key = \"$$(cat $$HOME/.ssh/id_rsa.pub)\"" >> $(QCOW2_DIR)/config.toml; \
			echo "Added SSH key (id_rsa) to config"; \
		else \
			echo "Warning: LIMA=1 but no SSH key found. Lima SSH access may not work."; \
		fi; \
	else \
		echo "No config found - creating default config (immutablue/immutablue)"; \
		echo "Tip: Run 'make qcow2-config' for interactive configuration"; \
		echo "# Auto-generated bootc-image-builder config" > $(QCOW2_DIR)/config.toml; \
		echo "" >> $(QCOW2_DIR)/config.toml; \
		echo "[[customizations.user]]" >> $(QCOW2_DIR)/config.toml; \
		echo 'name = "immutablue"' >> $(QCOW2_DIR)/config.toml; \
		echo 'password = "immutablue"' >> $(QCOW2_DIR)/config.toml; \
		echo 'groups = ["wheel"]' >> $(QCOW2_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(QCOW2_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(QCOW2_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type qcow2 \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(QCOW2_DIR)
	@echo "qcow2 image built: $(QCOW2_DIR)/qcow2/disk.qcow2"

# Run QCOW2 VM with QEMU
# Boots the qcow2 image with KVM acceleration
# SSH available on localhost:2222
# Exit with Ctrl-A X
run_qcow2:
	@echo "Booting $(QCOW2_DIR)/qcow2/disk.qcow2..."
	@echo "SSH: ssh -p 2222 immutablue@localhost (password: immutablue)"
	@echo "Exit: Ctrl-A X"
	sudo qemu-system-x86_64 \
		-enable-kvm \
		-m 4G \
		-smp 4 \
		-cpu host \
		-drive file=$(QCOW2_DIR)/qcow2/disk.qcow2,format=qcow2 \
		-boot c \
		-nic user,hostfwd=tcp::2222-:22 \
		-nographic \
		-serial mon:stdio


# Lima VM Management
# Provides a nicer interface for managing VMs with automatic SSH, port forwarding, etc.
# Usage: make lima (generate config) -> make lima-start -> make lima-shell -> make lima-stop
#        make TRUEBLUE=1 lima lima-start (for variant builds)
# Requires: limactl (brew install lima)
LIMA_DIR := ./.lima
LIMA_INSTANCE := immutablue-$(TAG)
LIMA_YAML := $(LIMA_DIR)/$(LIMA_INSTANCE).yaml

lima:
	@echo "Generating Lima config for $(LIMA_INSTANCE)..."
	@mkdir -p $(LIMA_DIR)
	@echo "# Lima configuration for $(IMAGE):$(TAG)" > $(LIMA_YAML)
	@echo "# Generated by: make lima" >> $(LIMA_YAML)
	@echo "# Auto-generated file - do not edit manually" >> $(LIMA_YAML)
	@echo "" >> $(LIMA_YAML)
	@echo 'minimumLimaVersion: "2.0.0"' >> $(LIMA_YAML)
	@echo "vmType: qemu" >> $(LIMA_YAML)
	@echo "arch: x86_64" >> $(LIMA_YAML)
	@echo "" >> $(LIMA_YAML)
	@echo "user:" >> $(LIMA_YAML)
	@echo "  name: immutablue" >> $(LIMA_YAML)
	@echo "" >> $(LIMA_YAML)
	@echo "images:" >> $(LIMA_YAML)
	@echo '- location: "$(PWD)/$(QCOW2_DIR)/qcow2/disk.qcow2"' >> $(LIMA_YAML)
	@echo '  arch: "x86_64"' >> $(LIMA_YAML)
	@echo "" >> $(LIMA_YAML)
	@echo "cpus: 4" >> $(LIMA_YAML)
	@echo 'memory: "4GiB"' >> $(LIMA_YAML)
	@echo 'disk: "100GiB"' >> $(LIMA_YAML)
	@echo "" >> $(LIMA_YAML)
	@echo "mounts:" >> $(LIMA_YAML)
	@echo '- location: "~"' >> $(LIMA_YAML)
	@echo "  writable: false" >> $(LIMA_YAML)
	@echo "" >> $(LIMA_YAML)
	@echo "ssh:" >> $(LIMA_YAML)
	@echo "  localPort: 0" >> $(LIMA_YAML)
	@echo "  loadDotSSHPubKeys: true" >> $(LIMA_YAML)
	@echo "  # Fedora 43 SELinux issue with vsock" >> $(LIMA_YAML)
	@echo "  overVsock: false" >> $(LIMA_YAML)
	@echo "" >> $(LIMA_YAML)
	@echo "containerd:" >> $(LIMA_YAML)
	@echo "  system: false" >> $(LIMA_YAML)
	@echo "  user: false" >> $(LIMA_YAML)
	@echo "" >> $(LIMA_YAML)
	@echo "# Skip Lima guest agent for pre-built bootc images" >> $(LIMA_YAML)
	@echo "plain: true" >> $(LIMA_YAML)
	@echo "" >> $(LIMA_YAML)
	@echo "# Probe to signal boot is complete (just check if we can run a command)" >> $(LIMA_YAML)
	@echo "probes:" >> $(LIMA_YAML)
	@echo "- mode: readiness" >> $(LIMA_YAML)
	@echo "  description: vm is ready" >> $(LIMA_YAML)
	@echo "  script: |" >> $(LIMA_YAML)
	@echo "    #!/bin/bash" >> $(LIMA_YAML)
	@echo "    true" >> $(LIMA_YAML)
	@echo "" >> $(LIMA_YAML)
	@echo "message: |" >> $(LIMA_YAML)
	@echo "  Immutablue VM ($(TAG))" >> $(LIMA_YAML)
	@echo "  Default user: immutablue (password: immutablue)" >> $(LIMA_YAML)
	@echo "  Commands:" >> $(LIMA_YAML)
	@echo "    limactl shell $(LIMA_INSTANCE)" >> $(LIMA_YAML)
	@echo "    limactl stop $(LIMA_INSTANCE)" >> $(LIMA_YAML)
	@echo "    limactl delete $(LIMA_INSTANCE)" >> $(LIMA_YAML)
	@echo ""
	@echo "Lima config generated: $(LIMA_YAML)"
	@echo "Run 'make lima-start' to start the VM"

# Start Lima VM
lima-start:
	@if [ ! -f "$(LIMA_YAML)" ]; then \
		echo "Lima config not found. Run 'make lima' first."; \
		exit 1; \
	fi
	@echo "Starting Lima VM $(LIMA_INSTANCE)..."
	limactl start $(LIMA_YAML)
	@echo ""
	@echo "VM started! Use 'make lima-shell' or 'limactl shell $(LIMA_INSTANCE)'"

# Shell into Lima VM
lima-shell:
	limactl shell $(LIMA_INSTANCE)

# Stop Lima VM
lima-stop:
	limactl stop $(LIMA_INSTANCE)

# Delete Lima VM instance
lima-delete:
	limactl delete $(LIMA_INSTANCE)


rpmostree_upgrade:
	sudo rpm-ostree update


rebase:
	sudo rpm-ostree rebase ostree-unverified-registry:$(IMAGE):$(TAG)

reboot:
	sudo systemctl reboot

clean: manifest_rm
	rm -rf ./iso
	rm -rf ./raw
	rm -rf ./ami
	rm -rf ./gce
	rm -rf ./vhd
	rm -rf ./vmdk
	rm -rf ./anaconda-iso
	rm -rf ./flatpak_refs
	rm -rf ./sbom
	rm -rf ./images
	rm -rf ./.lima


install_distrobox: 
	bash -x -c 'source ./scripts/packages.sh && dbox_install_all'

install_flatpak:
	bash -x -c 'source ./scripts/packages.sh && flatpak_install_all'

install_brew:
	bash -x -c 'source ./scripts/packages.sh && brew_install_all_packages'

install_services:
	# handled via the containerfile now
	#bash -x -c 'source ./scripts/packages.sh && services_unmask_disable_enable_mask_all'
	true

post_install:
	bash -x -c 'source ./scripts/packages.sh && run_all_post_upgrade_scripts'

post_install_notes:
	bash -x -c 'source ./scripts/packages.sh && post_install_notes'

# Pre-build test target: Validates shell scripts before building the container
# This target runs shellcheck against all bash scripts in the project to ensure code quality
# It runs in report-only mode for CI/CD integration (won't fail the build)
# Can be skipped by setting SKIP_TEST=1
pre_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		echo "Running pre-build shellcheck tests..."; \
		chmod +x ./tests/test_shellcheck.sh; \
		./tests/test_shellcheck.sh --report-only; \
	else \
		echo "Skipping pre-build shellcheck tests (SKIP_TEST=1)"; \
	fi

# Main test target: Runs all post-build tests to validate the container image
# This target runs container tests, QEMU tests, artifact tests, and setup tests
# For Kuberblue builds, includes Kuberblue-specific container and components tests
# These tests validate the built container image's functionality and integrity
# Can be skipped by setting SKIP_TEST=1
test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		$(MAKE) test_container test_container_qemu test_artifacts test_setup; \
		if [ "$(KUBERBLUE)" = "1" ]; then \
			echo "Running Kuberblue-specific tests..."; \
			$(MAKE) test_kuberblue_container test_kuberblue_components test_kuberblue_security; \
		fi; \
	else \
		echo "Skipping tests (SKIP_TEST=1)"; \
	fi

# Container test target: Validates basic container functionality
# Tests include container lint checks, essential packages, directory structure, and systemd services
# Can be skipped by setting SKIP_TEST=1
test_container:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/test_container.sh; \
		./tests/test_container.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping container tests (SKIP_TEST=1)"; \
	fi

# QEMU container test target: Tests container boot in a virtualized environment
# Validates that the container can boot properly in QEMU 
# Falls back to bootc container lint if QEMU is not available
# Can be skipped by setting SKIP_TEST=1
test_container_qemu:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/test_container_qemu.sh; \
		./tests/test_container_qemu.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping container QEMU tests (SKIP_TEST=1)"; \
	fi
	
# Artifacts test target: Verifies file integrity in the container
# Validates that files in artifacts/overrides match those in the container
# Ensures directory structure is correct and files haven't been modified
# Can be skipped by setting SKIP_TEST=1
test_artifacts:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/test_artifacts.sh; \
		./tests/test_artifacts.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping artifacts tests (SKIP_TEST=1)"; \
	fi
	
# Setup tests target: Tests the enhanced first-boot setup modules
# Tests the TUI and GUI setup applications with dry-run functionality
# Verifies that the setup applications work correctly without making changes
# Can be skipped by setting SKIP_TEST=1
test_setup:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		echo "Running setup tests..."; \
		chmod +x ./tests/test_setup.sh; \
		./tests/test_setup.sh; \
	else \
		echo "Skipping setup tests (SKIP_TEST=1)"; \
	fi

# Run all tests with a single command with detailed output
# This target provides more detailed test output than the regular test target
# It runs both pre-build tests (shellcheck) and post-build tests (container, QEMU, artifacts, setup)
# Can be skipped by setting SKIP_TEST=1
run_all_tests:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		echo "Running all tests..."; \
		chmod +x ./tests/run_tests.sh; \
		./tests/run_tests.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping all tests (SKIP_TEST=1)"; \
	fi

# Kuberblue container test target: Validates Kuberblue-specific container functionality
# Tests include Kubernetes binaries, Kuberblue files, systemd services, and configurations
# Can be skipped by setting SKIP_TEST=1
test_kuberblue_container:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_container_test

_run_kuberblue_container_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/kuberblue/test_kuberblue_container.sh; \
		KUBERBLUE=1 ./tests/kuberblue/test_kuberblue_container.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping Kuberblue container tests (SKIP_TEST=1)"; \
	fi

# Kuberblue cluster test target: Tests Kubernetes cluster functionality
# Validates cluster initialization, networking, storage, and health
# Requires VM environment - enable with KUBERBLUE_CLUSTER_TEST=1
# Can be skipped by setting SKIP_TEST=1
test_kuberblue_cluster:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_cluster_test

_run_kuberblue_cluster_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/kuberblue/test_kuberblue_cluster.sh; \
		KUBERBLUE=1 KUBERBLUE_CLUSTER_TEST=1 ./tests/kuberblue/test_kuberblue_cluster.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping Kuberblue cluster tests (SKIP_TEST=1)"; \
	fi

# Kuberblue components test target: Tests individual Kuberblue components
# Validates just commands, manifest deployment, user management, and scripts
# Can be skipped by setting SKIP_TEST=1
test_kuberblue_components:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_components_test

_run_kuberblue_components_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/kuberblue/test_kuberblue_components.sh; \
		KUBERBLUE=1 ./tests/kuberblue/test_kuberblue_components.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping Kuberblue components tests (SKIP_TEST=1)"; \
	fi

# Kuberblue integration test target: End-to-end integration testing
# Tests complete application deployment, real-world scenarios, and functionality validation
# Requires full cluster environment - enable with KUBERBLUE_INTEGRATION_TEST=1
# Can be skipped by setting SKIP_TEST=1
test_kuberblue_integration:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_integration_test

_run_kuberblue_integration_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/kuberblue/test_kuberblue_integration.sh; \
		KUBERBLUE=1 KUBERBLUE_CLUSTER_TEST=1 KUBERBLUE_INTEGRATION_TEST=1 ./tests/kuberblue/test_kuberblue_integration.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping Kuberblue integration tests (SKIP_TEST=1)"; \
	fi

# Kuberblue security test target: Security validation for Kuberblue
# Tests RBAC, network policies, pod security, and system security configurations
# Can be skipped by setting SKIP_TEST=1
test_kuberblue_security:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_security_test

_run_kuberblue_security_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/kuberblue/test_kuberblue_security.sh; \
		KUBERBLUE=1 ./tests/kuberblue/test_kuberblue_security.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping Kuberblue security tests (SKIP_TEST=1)"; \
	fi

# Kuberblue full test suite: Runs all Kuberblue tests
# Includes container tests, components tests, and optionally cluster/integration tests
# Use KUBERBLUE_CLUSTER_TEST=1 to enable cluster testing
# Use KUBERBLUE_INTEGRATION_TEST=1 to enable integration testing
# Can be skipped by setting SKIP_TEST=1
test_kuberblue:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_suite

_run_kuberblue_suite:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		echo "Running Kuberblue test suite..."; \
		$(MAKE) test_kuberblue_container test_kuberblue_components test_kuberblue_security; \
		if [ "$${KUBERBLUE_CLUSTER_TEST:-0}" = "1" ]; then \
			echo "Running cluster tests..."; \
			$(MAKE) test_kuberblue_cluster; \
			if [ "$${KUBERBLUE_INTEGRATION_TEST:-0}" = "1" ]; then \
				echo "Running integration tests..."; \
				$(MAKE) test_kuberblue_integration; \
			fi; \
		else \
			echo "INFO: Set KUBERBLUE_CLUSTER_TEST=1 to enable cluster testing"; \
			echo "INFO: Set KUBERBLUE_INTEGRATION_TEST=1 to enable integration testing"; \
		fi; \
	else \
		echo "Skipping Kuberblue tests (SKIP_TEST=1)"; \
	fi

# Kuberblue Chainsaw test target: Runs declarative Chainsaw tests for Kuberblue
# Tests include co-located YAML tests for networking, storage, and components
# Requires a running Kubernetes cluster and chainsaw binary installation
# Can be skipped by setting SKIP_TEST=1
test_kuberblue_chainsaw:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_chainsaw_test

_run_kuberblue_chainsaw_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		echo "Running Kuberblue Chainsaw tests..."; \
		chmod +x ./tests/kuberblue/chainsaw_runner.sh; \
		KUBERBLUE=1 ./tests/kuberblue/chainsaw_runner.sh; \
	else \
		echo "Skipping Kuberblue Chainsaw tests (SKIP_TEST=1)"; \
	fi

# Chainsaw-only testing: Runs only the Chainsaw declarative tests
# Convenience target for running just the Chainsaw tests without other Kuberblue tests
test_chainsaw: test_kuberblue_chainsaw


# SBOM Generation
# Generates Software Bill of Materials using Syft in both SPDX and CycloneDX formats
# Outputs are placed in ./sbom/ directory
# Usage: make sbom (after building the image)
SBOM_DIR := ./sbom
SYFT_IMAGE := docker.io/anchore/syft:latest

sbom:
	@echo "Generating SBOM for $(IMAGE):$(TAG)..."
	@mkdir -p $(SBOM_DIR)
	podman run \
		--rm \
		--security-opt label=disable \
		-v /run/user/$$(id -u)/podman/podman.sock:/var/run/docker.sock:ro \
		-v $(PWD)/$(SBOM_DIR):/sbom:z \
		$(SYFT_IMAGE) \
		$(IMAGE):$(TAG) \
		-o spdx-json=/sbom/sbom-$(TAG)-spdx.json
	podman run \
		--rm \
		--security-opt label=disable \
		-v /run/user/$$(id -u)/podman/podman.sock:/var/run/docker.sock:ro \
		-v $(PWD)/$(SBOM_DIR):/sbom:z \
		$(SYFT_IMAGE) \
		$(IMAGE):$(TAG) \
		-o cyclonedx-json=/sbom/sbom-$(TAG)-cyclonedx.json
	@echo "SBOMs generated in $(SBOM_DIR)/"
	@ls -la $(SBOM_DIR)/sbom-$(TAG)-*.json
