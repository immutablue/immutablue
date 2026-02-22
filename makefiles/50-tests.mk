# ==============================================================================
# Immutablue Build System - Test Targets
# ==============================================================================
# This file contains all test targets with SKIP_TEST support.
# ==============================================================================

# ------------------------------------------------------------------------------
# Pre-build Tests
# ------------------------------------------------------------------------------
pre_test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		echo "Running pre-build shellcheck tests..."; \
		chmod +x ./tests/test_shellcheck.sh; \
		./tests/test_shellcheck.sh; \
	else \
		echo "Skipping pre-build shellcheck tests (SKIP_TEST=1)"; \
	fi

# ------------------------------------------------------------------------------
# Standard Tests
# ------------------------------------------------------------------------------
test:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		$(MAKE) test_container test_container_qemu test_artifacts test_setup; \
		if [ "$(KUBERBLUE)" = "1" ]; then \
			echo "Running Kuberblue-specific tests..."; \
			$(MAKE) test_kuberblue_container test_kuberblue_components test_kuberblue_security; \
		fi; \
	else \
		echo "Skipping tests (SKIP_TEST=1)"; \
	fi

test_container:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/test_container.sh; \
		./tests/test_container.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping container tests (SKIP_TEST=1)"; \
	fi

test_container_qemu:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/test_container_qemu.sh; \
		./tests/test_container_qemu.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping container QEMU tests (SKIP_TEST=1)"; \
	fi

test_artifacts:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		chmod +x ./tests/test_artifacts.sh; \
		./tests/test_artifacts.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping artifacts tests (SKIP_TEST=1)"; \
	fi

test_setup:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		echo "Running setup tests..."; \
		chmod +x ./tests/test_setup.sh; \
		./tests/test_setup.sh; \
	else \
		echo "Skipping setup tests (SKIP_TEST=1)"; \
	fi

run_all_tests:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		echo "Running all tests..."; \
		chmod +x ./tests/run_tests.sh; \
		./tests/run_tests.sh $(IMAGE):$(TAG); \
	else \
		echo "Skipping all tests (SKIP_TEST=1)"; \
	fi

# ------------------------------------------------------------------------------
# Kuberblue Tests
# ------------------------------------------------------------------------------
test_kuberblue:
	@$(MAKE) KUBERBLUE=1 _run_kuberblue_suite

_run_kuberblue_suite:
	@if [ "$(SKIP_TEST)" = "0" ]; then \
		echo "Running Kuberblue test suite..."; \
		$(MAKE) test_kuberblue_container test_kuberblue_components test_kuberblue_security; \
		if [ "$${KUBERBLUE_CLUSTER_TEST:-0}" = "1" ]; then \
			echo "Running cluster tests..."; \
			$(MAKE) test_kuberblue_cluster; \
			if [ "$${KUBERBLUE_INTEGRATION_TEST:-0}" = "1" ]; then \
				echo "Running integration tests..."; \
				$(MAKE) test_kuberblue_integration; \
			fi; \
		else \
			echo "INFO: Set KUBERBLUE_CLUSTER_TEST=1 to enable cluster testing"; \
			echo "INFO: Set KUBERBLUE_INTEGRATION_TEST=1 to enable integration testing"; \
		fi; \
	else \
		echo "Skipping Kuberblue tests (SKIP_TEST=1)"; \
	fi

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
