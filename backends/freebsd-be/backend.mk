# backends/freebsd-be/backend.mk -- Make defaults for BACKEND=freebsd-be.
#
# FreeBSD images are tagged by release: quay.io/immutablue/immutablue:15.1-freebsd.
ifndef VERSION
    VERSION := 15.1
endif
ifndef TAG
    TAG = $(VERSION)-freebsd
endif

BACKEND_BASE_IMAGE := ghcr.io/freebsd/freebsd-runtime
BACKEND_BASE_IMAGE_TAG := $(VERSION)
