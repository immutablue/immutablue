ifndef $(REGISTRY)
    REGISTRY := quay.io/immutablue
endif

BASE_IMAGE := quay.io/fedora-ostree-desktops/silverblue
IMAGE_BASE_TAG := immutablue
IMAGE := $(REGISTRY)/$(IMAGE_BASE_TAG)
CURRENT := 42
MANIFEST := $(IMAGE_BASE_TAG)


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
	TAG = $(CURRENT)
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
	BASE_IMAGE := quay.io/fedora/fedora-bootc
	TAG := $(TAG)-nucleus
	# We don't want gui or anything else, just replace with nucleus
	BUILD_OPTIONS := nucleus
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



# A special edition so divine, it's been ordained by the Blue Council.
ifeq ($(BUILD_A_BLUE_WORKSHOP),1)
	BASE_IMAGE := quay.io/fedora/fedora-bootc
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



FULL_TAG := $(IMAGE):$(TAG)

.PHONY: list all all_upgrade install update upgrade install_or_update reboot \
	build push iso upgrade rebase clean \
	install_distrobox install_flatpak install_brew \
	post_install_notes test test_container test_container_qemu test_artifacts test_shellcheck test_setup \
	test_kuberblue_container test_kuberblue_cluster test_kuberblue_components test_kuberblue_integration test_kuberblue_security test_kuberblue test_kuberblue_chainsaw test_chainsaw


list:
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | grep -E -v -e '^[^[:alnum:]]' -e '^$@$$'


all: build test push
all_upgrade: all update

ifeq ($(REBOOT),1)
install_targets := install_brew install_distrobox install_flatpak post_install post_install_notes reboot
upgrade: rpmostree_upgrade reboot
else 
install_targets := install_brew install_distrobox install_flatpak post_install post_install_notes
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


# Build the Immutablue container image
# This target first runs pre-build tests (shellcheck) to ensure code quality
# Pre-tests can be skipped by setting SKIP_TEST=1
build: pre_test
	buildah \
		build \
		--ignorefile ./.containerignore \
		--no-cache \
		-t $(IMAGE):$(TAG) \
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


retag:
	buildah tag $(IMAGE):$(TAG) $(IMAGE):$(RETAG)


flatpak_refs/flatpaks: packages.yaml
	mkdir -p ./flatpak_refs
	bash -c 'source ./scripts/packages.sh && flatpak_make_refs'


iso: flatpak_refs/flatpaks
	mkdir -p ./iso
	sudo podman run \
		--name immutablue-build \
		--rm \
		--privileged \
		--volume ./iso:/build-container-installer/build \
		ghcr.io/jasonn3/build-container-installer:latest \
		VERSION=$(VERSION) \
		IMAGE_NAME=$(IMAGE_BASE_TAG) \
		IMAGE_TAG=$(TAG) \
		IMAGE_REPO=$(REGISTRY) \
		IMAGE_SIGNED=false \
		VARIANT=Silverblue \
		ISO_NAME="build/immutablue-$(TAG).iso"
	# sudo podman run \
	# 	--name immutablue-build \
	# 	--rm \
	# 	--privileged \
	# 	--volume ./iso:/build-container-installer/build \
	# 	--volume ./flatpak_refs:/build-container-installer/flatpak_refs \
	# 	ghcr.io/jasonn3/build-container-installer:latest \
	# 	VERSION=$(VERSION) \
	# 	IMAGE_NAME=$(IMAGE_BASE_TAG) \
	# 	IMAGE_TAG=$(TAG) \
	# 	IMAGE_REPO=$(REGISTRY) \
	# 	IMAGE_SIGNED=false \
	# 	FLATPAK_REMOTE_NAME=flathub \
	# 	FLATPAK_REMOTE_URL=https://flathub.org/repo/flathub.flatpakrepo \
	# 	FLATPAK_REMOTE_REFS_DIR=/build-container-installer/flatpak_refs \
	# 	VARIANT=Silverblue \
	# 	ISO_NAME="build/immutablue-$(TAG).iso"

push_iso:
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put ./iso/immutablue-$(TAG).iso s3://immutablue/immutablue-$(TAG).iso
	
	s3cmd \
		--access_key=$(S3_ACCESS_KEY) \
		--secret_key=$(S3_SECRET_KEY) \
		--host=us-east-1.linodeobjects.com \
		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
		--acl-public \
		put ./iso/immutablue-$(TAG).iso-CHECKSUM s3://immutablue/immutablue-$(TAG).iso-CHECKSUM

run_iso:
	podman \
		run \
		--rm \
		--cap-add NET_ADMIN \
		-p 127.0.0.1:8006:8006 \
		--env CPU_CORES=8 \
		--env RAM_SIZE=8G \
		--env DISK_SIZE=64G \
		--env BOOT_MODE=uefi \
		--device=/dev/kvm \
		-v ./iso/immutablue-$(TAG).iso:/boot.iso \
		docker.io/qemux/qemu-docker



rpmostree_upgrade:
	sudo rpm-ostree update


rebase:
	sudo rpm-ostree rebase ostree-unverified-registry:$(IMAGE):$(TAG)

reboot:
	sudo systemctl reboot

clean: manifest_rm
	rm -rf ./iso
	rm -rf ./flatpak_refs


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
