ifndef $(REGISTRY)
    REGISTRY := registry.gitlab.com/immutablue
endif

IMAGE_BASE_TAG := immutablue
IMAGE := $(REGISTRY)/$(IMAGE_BASE_TAG)
CURRENT := 40
MANIFEST := $(IMAGE_BASE_TAG)

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
	

FULL_TAG := $(IMAGE):$(TAG)

.PHONY: list all all_upgrade install update upgrade install_or_update reboot \
	build push iso upgrade rebase clean \
	install_distrobox install_flatpak install_brew \
	update_initramfs \
	post_install_notes


list:
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | grep -E -v -e '^[^[:alnum:]]' -e '^$@$$'


all: build push
all_upgrade: all update

ifeq ($(REBOOT),1)
install_targets := install_brew install_distrobox install_flatpak install_services post_install update_initramfs post_install_notes reboot
upgrade: rpmostree_upgrade reboot
else 
install_targets := install_brew install_distrobox install_flatpak install_services post_install update_initramfs post_install_notes
upgrade: rpmostree_upgrade
endif

install_or_update :$(install_targets)
install: install_or_update
update: install_or_update


build:
	buildah manifest rm $(MANIFEST) || true 
	buildah manifest create $(MANIFEST)
	buildah build \
		--jobs=4 \
		--manifest $(MANIFEST) \
		--platform=$(PLATFORM) \
		--ignorefile ./.containerignore \
		--no-cache \
		-t $(IMAGE):$(TAG) \
		-f ./Containerfile \
		--build-arg=FEDORA_VERSION=$(VERSION)
		

IMAGE_COMPRESSION_FORMAT := zstd:chunked 
IMAGE_COMPRESSION_LEVEL := 12
push:
ifeq ($(SET_AS_LATEST), 1)
	buildah \
		manifest \
		push \
		--all \
		--compression-format $(IMAGE_COMPRESSION_FORMAT) \
		--compression-level $(IMAGE_COMPRESSION_LEVEL) \
		$(MANIFEST) \
		docker://$(IMAGE):latest
endif
	buildah \
		manifest \
		push \
		--all \
		--compression-format $(IMAGE_COMPRESSION_FORMAT) \
		--compression-level $(IMAGE_COMPRESSION_LEVEL) \
		$(MANIFEST) \
		docker://$(IMAGE):$(TAG)


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
		--volume ./flatpak_refs:/build-container-installer/flatpak_refs \
		ghcr.io/jasonn3/build-container-installer:latest \
		VERSION=$(VERSION) \
		IMAGE_NAME=$(IMAGE_BASE_TAG) \
		IMAGE_TAG=$(TAG) \
		IMAGE_REPO=$(REGISTRY) \
		IMAGE_SIGNED=false \
		FLATPAK_REMOTE_NAME=flathub \
		FLATPAK_REMOTE_URL=https://flathub.org/repo/flathub.flatpakrepo \
		FLATPAK_REMOTE_REFS_DIR=/build-container-installer/flatpak_refs \
		VARIANT=Silverblue \
		ISO_NAME="build/immutablue-$(TAG).iso"

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
	bash -x -c 'source ./scripts/packages.sh && services_unmask_disable_enable_mask_all'

post_install:
	bash -x -c 'source ./scripts/packages.sh && run_all_post_upgrade_scripts'

update_initramfs:
	bash -x -c 'source ./scripts/packages.sh && update_initramfs_if_bad_watermark'

post_install_notes:
	bash -x -c 'source ./scripts/packages.sh && post_install_notes'
