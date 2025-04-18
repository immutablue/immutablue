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



FULL_TAG := $(IMAGE):$(TAG)

.PHONY: list all all_upgrade install update upgrade install_or_update reboot \
	build push iso upgrade rebase clean \
	install_distrobox install_flatpak install_brew \
	post_install_notes test test_container test_container_qemu test_artifacts


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


build:
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

test: test_container test_container_qemu test_artifacts

test_container:
	chmod +x ./tests/test_container.sh
	./tests/test_container.sh $(IMAGE):$(TAG)

test_container_qemu:
	chmod +x ./tests/test_container_qemu.sh
	./tests/test_container_qemu.sh $(IMAGE):$(TAG)
	
test_artifacts:
	chmod +x ./tests/test_artifacts.sh
	./tests/test_artifacts.sh $(IMAGE):$(TAG)
	
# Run all tests with a single command
run_all_tests:
	chmod +x ./tests/run_tests.sh
	./tests/run_tests.sh $(IMAGE):$(TAG)
