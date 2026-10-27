# backends/freebsd-be/backend.mk -- Make defaults for BACKEND=freebsd-be.
#
# FreeBSD images are tagged by release: quay.io/immutablue/immutablue:15.1-freebsd.
ifndef VERSION
    VERSION := 15.1
endif
ifndef TAG
    TAG = $(VERSION)-freebsd
endif

# FreeBSD containers, not Linux ones.
ifndef PLATFORM
    PLATFORM := freebsd/amd64
endif

# The Containerfile COPYs the build context (no bind mounts on FreeBSD);
# squashing keeps that copy out of the image.
BACKEND_BUILD_FLAGS := --squash

BACKEND_BASE_IMAGE := ghcr.io/freebsd/freebsd-runtime
BACKEND_BASE_IMAGE_TAG := $(VERSION)
