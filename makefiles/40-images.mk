# ==============================================================================
# Immutablue Build System - Image Generation Targets
# ==============================================================================
# This file generates bootc images (ISO, Raw, AMI, GCE, VHD, VMDK, QCOW2)
# using bootc-image-builder with unified patterns.
# ==============================================================================

# ------------------------------------------------------------------------------
# Guard Target for Distroless
# ------------------------------------------------------------------------------
_check_not_distroless:
ifeq ($(DISTROLESS),1)
	@echo "ERROR: This target is not supported for distroless builds."
	@echo "bootc-image-builder requires dnf which GNOME OS does not have."
	@echo ""
	@echo "For distroless, use the container image directly with:"
	@echo "  podman run -it $(IMAGE):$(TAG)"
	@exit 1
endif

# ------------------------------------------------------------------------------
# ISO Generation
# ------------------------------------------------------------------------------
iso: _check_not_distroless
ifeq ($(CLASSIC_ISO),1)
	@echo "Building classic ISO using build-container-installer..."
	$(MAKE) _iso_classic
else
	@echo "Building ISO using bootc-image-builder..."
	$(MAKE) _iso_bootc
endif

iso-config:
	@./scripts/generate-image-config.sh iso $(ISO_DIR)/config-$(TAG).toml

_iso_bootc:
	@echo "Building bootc ISO for $(IMAGE):$(TAG)..."
	@mkdir -p $(ISO_DIR)/.build-$(TAG)
	@if [ -f "$(ISO_DIR)/config-$(TAG).toml" ]; then \
		echo "Using existing config: $(ISO_DIR)/config-$(TAG).toml"; \
		cp $(ISO_DIR)/config-$(TAG).toml $(ISO_DIR)/.build-$(TAG)/config.toml; \
	else \
		echo "No user config found - enabling interactive first-boot setup"; \
		./scripts/generate-image-config.sh iso $(ISO_DIR)/.build-$(TAG)/config.toml --no-user --non-interactive; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm -it --privileged \
		--security-opt label=type:unconfined_t \
		-v $(ISO_DIR)/.build-$(TAG):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(ISO_DIR)/.build-$(TAG)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type iso --rootfs btrfs --config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(ISO_DIR)/.build-$(TAG)
	mv $(ISO_DIR)/.build-$(TAG)/bootiso/install.iso $(ISO_DIR)/immutablue-$(TAG).iso
	rm -rf $(ISO_DIR)/.build-$(TAG)
	sha256sum $(ISO_DIR)/immutablue-$(TAG).iso > "$(ISO_DIR)/immutablue-$(TAG).iso.CHECKSUM"
	@echo ""
	@echo "ISO built: $(ISO_DIR)/immutablue-$(TAG).iso"

_iso_classic: flatpak_refs/flatpaks
	@echo "Building classic ISO for $(IMAGE):$(TAG)..."
	mkdir -p $(ISO_DIR)
	sudo podman run \
		--name immutablue-build --rm --privileged \
		--volume $(ISO_DIR):/build-container-installer/build \
		ghcr.io/jasonn3/build-container-installer:latest \
		VERSION=$(VERSION) \
		IMAGE_NAME=$(IMAGE_BASE_TAG) \
		IMAGE_TAG=$(TAG) \
		IMAGE_REPO=$(REGISTRY) \
		IMAGE_SIGNED=false \
		VARIANT=$(VARIANT) \
		ISO_NAME="build/immutablue-$(TAG).iso"
	@echo ""
	@echo "Classic ISO built: $(ISO_DIR)/immutablue-$(TAG).iso"

# ------------------------------------------------------------------------------
# Raw Disk Image Generation
# ------------------------------------------------------------------------------
raw-config:
	@./scripts/generate-image-config.sh raw $(RAW_DIR)/config-$(TAG).toml

raw: _check_not_distroless
	@echo "Building raw disk image for $(IMAGE):$(TAG)..."
	@mkdir -p $(RAW_DIR)/.build-$(TAG)
	@if [ -f "$(RAW_DIR)/config-$(TAG).toml" ]; then \
		cp $(RAW_DIR)/config-$(TAG).toml $(RAW_DIR)/.build-$(TAG)/config.toml; \
	else \
		./scripts/generate-image-config.sh raw $(RAW_DIR)/.build-$(TAG)/config.toml --no-user --non-interactive; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm -it --privileged \
		--security-opt label=type:unconfined_t \
		-v $(RAW_DIR)/.build-$(TAG):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(RAW_DIR)/.build-$(TAG)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type raw --rootfs btrfs --config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(RAW_DIR)/.build-$(TAG)
	@echo "Compressing with zstd..."
	zstd -T4 -5 $(RAW_DIR)/.build-$(TAG)/image/disk.raw -o $(RAW_DIR)/immutablue-$(TAG).img.zst
	rm -rf $(RAW_DIR)/.build-$(TAG)
	@echo ""
	@echo "Raw image built: $(RAW_DIR)/immutablue-$(TAG).img.zst"
	@echo "To extract: zstd -d $(RAW_DIR)/immutablue-$(TAG).img.zst -o immutablue-$(TAG).img"

