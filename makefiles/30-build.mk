# ==============================================================================
# Immutablue Build System - Build Targets
# ==============================================================================
# This file contains all container build and push targets.
# ==============================================================================

# ------------------------------------------------------------------------------
# Smart Build Targets
# ------------------------------------------------------------------------------
# build-smart and build-deps-smart check remote image freshness before building.
# They produce identical results to build/build-deps but skip unnecessary work:
#   pull  — remote image is newer than local; pull it
#   local — local image is current; skip rebuild
#   build — no image anywhere; fall through to normal build
#
# build-smart is NOT the default (all: build test push remains unchanged).
# Use all-smart for a full smart pipeline.
# ------------------------------------------------------------------------------

build-deps-smart:
	@action=$$(./scripts/check-image-freshness.sh "$(DEPS_CONTAINER)"); \
	case "$$action" in \
		pull) \
			echo "==> Remote deps image is newer, pulling $(DEPS_CONTAINER)..."; \
			buildah pull "$(DEPS_CONTAINER)" \
			;; \
		local) \
			echo "==> Local deps image is current, skipping rebuild" \
			;; \
		build) \
			echo "==> No cached deps image found, building..."; \
			$(MAKE) build-deps push-deps \
			;; \
	esac

build-smart: pre_test
	@action=$$(./scripts/check-image-freshness.sh "$(IMAGE):$(TAG)"); \
	case "$$action" in \
		pull) \
			echo "==> Remote image is newer, pulling $(IMAGE):$(TAG)..."; \
			buildah pull "$(IMAGE):$(TAG)" \
			;; \
		local) \
			echo "==> Local image is current, skipping rebuild" \
			;; \
		build) \
			echo "==> No cached image found, building..."; \
			$(MAKE) build \
			;; \
	esac

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
