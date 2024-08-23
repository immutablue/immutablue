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

.PHONY: all all_upgrade build push iso upgrade rebase clean install_distrobox


all: build push
all_upgrade: all update


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

iso: 
	mkdir -p ./iso
	sudo podman run \
		--rm \
		--privileged \
		--volume \
		./iso:/build-container-installer/build \
		ghcr.io/jasonn3/build-container-installer:latest \
		VERSION=$(VERSION) \
		IMAGE_NAME=$(IMAGE_BASE_TAG) \
		IMAGE_TAG=$(TAG) \
		IMAGE_REPO=$(REGISTRY) \
		IMAGE_SIGNED=false \
		VARIANT=Silverblue \
		ISO_NAME="build/immutablue-$(TAG).iso"



upgrade:
	sudo rpm-ostree update

rebase:
	sudo rpm-ostree rebase ostree-unverified-registry:$(IMAGE):$(TAG)

clean:
	rm -rf ./iso


install_distrobox: 
	bash -c 'source ./src/packages.sh && dbox_install_all'

