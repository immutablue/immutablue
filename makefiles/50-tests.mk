# ==============================================================================
# Immutablue Build System - Test Targets
# ==============================================================================
# This file contains all test targets with SKIP_TEST support.
# ==============================================================================

.PHONY: pre_test test test_container test_package_presence test_container_qemu test_artifacts test_setup \
        run_all_tests test_kuberblue _run_kuberblue_suite \
        test_kuberblue_container _run_kuberblue_container_test \
        test_kuberblue_cluster _run_kuberblue_cluster_test \
        test_kuberblue_components _run_kuberblue_components_test \
        test_kuberblue_integration _run_kuberblue_integration_test \
        test_kuberblue_security _run_kuberblue_security_test \
        test_kuberblue_chainsaw _run_kuberblue_chainsaw_test \
        test_chainsaw test_kuberblue_lima _run_kuberblue_lima_test \
        sbom

# Host-safe regression checks; no image build, root access, or cluster needed.
export SKIP_TEST
.PHONY: tests test_regressions
tests: test

test_regressions:
	@bash tests/run_tests.sh --suite regressions $(IMAGE):$(TAG)

pre_test:
	@bash tests/run_tests.sh --suite pre $(IMAGE):$(TAG)

test run_all_tests:
	@IMMUTABLUE_BUILD_OPTIONS="$(BUILD_OPTIONS)" VERSION="$(VERSION)" KUBERBLUE="$(KUBERBLUE)" \
		bash tests/run_tests.sh $(IMAGE):$(TAG)

test_container test_package_presence test_container_qemu test_artifacts test_setup:
	@IMMUTABLUE_BUILD_OPTIONS="$(BUILD_OPTIONS)" VERSION="$(VERSION)" \
		bash tests/run_tests.sh --suite $(patsubst test_%,%,$@) $(IMAGE):$(TAG)

# ------------------------------------------------------------------------------
# Kuberblue Tests
# ------------------------------------------------------------------------------
test_kuberblue:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_suite

_run_kuberblue_suite:
	@KUBERBLUE=1 bash tests/run_tests.sh --suite kuberblue $(IMAGE):$(TAG)

test_kuberblue_container:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_container_test

_run_kuberblue_container_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/kuberblue/test_kuberblue_container.sh; \
		KUBERBLUE=1 ./tests/kuberblue/test_kuberblue_container.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping Kuberblue container tests (SKIP_TEST=1)"; \
	fi

test_kuberblue_cluster:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_cluster_test

_run_kuberblue_cluster_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/kuberblue/test_kuberblue_cluster.sh; \
		KUBERBLUE=1 KUBERBLUE_CLUSTER_TEST=1 ./tests/kuberblue/test_kuberblue_cluster.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping Kuberblue cluster tests (SKIP_TEST=1)"; \
	fi

test_kuberblue_components:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_components_test

_run_kuberblue_components_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/kuberblue/test_kuberblue_components.sh; \
		KUBERBLUE=1 ./tests/kuberblue/test_kuberblue_components.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping Kuberblue components tests (SKIP_TEST=1)"; \
	fi

test_kuberblue_integration:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_integration_test

_run_kuberblue_integration_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/kuberblue/test_kuberblue_integration.sh; \
		KUBERBLUE=1 KUBERBLUE_CLUSTER_TEST=1 KUBERBLUE_INTEGRATION_TEST=1 ./tests/kuberblue/test_kuberblue_integration.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping Kuberblue integration tests (SKIP_TEST=1)"; \
	fi

test_kuberblue_security:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_security_test

_run_kuberblue_security_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/kuberblue/test_kuberblue_security.sh; \
		KUBERBLUE=1 ./tests/kuberblue/test_kuberblue_security.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping Kuberblue security tests (SKIP_TEST=1)"; \
	fi

test_kuberblue_chainsaw:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_chainsaw_test

_run_kuberblue_chainsaw_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		echo "Running Kuberblue Chainsaw tests..."; \
		chmod +x ./tests/kuberblue/chainsaw_runner.sh; \
		KUBERBLUE=1 ./tests/kuberblue/chainsaw_runner.sh; \
	else \
		echo "Skipping Kuberblue Chainsaw tests (SKIP_TEST=1)"; \
	fi

test_chainsaw: test_kuberblue_chainsaw

test_kuberblue_lima:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_lima_test

_run_kuberblue_lima_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		if ! command -v limactl &>/dev/null; then \
			echo "SKIP: limactl not found — install Lima to run VM smoke tests"; \
		else \
			chmod +x ./tests/kuberblue/test_kuberblue_lima.sh; \
			./tests/kuberblue/test_kuberblue_lima.sh; \
		fi; \
	else \
		echo "Skipping Kuberblue Lima VM tests (SKIP_TEST=1)"; \
	fi

# ------------------------------------------------------------------------------
# SBOM Generation
# ------------------------------------------------------------------------------
sbom:
	@echo "Generating SBOM for $(IMAGE):$(TAG)..."
	@mkdir -p $(SBOM_DIR)
	podman run \
		--rm \
		--security-opt label=disable \
		-v /run/user/$$(id -u)/podman/podman.sock:/var/run/docker.sock:ro \
		-v $(CURDIR)/$(SBOM_DIR):/sbom:z \
		$(SYFT_IMAGE) \
		$(IMAGE):$(TAG) \
		-o spdx-json=/sbom/sbom-$(TAG)-spdx.json
	podman run \
		--rm \
		--security-opt label=disable \
		-v /run/user/$$(id -u)/podman/podman.sock:/var/run/docker.sock:ro \
		-v $(CURDIR)/$(SBOM_DIR):/sbom:z \
		$(SYFT_IMAGE) \
		$(IMAGE):$(TAG) \
		-o cyclonedx-json=/sbom/sbom-$(TAG)-cyclonedx.json
	@echo "SBOMs generated in $(SBOM_DIR)/"
	@ls -la $(SBOM_DIR)/sbom-$(TAG)-*.json
