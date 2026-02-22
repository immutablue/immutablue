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
upgrade: rpmostree_upgrade reboot
else
install_targets := install_flatpak install_distrobox post_install post_install_notes
upgrade: rpmostree_upgrade
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
rpmostree_upgrade:
	sudo rpm-ostree update

rebase:
	sudo rpm-ostree rebase ostree-unverified-registry:$(IMAGE):$(TAG)

reboot:
	sudo systemctl reboot

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
