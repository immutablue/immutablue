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

FULL_TAG := $(IMAGE):$(TAG)

.PHONY: all all_upgrade build push iso upgrade rebase clean


all: build push
all_upgrade: all update


build:
	buildah build --ignorefile ./.containerignore --no-cache -t $(IMAGE):$(TAG) -f ./Containerfile --build-arg=FEDORA_VERSION=$(VERSION)

push:
	buildah push $(IMAGE):$(TAG)

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