# ------------------------------------------------------------------------------
# AMI (Amazon Machine Image) Generation
# ------------------------------------------------------------------------------
ami-config:
	@./scripts/generate-image-config.sh ami $(AMI_DIR)/config-$(TAG).toml

ami: _check_not_distroless
	@echo "Building AMI for $(IMAGE):$(TAG)..."
	@mkdir -p $(AMI_DIR)/.build-$(TAG)
	@if [ -f "$(AMI_DIR)/config-$(TAG).toml" ]; then \
		cp $(AMI_DIR)/config-$(TAG).toml $(AMI_DIR)/.build-$(TAG)/config.toml; \
	else \
		./scripts/generate-image-config.sh ami $(AMI_DIR)/.build-$(TAG)/config.toml --no-user --non-interactive; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm -it --privileged \
		--security-opt label=type:unconfined_t \
		-v $(AMI_DIR)/.build-$(TAG):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(AMI_DIR)/.build-$(TAG)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type ami --rootfs btrfs --config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(AMI_DIR)/.build-$(TAG)
	mv $(AMI_DIR)/.build-$(TAG)/image/disk.raw $(AMI_DIR)/immutablue-$(TAG).ami.raw
	rm -rf $(AMI_DIR)/.build-$(TAG)
	@echo ""
	@echo "AMI built: $(AMI_DIR)/immutablue-$(TAG).ami.raw"
	@echo "Upload to AWS with: aws ec2 import-image"

# ------------------------------------------------------------------------------
# GCE (Google Compute Engine) Image Generation
# ------------------------------------------------------------------------------
gce-config:
	@./scripts/generate-image-config.sh gce $(GCE_DIR)/config-$(TAG).toml

gce: _check_not_distroless
	@echo "Building GCE image for $(IMAGE):$(TAG)..."
	@mkdir -p $(GCE_DIR)/.build-$(TAG)
	@if [ -f "$(GCE_DIR)/config-$(TAG).toml" ]; then \
		cp $(GCE_DIR)/config-$(TAG).toml $(GCE_DIR)/.build-$(TAG)/config.toml; \
	else \
		./scripts/generate-image-config.sh gce $(GCE_DIR)/.build-$(TAG)/config.toml --no-user --non-interactive; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm -it --privileged \
		--security-opt label=type:unconfined_t \
		-v $(GCE_DIR)/.build-$(TAG):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(GCE_DIR)/.build-$(TAG)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type gce --rootfs btrfs --config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(GCE_DIR)/.build-$(TAG)
	mv $(GCE_DIR)/.build-$(TAG)/image/disk.tar.gz $(GCE_DIR)/immutablue-$(TAG).gce.tar.gz
	rm -rf $(GCE_DIR)/.build-$(TAG)
	@echo ""
	@echo "GCE image built: $(GCE_DIR)/immutablue-$(TAG).gce.tar.gz"
	@echo "Upload to GCS with: gsutil cp $(GCE_DIR)/immutablue-$(TAG).gce.tar.gz gs://your-bucket/"

# ------------------------------------------------------------------------------
# VHD (Virtual Hard Disk) Image Generation
# ------------------------------------------------------------------------------
vhd-config:
	@./scripts/generate-image-config.sh vhd $(VHD_DIR)/config-$(TAG).toml

vhd: _check_not_distroless
	@echo "Building VHD image for $(IMAGE):$(TAG)..."
	@mkdir -p $(VHD_DIR)/.build-$(TAG)
	@if [ -f "$(VHD_DIR)/config-$(TAG).toml" ]; then \
		cp $(VHD_DIR)/config-$(TAG).toml $(VHD_DIR)/.build-$(TAG)/config.toml; \
	else \
		./scripts/generate-image-config.sh vhd $(VHD_DIR)/.build-$(TAG)/config.toml --no-user --non-interactive; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm -it --privileged \
		--security-opt label=type:unconfined_t \
		-v $(VHD_DIR)/.build-$(TAG):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(VHD_DIR)/.build-$(TAG)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type vhd --rootfs btrfs --config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(VHD_DIR)/.build-$(TAG)
	mv $(VHD_DIR)/.build-$(TAG)/image/disk.vhd $(VHD_DIR)/immutablue-$(TAG).vhd
	rm -rf $(VHD_DIR)/.build-$(TAG)
	@echo ""
	@echo "VHD image built: $(VHD_DIR)/immutablue-$(TAG).vhd"
	@echo "Use with Azure, Hyper-V, or Virtual PC"

