# ==============================================================================
# Immutablue Build System - Install and Update Targets
# ==============================================================================
# This file contains targets for installing packages and updating the system.
# ==============================================================================

# ------------------------------------------------------------------------------
# Composite Targets
# ------------------------------------------------------------------------------
all: build test push
all_upgrade: all update

ifeq ($(REBOOT),1)
install_targets := install_flatpak install_distrobox post_install post_install_notes reboot
upgrade: backend_upgrade reboot
else
install_targets := install_flatpak install_distrobox post_install post_install_notes
upgrade: backend_upgrade
endif

install_or_update: $(install_targets)
install: install_or_update
update: install_or_update

# ------------------------------------------------------------------------------
# Package Installation
# ------------------------------------------------------------------------------
install_distrobox:
	bash -x -c 'source ./scripts/packages.sh && dbox_install_all'

install_flatpak:
	bash -x -c 'source ./scripts/packages.sh && flatpak_install_all'

install_brew:
	bash -x -c 'source ./scripts/packages.sh && brew_install_all_packages'

install_services:
	true

# ------------------------------------------------------------------------------
# Post-Install
# ------------------------------------------------------------------------------
post_install:
	bash -x -c 'source ./scripts/packages.sh && run_all_post_upgrade_scripts'

post_install_notes:
	bash -x -c 'source ./scripts/packages.sh && post_install_notes'

# ------------------------------------------------------------------------------
# System Operations
# ------------------------------------------------------------------------------
# Image updates and rebases go through the running image's backend
# (bootc on fedora-bootc/gnomeos/arch-bootc, boot environments on freebsd-be).
backend_upgrade:
	sudo immutablue-backend upgrade

# Kept as an alias for existing muscle memory and scripts.
rpmostree_upgrade: backend_upgrade

rebase:
	sudo immutablue-backend rebase $(IMAGE):$(TAG)

reboot:
	sudo systemctl reboot

# ------------------------------------------------------------------------------
# Source Updates
# ------------------------------------------------------------------------------
GITLAB_SRC_DIRS := $(wildcard deps/*/)
update-gitlab-src:
	@for dir in $(GITLAB_SRC_DIRS); do \
		echo "Updating $${dir}..."; \
		git -C "$${dir}" checkout master; \
		git -C "$${dir}" pull --recurse-submodules; \
	done

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------
clean: manifest_rm
	rm -rf ./iso
	rm -rf ./raw
	rm -rf ./ami
	rm -rf ./gce
	rm -rf ./vhd
	rm -rf ./vmdk
	rm -rf ./anaconda-iso
	rm -rf ./flatpak_refs
	rm -rf ./sbom
	rm -rf ./images
	rm -rf ./.lima
	rm -rf ./$(LEGACY_DEP_INFO)
