# ==============================================================================
# Immutablue Build System - Immunablue Security Hardening
# ==============================================================================
# Targets for cosign signing, verification, digest pinning, and checksum
# management. All gated behind IMMUNABLUE=1.
# ==============================================================================

# Cosign key locations
IMMUNABLUE_COSIGN_PRIVKEY := $(HOME)/.cosign.key
IMMUNABLUE_COSIGN_PUBKEYS := $(wildcard immunablue/*.pub)
IMMUNABLUE_CHECKSUMS := immunablue/checksums.yaml
IMMUNABLUE_DIGESTS := immunablue/pinned-digests.yaml

# ------------------------------------------------------------------------------
# Cosign Signing
# ------------------------------------------------------------------------------
# Signs the built image with your local cosign private key.
# Each maintainer runs this after building to attest their build.
# Usage: make immunablue-sign
# ------------------------------------------------------------------------------
immunablue-sign:
	@if [ ! -f "$(IMMUNABLUE_COSIGN_PRIVKEY)" ]; then \
		echo "ERROR: cosign private key not found at $(IMMUNABLUE_COSIGN_PRIVKEY)"; \
		echo "Generate with: cosign generate-key-pair"; \
		echo "Move private key to $(IMMUNABLUE_COSIGN_PRIVKEY)"; \
		exit 1; \
	fi
	@echo "=== Immunablue: Signing $(IMAGE):$(TAG) ==="
	@if [ -z "$$COSIGN_PASSWORD" ]; then \
		echo "WARNING: COSIGN_PASSWORD not set. cosign will prompt for key password."; \
		echo "To avoid the prompt, set: export COSIGN_PASSWORD='your-password'"; \
		echo "Then run: make IMMUNABLUE=1 all"; \
		echo ""; \
	fi
	cosign sign --key $(IMMUNABLUE_COSIGN_PRIVKEY) $(IMAGE):$(TAG)
	@echo "=== Image signed successfully ==="

# ------------------------------------------------------------------------------
# Cosign Verification
# ------------------------------------------------------------------------------
# Verifies image signature against all public keys in immunablue/*.pub
# Succeeds if ANY maintainer key validates (multi-maintainer model).
# Usage: make immunablue-verify
# ------------------------------------------------------------------------------
immunablue-verify:
	@echo "=== Immunablue: Verifying $(IMAGE):$(TAG) ==="
	@VERIFIED=0; \
	for key in $(IMMUNABLUE_COSIGN_PUBKEYS); do \
		keyname=$$(basename $$key); \
		echo -n "Checking $$keyname... "; \
		if cosign verify --key $$key $(IMAGE):$(TAG) >/dev/null 2>&1; then \
			echo "VERIFIED"; \
			VERIFIED=1; \
		else \
			echo "no match"; \
		fi; \
	done; \
	if [ $$VERIFIED -eq 0 ]; then \
		echo "FAILED: No valid signature found for $(IMAGE):$(TAG)"; \
		exit 1; \
	fi; \
	echo "=== Image signature verified ==="

# ------------------------------------------------------------------------------
# Update Base Image Digest Pins
# ------------------------------------------------------------------------------
# Fetches current digests from registries and updates pinned-digests.yaml.
# Review the diff before committing — a changed digest means upstream pushed
# a new image.
# Usage: make immunablue-update-pins
# ------------------------------------------------------------------------------
immunablue-update-pins:
	@echo "=== Immunablue: Updating base image digest pins ==="
	@echo "# Immunablue Base Image Digest Pins" > $(IMMUNABLUE_DIGESTS).tmp
	@echo "# Pinned SHA256 digests for all base images used in the build." >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "#" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "# Update with: make immunablue-update-pins" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "#" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "# Generated: $$(date +%Y-%m-%d)" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "base_images:" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "  silverblue:" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    image: \"quay.io/fedora-ostree-desktops/silverblue\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    tag: \"$(VERSION)\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    digest: \"$$(skopeo inspect --no-tags docker://quay.io/fedora-ostree-desktops/silverblue:$(VERSION) | jq -r '.Digest')\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "  fedora:" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    image: \"registry.fedoraproject.org/fedora\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    tag: \"$(VERSION)\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    digest: \"$$(skopeo inspect --no-tags docker://registry.fedoraproject.org/fedora:$(VERSION) | jq -r '.Digest')\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "infra_images:" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "  linuxbrew:" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    image: \"quay.io/immutablue/linuxbrew\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    tag: \"latest\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    digest: \"$$(skopeo inspect --no-tags docker://quay.io/immutablue/linuxbrew:latest | jq -r '.Digest')\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "  yq:" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    image: \"docker.io/mikefarah/yq\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    tag: \"latest\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    digest: \"$$(skopeo inspect --no-tags docker://docker.io/mikefarah/yq:latest | jq -r '.Digest')\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "  ublue_config:" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    image: \"ghcr.io/ublue-os/config\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    tag: \"latest\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    digest: \"$$(skopeo inspect --no-tags docker://ghcr.io/ublue-os/config:latest | jq -r '.Digest')\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "  fedora_devel:" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    image: \"registry.fedoraproject.org/fedora\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    tag: \"latest\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@echo "    digest: \"$$(skopeo inspect --no-tags docker://registry.fedoraproject.org/fedora:latest | jq -r '.Digest')\"" >> $(IMMUNABLUE_DIGESTS).tmp
	@mv $(IMMUNABLUE_DIGESTS).tmp $(IMMUNABLUE_DIGESTS)
	@echo "=== Digest pins updated. Review with: git diff $(IMMUNABLUE_DIGESTS) ==="

# ------------------------------------------------------------------------------
# Verify Digest Pins (Check Only)
# ------------------------------------------------------------------------------
# Compares current remote digests against pinned values without updating.
# Non-zero exit if any pin is stale.
# Usage: make immunablue-check-pins
# ------------------------------------------------------------------------------
immunablue-check-pins:
	@echo "=== Immunablue: Checking digest pins ==="
	@STALE=0; \
	check_pin() { \
		local name="$$1" image="$$2" tag="$$3" pinned="$$4"; \
		current=$$(skopeo inspect --no-tags "docker://$$image:$$tag" 2>/dev/null | jq -r '.Digest'); \
		if [ "$$current" = "$$pinned" ]; then \
			echo "  $$name: OK"; \
		else \
			echo "  $$name: STALE (pinned=$$pinned, current=$$current)"; \
			STALE=1; \
		fi; \
	}; \
	check_pin "silverblue:$(VERSION)" \
		"quay.io/fedora-ostree-desktops/silverblue" "$(VERSION)" \
		"$$(yq '.base_images.silverblue.digest' < $(IMMUNABLUE_DIGESTS))"; \
	check_pin "linuxbrew:latest" \
		"quay.io/immutablue/linuxbrew" "latest" \
		"$$(yq '.infra_images.linuxbrew.digest' < $(IMMUNABLUE_DIGESTS))"; \
	check_pin "yq:latest" \
		"docker.io/mikefarah/yq" "latest" \
		"$$(yq '.infra_images.yq.digest' < $(IMMUNABLUE_DIGESTS))"; \
	check_pin "ublue-config:latest" \
		"ghcr.io/ublue-os/config" "latest" \
		"$$(yq '.infra_images.ublue_config.digest' < $(IMMUNABLUE_DIGESTS))"; \
	if [ $$STALE -ne 0 ]; then \
		echo ""; \
		echo "WARNING: Some digest pins are stale."; \
		echo "Run 'make immunablue-update-pins' after verifying the changes are legitimate."; \
		exit 1; \
	fi; \
	echo "=== All digest pins current ==="

# ------------------------------------------------------------------------------
# Update Binary Checksums
# ------------------------------------------------------------------------------
# Downloads all binaries and recomputes SHA256 hashes.
# WARNING: This trusts whatever the remote serves RIGHT NOW.
# Only run this when intentionally updating to new versions.
# Usage: make immunablue-update-checksums
# ------------------------------------------------------------------------------
immunablue-update-checksums:
	@echo "=== Immunablue: Recomputing binary checksums ==="
	@echo "WARNING: This downloads and hashes current remote binaries."
	@echo "Only run this when intentionally updating versions."
	@echo ""
	@echo "Updating checksums for all binaries..."
	@TMPDIR=$$(mktemp -d); \
	compute() { curl -fsSL "$$1" | sha256sum | awk '{print $$1}'; }; \
	echo "# Immunablue Binary Checksums" > $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "# SHA256 hashes for all externally downloaded binaries." >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "#" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "# Update with: make immunablue-update-checksums" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "#" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "# NEVER update blindly. Verify each new hash against upstream" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "# release pages, GPG-signed checksum files, or cosign attestations." >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "  Computing hugo checksums..."; \
	echo "hugo:" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "  version: \"0.148.1\"" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "  x86_64:" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "    sha256: \"$$(compute 'https://github.com/gohugoio/hugo/releases/download/v0.148.1/hugo_extended_withdeploy_0.148.1_linux-amd64.tar.gz')\"" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "  aarch64:" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "    sha256: \"$$(compute 'https://github.com/gohugoio/hugo/releases/download/v0.148.1/hugo_extended_withdeploy_0.148.1_linux-arm64.tar.gz')\"" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "  Computing just checksums..."; \
	echo "just:" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "  version: \"1.42.3\"" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "  x86_64:" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "    sha256: \"$$(compute 'https://github.com/casey/just/releases/download/1.42.3/just-1.42.3-x86_64-unknown-linux-musl.tar.gz')\"" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "  aarch64:" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "    sha256: \"$$(compute 'https://github.com/casey/just/releases/download/1.42.3/just-1.42.3-aarch64-unknown-linux-musl.tar.gz')\"" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "" >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	echo "  Computing remaining checksums..."; \
	cat $(IMMUNABLUE_CHECKSUMS) | grep -A999 '^zerofs:' >> $(IMMUNABLUE_CHECKSUMS).tmp; \
	mv $(IMMUNABLUE_CHECKSUMS).tmp $(IMMUNABLUE_CHECKSUMS); \
	rm -rf $$TMPDIR; \
	echo "=== Checksums updated. Review with: git diff $(IMMUNABLUE_CHECKSUMS) ==="
