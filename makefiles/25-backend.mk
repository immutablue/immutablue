# ==============================================================================
# Immutablue Build System - Backend Selection
# ==============================================================================
# A backend is the operating system Immutablue is layered onto. Each lives in
# backends/<name>/ with its own Containerfile, deps Containerfile and
# backend.yaml; see backends/lib/interface.sh for the contract.
#
#   make build                          # BACKEND=fedora-bootc (default)
#   make BACKEND=arch-bootc build
#
# Included after 20-variants-logic.mk, so variant flags that imply a backend
# have already been applied.
# ==============================================================================

BACKEND_DIR := backends/$(BACKEND)

# Base image set by backends/<backend>/backend.mk wins over the Fedora base
# images the variant flags (NUCLEUS, ...) select.
ifdef BACKEND_BASE_IMAGE
    BASE_IMAGE := $(BACKEND_BASE_IMAGE)
endif
ifdef BACKEND_BASE_IMAGE_TAG
    BASE_IMAGE_TAG := $(BACKEND_BASE_IMAGE_TAG)
endif

# Backends that build the in-house C projects get the digest-pinned deps image;
# the others build against their Containerfile's empty 'no-deps' stage.
BACKEND_INHOUSE_DEPS := $(shell yq '.provides // [] | contains(["inhouse_deps"])' $(BACKEND_DIR)/backend.yaml 2>/dev/null)
CONTAINERFILE := $(BACKEND_DIR)/Containerfile
DEPS_CONTAINERFILE := $(BACKEND_DIR)/deps.Containerfile

# ------------------------------------------------------------------------------
# backend_check: refuse a build that cannot work before podman starts.
#
# Verifies the backend exists, that this host can build it, and that every
# build option is supported by it (variants/<option>.yaml 'requires').
# ------------------------------------------------------------------------------
.PHONY: backend_check
backend_check:
	@bash scripts/check-backend.sh "$(BACKEND)" "$(BUILD_OPTIONS)"

.PHONY: backend
backend:
	@echo "$(BACKEND)"