# ------------------------------------------------------------------------------
# VMDK (VMware Disk) Image Generation
# ------------------------------------------------------------------------------
vmdk-config:
	@./scripts/generate-image-config.sh vmdk $(VMDK_DIR)/config-$(TAG).toml

vmdk: _check_not_distroless
	@echo "Building VMDK image for $(IMAGE):$(TAG)..."
	@mkdir -p $(VMDK_DIR)/.build-$(TAG)
	@if [ -f "$(VMDK_DIR)/config-$(TAG).toml" ]; then \
		cp $(VMDK_DIR)/config-$(TAG).toml $(VMDK_DIR)/.build-$(TAG)/config.toml; \
	else \
		./scripts/generate-image-config.sh vmdk $(VMDK_DIR)/.build-$(TAG)/config.toml --no-user --non-interactive; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm -it --privileged \
		--security-opt label=type:unconfined_t \
		-v $(VMDK_DIR)/.build-$(TAG):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(VMDK_DIR)/.build-$(TAG)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type vmdk --rootfs btrfs --config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(VMDK_DIR)/.build-$(TAG)
	mv $(VMDK_DIR)/.build-$(TAG)/image/disk.vmdk $(VMDK_DIR)/immutablue-$(TAG).vmdk
	rm -rf $(VMDK_DIR)/.build-$(TAG)
	@echo ""
	@echo "VMDK image built: $(VMDK_DIR)/immutablue-$(TAG).vmdk"
	@echo "Use with VMware vSphere, Workstation, or Fusion"

# ------------------------------------------------------------------------------
# Anaconda ISO Generation
# ------------------------------------------------------------------------------
anaconda-iso-config:
	@./scripts/generate-image-config.sh anaconda-iso $(ANACONDA_ISO_DIR)/config-$(TAG).toml

anaconda-iso:
	@echo "Building Anaconda ISO for $(IMAGE):$(TAG)..."
	@mkdir -p $(ANACONDA_ISO_DIR)/.build-$(TAG)
	@if [ -f "$(ANACONDA_ISO_DIR)/config-$(TAG).toml" ]; then \
		cp $(ANACONDA_ISO_DIR)/config-$(TAG).toml $(ANACONDA_ISO_DIR)/.build-$(TAG)/config.toml; \
	else \
		./scripts/generate-image-config.sh anaconda-iso $(ANACONDA_ISO_DIR)/.build-$(TAG)/config.toml --no-user --non-interactive; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm -it --privileged \
		--security-opt label=type:unconfined_t \
		-v $(ANACONDA_ISO_DIR)/.build-$(TAG):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(ANACONDA_ISO_DIR)/.build-$(TAG)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type anaconda-iso --rootfs btrfs --config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(ANACONDA_ISO_DIR)/.build-$(TAG)
	mv $(ANACONDA_ISO_DIR)/.build-$(TAG)/bootiso/install.iso $(ANACONDA_ISO_DIR)/immutablue-$(TAG)-anaconda.iso
	rm -rf $(ANACONDA_ISO_DIR)/.build-$(TAG)
	@echo ""
	@echo "Anaconda ISO built: $(ANACONDA_ISO_DIR)/immutablue-$(TAG)-anaconda.iso"
	@echo "This ISO auto-installs to the first disk found"

# ------------------------------------------------------------------------------
# Run Targets (QEMU Testing)
# ------------------------------------------------------------------------------
run_iso:
	@if [ ! -f "$(ISO_DIR)/immutablue-$(TAG).iso" ]; then \
		echo "Error: No ISO found. Run 'make iso' first."; \
		exit 1; \
	fi
	@echo "Booting ISO: $(ISO_DIR)/immutablue-$(TAG).iso"
	@echo "Web console: http://localhost:8006"
	$(call CONTAINERIZED_QEMU_TEMPLATE,$(CURDIR)/$(ISO_DIR)/immutablue-$(TAG).iso)

