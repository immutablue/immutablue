IMAGE := registry.gitlab.com/immutablue/immutablue
CURRENT := 40

ifndef $(VERSION)
	VERSION = $(CURRENT)
endif

ifndef $(TAG)
	TAG = $(CURRENT)
endif


.PHONY: all all_upgrade build push rebase 


all: build push
all_upgrade: all update


build:
	buildah build --no-cache -t $(IMAGE):$(TAG) -f ./Containerfile --build-arg=FEDORA_VERSION=$(VERSION)

push:
	buildah push $(IMAGE):$(TAG)




upgrade:
	sudo rpm-ostree update

rebase:
	sudo rpm-ostree rebase ostree-unverified-registry:$(IMAGE):$(TAG)


