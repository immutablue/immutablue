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