run_iso_qemu:
	@if [ ! -f "$(ISO_DIR)/immutablue-$(TAG).iso" ]; then \
		echo "Error: No ISO found. Run 'make iso' first."; \
		exit 1; \
	fi
	@if [ ! -f "$(ISO_DIR)/.install-disk.qcow2" ]; then \
		echo "Creating installation target disk..."; \
		qemu-img create -f qcow2 $(ISO_DIR)/.install-disk.qcow2 64G; \
	fi
	@echo "Booting ISO: $(ISO_DIR)/immutablue-$(TAG).iso"
	@echo "SSH: ssh -p 2222 <user>@localhost (after install)"
	@echo "Exit: Ctrl-A X"
	sudo qemu-system-x86_64 \
		-enable-kvm -m 4G -smp 4 -cpu host \
		-cdrom $(ISO_DIR)/immutablue-$(TAG).iso \
		-drive file=$(ISO_DIR)/.install-disk.qcow2,format=qcow2,if=virtio \
		-boot d \
		-nic user,hostfwd=tcp::2222-:22 \
		-nographic -serial mon:stdio

run_raw:
	@if [ ! -f "$(RAW_DIR)/immutablue-$(TAG).img.zst" ]; then \
		echo "Error: No raw image found. Run 'make raw' first."; \
		exit 1; \
	fi
	@echo "Extracting compressed image..."
	zstd -d $(RAW_DIR)/immutablue-$(TAG).img.zst -o $(RAW_DIR)/.run-tmp.img -f
	@echo "Booting raw image..."
	@echo "Web console: http://localhost:8006"
	$(call CONTAINERIZED_QEMU_TEMPLATE,$(CURDIR)/$(RAW_DIR)/.run-tmp.img)
	@rm -f $(RAW_DIR)/.run-tmp.img

run_raw_qemu:
	@if [ ! -f "$(RAW_DIR)/immutablue-$(TAG).img.zst" ]; then \
		echo "Error: No raw image found. Run 'make raw' first."; \
		exit 1; \
	fi
	@echo "Extracting compressed image..."
	zstd -d $(RAW_DIR)/immutablue-$(TAG).img.zst -o $(RAW_DIR)/.run-tmp.img -f
	@echo "Booting raw image..."
	@echo "SSH: ssh -p 2222 immutablue@localhost (if configured)"
	@echo "Exit: Ctrl-A X"
	sudo qemu-system-x86_64 \
		-enable-kvm -m 4G -smp 4 -cpu host \
		-drive file=$(RAW_DIR)/.run-tmp.img,format=raw \
		-boot c \
		-nic user,hostfwd=tcp::2222-:22 \
		-nographic -serial mon:stdio
	@rm -f $(RAW_DIR)/.run-tmp.img

# ------------------------------------------------------------------------------
# Push Targets (S3 Upload)
# ------------------------------------------------------------------------------
push_iso:
	@if [ ! -f "$(ISO_DIR)/immutablue-$(TAG).iso" ]; then \
		echo "Error: No ISO found. Run 'make iso' first."; \
		exit 1; \
	fi
	@echo "Pushing ISO..."
	@cd $(ISO_DIR) && sha256sum immutablue-$(TAG).iso > immutablue-$(TAG).iso-CHECKSUM
	s3cmd $(S3_COMMON_OPTS) --access_key=$(S3_ACCESS_KEY) --secret_key=$(S3_SECRET_KEY) \
		put $(ISO_DIR)/immutablue-$(TAG).iso s3://$(S3_BUCKET)/immutablue-$(TAG).iso
	s3cmd $(S3_COMMON_OPTS) --access_key=$(S3_ACCESS_KEY) --secret_key=$(S3_SECRET_KEY) \
		put $(ISO_DIR)/immutablue-$(TAG).iso-CHECKSUM s3://$(S3_BUCKET)/immutablue-$(TAG).iso-CHECKSUM

push_raw:
	@if [ ! -f "$(RAW_DIR)/immutablue-$(TAG).img.zst" ]; then \
		echo "Error: No raw image found. Run 'make raw' first."; \
		exit 1; \
	fi
	@echo "Pushing raw image..."
	@cd $(RAW_DIR) && sha256sum immutablue-$(TAG).img.zst > immutablue-$(TAG).img.zst-CHECKSUM
	s3cmd $(S3_COMMON_OPTS) --access_key=$(S3_ACCESS_KEY) --secret_key=$(S3_SECRET_KEY) \
		put $(RAW_DIR)/immutablue-$(TAG).img.zst s3://$(S3_BUCKET)/immutablue-$(TAG).img.zst
	s3cmd $(S3_COMMON_OPTS) --access_key=$(S3_ACCESS_KEY) --secret_key=$(S3_SECRET_KEY) \
		put $(RAW_DIR)/immutablue-$(TAG).img.zst-CHECKSUM s3://$(S3_BUCKET)/immutablue-$(TAG).img.zst-CHECKSUM

