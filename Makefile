REGISTRY := registry.gitlab.com/immutablue
IMAGE_BASE_TAG := immutablue
IMAGE := $(REGISTRY)/$(IMAGE_BASE_TAG)
CURRENT := 40

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

.PHONY: all all_upgrade install update install_or_update \
	build push iso upgrade rebase clean \
	install_distrobox install_flatpak



all: build push
all_upgrade: all update

install_targets := install_distrobox install_flatpak upgrade
install_or_update :$(install_targets)
install: install_or_update
update: install_or_update


build:
ifeq ($(SET_AS_LATEST), 1)
	buildah build --ignorefile ./.containerignore --no-cache -t $(IMAGE):latest -t $(IMAGE):$(TAG) -f ./Containerfile --build-arg=FEDORA_VERSION=$(VERSION)
else
	buildah build --ignorefile ./.containerignore --no-cache -t $(IMAGE):$(TAG) -f ./Containerfile --build-arg=FEDORA_VERSION=$(VERSION)
endif
		

push:
ifeq ($(SET_AS_LATEST), 1)
	buildah push $(IMAGE):$(TAG)
	buildah push $(IMAGE):latest
else
	buildah push $(IMAGE):$(TAG)
endif


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



upgrade:
	sudo rpm-ostree update


rebase:
	sudo rpm-ostree rebase ostree-unverified-registry:$(IMAGE):$(TAG)

clean:
	rm -rf ./iso
	rm -rf ./flatpak_refs



install_distrobox: 
	bash -c 'source ./scripts/packages.sh && dbox_install_all'

install_flatpak:
	bash -c 'source ./scripts/packages.sh && flatpak_install_all'

