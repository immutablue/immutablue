# ==============================================================================
# Immutablue Build System - Build Targets
# ==============================================================================
# This file contains all container build and push targets.
# ==============================================================================

# ------------------------------------------------------------------------------
# Dependency Container Builds
# ------------------------------------------------------------------------------
build-deps:
	buildah \
		build \
		--ignorefile ./.containerignore \
		--no-cache \
		--platform $(PLATFORM) \
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
	buildah push $(DEPS_CONTAINER)

# ------------------------------------------------------------------------------
# NVIDIA/Cyan Dependency Build
# ------------------------------------------------------------------------------
build-cyan-deps:
	buildah \
		build \
		--no-cache \
		--platform $(PLATFORM) \
		-t $(CYAN_DEPS_CONTAINER) \
		-f ./deps/cyan/Containerfile \
		--build-arg=FEDORA_VERSION=$(VERSION)

push-cyan-deps:
	buildah push $(CYAN_DEPS_CONTAINER)

# ------------------------------------------------------------------------------
# Main Container Build
# ------------------------------------------------------------------------------
build: pre_test
ifeq ($(DISTROLESS),1)
	sudo podman \
		build \
		--format oci \
		--security-opt label=disable \
		--squash-all \
		--ignorefile ./.containerignore \
		--no-cache \
		-t $(IMAGE):$(TAG) \
		-f ./Containerfile \
		--build-arg=BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg=BASE_IMAGE_TAG=$(BASE_IMAGE_TAG) \
		--build-arg=BASE_IMAGE_DEVEL=$(BASE_IMAGE_DEVEL) \
		--build-arg=IS_DISTROLESS=$(IS_DISTROLESS) \
		--build-arg=FEDORA_VERSION=$(VERSION) \
		--build-arg=IMAGE_TAG=$(IMAGE_BASE_TAG):$(TAG) \
		--build-arg=DO_INSTALL_LTS=$(DO_INSTALL_LTS) \
		--build-arg=DO_INSTALL_ZFS=$(DO_INSTALL_ZFS) \
		--build-arg=DO_INSTALL_AKMODS=$(DO_INSTALL_AKMODS) \
		--build-arg=IMMUTABLUE_BUILD_OPTIONS=$(BUILD_OPTIONS) \
		--build-arg=SKIP=$(SKIP)
	sudo podman tag $(IMAGE):$(TAG) $(IMAGE):$(DATE_TAG)
else
	buildah \
		build \
		--ignorefile ./.containerignore \
		--no-cache \
		-t $(IMAGE):$(TAG) \
		-t $(IMAGE):$(DATE_TAG) \
		-f ./Containerfile \
		--build-arg=BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg=BASE_IMAGE_TAG=$(BASE_IMAGE_TAG) \
		--build-arg=BASE_IMAGE_DEVEL=$(BASE_IMAGE_DEVEL) \
		--build-arg=IS_DISTROLESS=$(IS_DISTROLESS) \
		--build-arg=FEDORA_VERSION=$(VERSION) \
		--build-arg=IMAGE_TAG=$(IMAGE_BASE_TAG):$(TAG) \
		--build-arg=DO_INSTALL_LTS=$(DO_INSTALL_LTS) \
		--build-arg=DO_INSTALL_ZFS=$(DO_INSTALL_ZFS) \
		--build-arg=DO_INSTALL_AKMODS=$(DO_INSTALL_AKMODS) \
		--build-arg=IMMUTABLUE_BUILD_OPTIONS=$(BUILD_OPTIONS) \
		--build-arg=SKIP=$(SKIP)
endif

# ------------------------------------------------------------------------------
# Push Targets
# ------------------------------------------------------------------------------
push:
ifeq ($(SET_AS_LATEST), 1)
	buildah push $(IMAGE):latest
endif
	buildah push $(IMAGE):$(TAG)
	buildah push $(IMAGE):$(DATE_TAG)

retag:
	buildah tag $(IMAGE):$(TAG) $(IMAGE):$(RETAG)

# ------------------------------------------------------------------------------
# Flatpak References
# ------------------------------------------------------------------------------
flatpak_refs/flatpaks: packages.yaml
	mkdir -p ./flatpak_refs
	bash -c 'source ./scripts/packages.sh && flatpak_make_refs'

# ------------------------------------------------------------------------------
# Manifest Management
# ------------------------------------------------------------------------------
manifest:
	buildah manifest create $(IMAGE):$(TAG)
	buildah manifest add $(IMAGE):$(TAG) docker://$(IMAGE):$(TAG)-amd64
	buildah manifest add $(IMAGE):$(TAG) docker://$(IMAGE):$(TAG)-arm64
	buildah manifest push --all $(IMAGE):$(TAG) docker://$(IMAGE):$(TAG)

manifest_rm:
	-buildah manifest rm $(IMAGE):$(TAG) 2>/dev/null || true