push_ami:
	@if [ ! -f "$(AMI_DIR)/immutablue-$(TAG).ami.raw" ]; then \
		echo "Error: No AMI found. Run 'make ami' first."; \
		exit 1; \
	fi
	@echo "Pushing AMI..."
	@cd $(AMI_DIR) && sha256sum immutablue-$(TAG).ami.raw > immutablue-$(TAG).ami.raw-CHECKSUM
	s3cmd $(S3_COMMON_OPTS) --access_key=$(S3_ACCESS_KEY) --secret_key=$(S3_SECRET_KEY) \
		put $(AMI_DIR)/immutablue-$(TAG).ami.raw s3://$(S3_BUCKET)/immutablue-$(TAG).ami.raw
	s3cmd $(S3_COMMON_OPTS) --access_key=$(S3_ACCESS_KEY) --secret_key=$(S3_SECRET_KEY) \
		put $(AMI_DIR)/immutablue-$(TAG).ami.raw-CHECKSUM s3://$(S3_BUCKET)/immutablue-$(TAG).ami.raw-CHECKSUM

push_gce:
	@if [ ! -f "$(GCE_DIR)/immutablue-$(TAG).gce.tar.gz" ]; then \
		echo "Error: No GCE image found. Run 'make gce' first."; \
		exit 1; \
	fi
	@echo "Pushing GCE image..."
	@cd $(GCE_DIR) && sha256sum immutablue-$(TAG).gce.tar.gz > immutablue-$(TAG).gce.tar.gz-CHECKSUM
	s3cmd $(S3_COMMON_OPTS) --access_key=$(S3_ACCESS_KEY) --secret_key=$(S3_SECRET_KEY) \
		put $(GCE_DIR)/immutablue-$(TAG).gce.tar.gz s3://$(S3_BUCKET)/immutablue-$(TAG).gce.tar.gz
	s3cmd $(S3_COMMON_OPTS) --access_key=$(S3_ACCESS_KEY) --secret_key=$(S3_SECRET_KEY) \
		put $(GCE_DIR)/immutablue-$(TAG).gce.tar.gz-CHECKSUM s3://$(S3_BUCKET)/immutablue-$(TAG).gce.tar.gz-CHECKSUM

push_vhd:
	@if [ ! -f "$(VHD_DIR)/immutablue-$(TAG).vhd" ]; then \
		echo "Error: No VHD image found. Run 'make vhd' first."; \
		exit 1; \
	fi
	@echo "Pushing VHD image..."
	@cd $(VHD_DIR) && sha256sum immutablue-$(TAG).vhd > immutablue-$(TAG).vhd-CHECKSUM
	s3cmd $(S3_COMMON_OPTS) --access_key=$(S3_ACCESS_KEY) --secret_key=$(S3_SECRET_KEY) \
		put $(VHD_DIR)/immutablue-$(TAG).vhd s3://$(S3_BUCKET)/immutablue-$(TAG).vhd
	s3cmd $(S3_COMMON_OPTS) --access_key=$(S3_ACCESS_KEY) --secret_key=$(S3_SECRET_KEY) \
		put $(VHD_DIR)/immutablue-$(TAG).vhd-CHECKSUM s3://$(S3_BUCKET)/immutablue-$(TAG).vhd-CHECKSUM

push_vmdk:
	@if [ ! -f "$(VMDK_DIR)/immutablue-$(TAG).vmdk" ]; then \
		echo "Error: No VMDK image found. Run 'make vmdk' first."; \
		exit 1; \
	fi
	@echo "Pushing VMDK image..."
	@cd $(VMDK_DIR) && sha256sum immutablue-$(TAG).vmdk > immutablue-$(TAG).vmdk-CHECKSUM
	s3cmd $(S3_COMMON_OPTS) --access_key=$(S3_ACCESS_KEY) --secret_key=$(S3_SECRET_KEY) \
		put $(VMDK_DIR)/immutablue-$(TAG).vmdk s3://$(S3_BUCKET)/immutablue-$(TAG).vmdk
	s3cmd $(S3_COMMON_OPTS) --access_key=$(S3_ACCESS_KEY) --secret_key=$(S3_SECRET_KEY) \
		put $(VMDK_DIR)/immutablue-$(TAG).vmdk-CHECKSUM s3://$(S3_BUCKET)/immutablue-$(TAG).vmdk-CHECKSUM
